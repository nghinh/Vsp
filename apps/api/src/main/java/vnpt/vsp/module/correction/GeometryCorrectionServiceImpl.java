package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LinearRing;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.WKTWriter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.correction.dto.GeometryCorrectionRequest;
import vnpt.vsp.module.correction.dto.GeometryCorrectionResponse;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.GeometryLayer;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Records golfer-submitted geometry corrections and aggregates the repeated
 * ones.
 *
 * <p><strong>Provenance.</strong> Every row is stamped as unverified community
 * data: accuracy class D, source {@value #SOURCE}, publisher
 * {@value #PUBLISHER}, licence {@value #LICENSE}. A report is evidence, not
 * truth, and the stamp is what keeps it from ever being mistaken for a survey.</p>
 *
 * <p><strong>Aggregation runs on write.</strong> A report is only ever compared
 * against reports for the same hole and the same layer, so the candidate set is
 * a handful of rows behind a composite index — cheap enough to do inline, and
 * doing it inline means the golfer is told immediately that three people now
 * agree with them, which is the whole point of asking them to report. A
 * scheduled sweep would add a scheduler, leader election across API instances,
 * and a delay between "I reported it" and "someone will look", buying nothing
 * at this write volume.</p>
 */
@Service
@CorrectionModule
public class GeometryCorrectionServiceImpl implements GeometryCorrectionService {

    private static final Logger log = LoggerFactory.getLogger(GeometryCorrectionServiceImpl.class);

    /** Provenance stamped on every golfer-submitted correction. */
    static final String SOURCE = "GOLFER_REPORT";
    static final String PUBLISHER = "VSP Community";
    static final String LICENSE = "VSP Community Contribution";

    private static final GeometryFactory GEOMETRY_FACTORY =
            new GeometryFactory(new PrecisionModel(), 4326);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final WKTWriter WKT_WRITER = new WKTWriter();

    private final CourseCorrectionRepository correctionRepository;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final AuditService auditService;

    /** Cluster radius in metres — reports closer than this describe the same spot. */
    private final double clusterRadiusMeters;

    /** Independent reports needed before a cluster is worth a reviewer's time. */
    private final int corroborationThreshold;

    public GeometryCorrectionServiceImpl(
            CourseCorrectionRepository correctionRepository,
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            AuditService auditService,
            @Value("${vsp.corrections.cluster-radius-meters:15}") double clusterRadiusMeters,
            @Value("${vsp.corrections.corroboration-threshold:3}") int corroborationThreshold) {
        this.correctionRepository = correctionRepository;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.auditService = auditService;
        this.clusterRadiusMeters = clusterRadiusMeters;
        this.corroborationThreshold = corroborationThreshold;
    }

    @Override
    @Transactional
    public GeometryCorrectionResponse submitGeometryCorrection(Long courseId,
                                                               Long reporterId,
                                                               GeometryCorrectionRequest request) {
        if (!courseRepository.existsById(courseId)) {
            throw new VspApiException(VspErrorCode.COURSE_001);
        }

        Hole hole = holeRepository.findById(request.getHoleId())
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));
        if (hole.getCourse() == null || !courseId.equals(hole.getCourse().getId())) {
            // Reporting hole 7 of another course against this course would file
            // the correction against geometry the reviewer is not looking at.
            throw new VspApiException(VspErrorCode.HOLE_001);
        }

        String wkt = toWkt(request.getGeometry());
        GeometryLayer layer = request.getLayer();

        CourseCorrection correction = buildCorrection(courseId, reporterId, request, layer);
        correction = correctionRepository.saveAndFlush(correction);

        // Geometry columns cannot be written through the JPA mapping — see
        // CourseCorrectionRepository.setGeometryColumns.
        correctionRepository.setGeometryColumns(
                correction.getId(), wkt, request.getReporterLng(), request.getReporterLat());

        CorroborationOutcome outcome = corroborate(hole.getId(), layer, wkt);

        auditService.log(
                AuditAction.CORRECTION_SUBMITTED,
                "CourseCorrection",
                String.valueOf(correction.getId()),
                null,
                toJson(Map.of(
                        "courseId", courseId,
                        "holeId", hole.getId(),
                        "layer", layer.getWireValue(),
                        "gpsAccuracyMeters", request.getGpsAccuracyMeters(),
                        "source", SOURCE,
                        "publisher", PUBLISHER,
                        "license", LICENSE)),
                toJson(Map.of("reporterId", reporterId)));

        if (outcome.promoted()) {
            auditService.log(
                    AuditAction.CORRECTION_CORROBORATED,
                    "CourseCorrection",
                    String.valueOf(correction.getId()),
                    null,
                    toJson(Map.of(
                            "holeId", hole.getId(),
                            "layer", layer.getWireValue(),
                            "clusterSize", outcome.clusterSize(),
                            "verificationStatus", VerificationStatus.PENDING_REVIEW.name())),
                    toJson(Map.of(
                            "clusterRadiusMeters", clusterRadiusMeters,
                            "corroborationThreshold", corroborationThreshold)));
        }

        String storedWkt = correctionRepository.findProposedGeometryWkt(correction.getId());

        log.info("Geometry correction {} stored: course={} hole={} layer={} cluster={} promoted={}",
                correction.getId(), courseId, hole.getId(), layer.getWireValue(),
                outcome.clusterSize(), outcome.promoted());

        return GeometryCorrectionResponse.fromEntity(
                correction,
                storedWkt != null ? storedWkt : wkt,
                outcome.clusterSize(),
                outcome.promoted(),
                outcome.verificationStatus().name());
    }

    // ─── Corroboration ────────────────────────────────────────────────────────

    /**
     * Counts the reports agreeing with this shape and, once they reach the
     * threshold, promotes the whole cluster to PENDING_REVIEW.
     */
    private CorroborationOutcome corroborate(Long holeId, GeometryLayer layer, String wkt) {
        long clusterSize = correctionRepository.countCorroboratingReports(
                holeId, layer.name(), wkt, clusterRadiusMeters);

        if (clusterSize < corroborationThreshold) {
            return new CorroborationOutcome((int) clusterSize, false, VerificationStatus.UNVERIFIED);
        }

        int promoted = correctionRepository.promoteCorroboratedCluster(
                holeId, layer.name(), wkt, clusterRadiusMeters, (int) clusterSize);

        log.info("Corroborated cluster promoted to PENDING_REVIEW: hole={} layer={} members={}",
                holeId, layer.getWireValue(), promoted);

        return new CorroborationOutcome((int) clusterSize, true, VerificationStatus.PENDING_REVIEW);
    }

    /** Result of the corroboration pass for one submission. */
    private record CorroborationOutcome(int clusterSize,
                                        boolean promoted,
                                        VerificationStatus verificationStatus) {
    }

    // ─── Row construction ─────────────────────────────────────────────────────

    private CourseCorrection buildCorrection(Long courseId,
                                             Long reporterId,
                                             GeometryCorrectionRequest request,
                                             GeometryLayer layer) {
        CourseCorrection correction = new CourseCorrection();
        correction.setCourseId(courseId);
        correction.setHoleId(request.getHoleId());
        correction.setReporterId(reporterId);
        correction.setGeometryLayer(layer);
        correction.setCorrectionType(layer.getCorrectionType());
        correction.setStatus(CorrectionStatus.PENDING);
        correction.setGpsAccuracyMeters(request.getGpsAccuracyMeters());
        correction.setConfidence(confidenceFromGpsAccuracy(request.getGpsAccuracyMeters()));
        correction.setCorroborationCount(1);
        correction.setSubmittedAt(Instant.now());
        if (request.getNote() != null && !request.getNote().isBlank()) {
            correction.setReporterNote(request.getNote().trim());
        }

        // Provenance — Architecture §9.3: every written object records where it
        // came from, who published it, and under what licence.
        correction.getMetadata().setSource(SOURCE);
        correction.getMetadata().setPublisher(PUBLISHER);
        correction.getMetadata().setLicense(LICENSE);
        correction.getMetadata().setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        correction.getMetadata().setVerificationStatus(VerificationStatus.UNVERIFIED);
        correction.getMetadata().setEffectiveDate(LocalDate.now());
        return correction;
    }

    /**
     * Confidence banded off the reporter's GPS fix. A single community report is
     * never certain, so the scale tops out well below 100 — the number says how
     * well the phone could localise the claim, not whether the claim is right.
     */
    static BigDecimal confidenceFromGpsAccuracy(Double accuracyMeters) {
        if (accuracyMeters == null) {
            return BigDecimal.valueOf(20);
        }
        if (accuracyMeters <= 5) {
            return BigDecimal.valueOf(80);
        }
        if (accuracyMeters <= 10) {
            return BigDecimal.valueOf(60);
        }
        if (accuracyMeters <= 20) {
            return BigDecimal.valueOf(40);
        }
        return BigDecimal.valueOf(20);
    }

    // ─── GeoJSON ──────────────────────────────────────────────────────────────

    /**
     * Converts a GeoJSON geometry object to WKT, rejecting anything PostGIS
     * would store as a broken shape (self-intersecting polygon, unclosed ring,
     * degenerate line).
     */
    static String toWkt(JsonNode geoJson) {
        Geometry geometry = parseGeoJson(geoJson);
        if (geometry == null || geometry.isEmpty()) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
        if (!geometry.isValid()) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
        geometry.setSRID(4326);
        return WKT_WRITER.write(geometry);
    }

    private static Geometry parseGeoJson(JsonNode root) {
        if (root == null || !root.isObject()) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
        JsonNode typeNode = root.get("type");
        JsonNode coordinates = root.get("coordinates");
        if (typeNode == null || coordinates == null || !coordinates.isArray()) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }

        try {
            return switch (typeNode.asText()) {
                case "Point" -> GEOMETRY_FACTORY.createPoint(coordinate(coordinates));
                case "LineString" -> GEOMETRY_FACTORY.createLineString(coordinates(coordinates));
                case "Polygon" -> {
                    LinearRing shell = GEOMETRY_FACTORY.createLinearRing(
                            closeRing(coordinates(coordinates.get(0))));
                    List<LinearRing> holes = new ArrayList<>();
                    for (int i = 1; i < coordinates.size(); i++) {
                        holes.add(GEOMETRY_FACTORY.createLinearRing(
                                closeRing(coordinates(coordinates.get(i)))));
                    }
                    yield GEOMETRY_FACTORY.createPolygon(
                            shell, holes.toArray(new LinearRing[0]));
                }
                default -> throw new VspApiException(VspErrorCode.VALIDATION_008);
            };
        } catch (VspApiException e) {
            throw e;
        } catch (RuntimeException e) {
            // Malformed coordinate arrays, too-few points for a ring, etc.
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
    }

    private static Coordinate coordinate(JsonNode pair) {
        if (pair == null || !pair.isArray() || pair.size() < 2) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
        double lng = pair.get(0).asDouble();
        double lat = pair.get(1).asDouble();
        if (lng < -180 || lng > 180 || lat < -90 || lat > 90) {
            throw new VspApiException(VspErrorCode.COURSE_007);
        }
        return new Coordinate(lng, lat);
    }

    private static Coordinate[] coordinates(JsonNode array) {
        if (array == null || !array.isArray() || array.isEmpty()) {
            throw new VspApiException(VspErrorCode.VALIDATION_008);
        }
        Coordinate[] coords = new Coordinate[array.size()];
        for (int i = 0; i < array.size(); i++) {
            coords[i] = coordinate(array.get(i));
        }
        return coords;
    }

    /** GeoJSON rings must be closed; clients often forget, so close them here. */
    private static Coordinate[] closeRing(Coordinate[] coords) {
        if (coords.length >= 3 && !coords[0].equals2D(coords[coords.length - 1])) {
            Coordinate[] closed = new Coordinate[coords.length + 1];
            System.arraycopy(coords, 0, closed, 0, coords.length);
            closed[coords.length] = new Coordinate(coords[0]);
            return closed;
        }
        return coords;
    }

    private static String toJson(Map<String, ?> values) {
        try {
            return MAPPER.writeValueAsString(values);
        } catch (Exception e) {
            return null;
        }
    }
}
