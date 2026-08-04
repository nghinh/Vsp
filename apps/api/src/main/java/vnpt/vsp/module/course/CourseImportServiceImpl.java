package vnpt.vsp.module.course;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.dto.ImportPreviewDto;
import vnpt.vsp.module.course.dto.ImportResultDto;
import vnpt.vsp.module.course.dto.ValidationErrorDto;
import vnpt.vsp.module.course.entity.AccuracyClass;
import vnpt.vsp.module.course.entity.Bunker;
import vnpt.vsp.module.course.entity.CartPath;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.course.entity.FairwaySegment;
import vnpt.vsp.module.course.entity.Green;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.entity.Landmark;
import vnpt.vsp.module.course.entity.OutOfBounds;
import vnpt.vsp.module.course.entity.PenaltyArea;
import vnpt.vsp.module.course.entity.PinPosition;
import vnpt.vsp.module.course.entity.TeeBox;
import vnpt.vsp.module.course.entity.TeeSet;
import vnpt.vsp.module.course.entity.VerificationStatus;
import vnpt.vsp.module.course.entity.WaterHazard;
import vnpt.vsp.module.course.imports.FeatureTypeMapper;
import vnpt.vsp.module.course.imports.FeatureTypeMapper.TargetEntity;
import vnpt.vsp.module.course.imports.GeoJsonParser;
import vnpt.vsp.module.course.imports.ImportValidator;
import vnpt.vsp.module.course.imports.ParsedFeature;
import vnpt.vsp.module.course.imports.ValidationError;
import vnpt.vsp.module.course.repository.*;

import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Implementation of CourseImportService.
 * Per Story 3.4 AC-1 (GeoJSON import), AC-2 (validation), AC-3 (DRAFT state).
 */
@Service
@CourseModule
public class CourseImportServiceImpl implements CourseImportService {

    private static final Logger log = LoggerFactory.getLogger(CourseImportServiceImpl.class);
    private static final int SRID_4326 = 4326;
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), SRID_4326);

    private final GeoJsonParser geoJsonParser;
    private final ImportValidator importValidator;
    private final FeatureTypeMapper featureTypeMapper;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final TeeSetRepository teeSetRepository;
    private final DataVersionRepository dataVersionRepository;
    private final EntityManager entityManager;

    // Preview token storage (in-memory for MVP; replace with Redis for production)
    private final Map<String, PreviewState> previewTokenStore = new ConcurrentHashMap<>();

    public CourseImportServiceImpl(GeoJsonParser geoJsonParser,
                                   ImportValidator importValidator,
                                   FeatureTypeMapper featureTypeMapper,
                                   CourseRepository courseRepository,
                                   HoleRepository holeRepository,
                                   TeeSetRepository teeSetRepository,
                                   DataVersionRepository dataVersionRepository,
                                   EntityManager entityManager) {
        this.geoJsonParser = geoJsonParser;
        this.importValidator = importValidator;
        this.featureTypeMapper = featureTypeMapper;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.teeSetRepository = teeSetRepository;
        this.dataVersionRepository = dataVersionRepository;
        this.entityManager = entityManager;
    }

    @Override
    public ImportPreviewDto previewImport(Long courseId, String geoJson, String source,
                                        String license, String uploaderId) {
        log.info("action=PREVIEW_IMPORT courseId={} uploaderId={}", courseId, uploaderId);

        // Validate course exists
        Course course = courseRepository.findById(courseId)
            .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        // Get valid hole and tee set IDs for FK validation
        Set<Long> holeIds = new HashSet<>(holeRepository.findByCourseIdOrderByHoleNumber(courseId)
            .stream().map(Hole::getId).toList());
        Set<Long> teeSetIds = new HashSet<>(teeSetRepository.findByCourseId(courseId)
            .stream().map(TeeSet::getId).toList());

        // Parse GeoJSON
        List<ParsedFeature> features = geoJsonParser.parse(geoJson);

        // Validate all features
        List<ValidationError> errors = importValidator.validateAll(features, holeIds, teeSetIds);

        // Build geometry type breakdown
        Map<String, Integer> breakdown = new HashMap<>();
        for (ParsedFeature f : features) {
            breakdown.merge(f.getGeometryType(), 1, Integer::sum);
        }

        // Separate valid and invalid features
        Set<Integer> errorIndices = new HashSet<>();
        for (ValidationError err : errors) {
            errorIndices.add(err.getFeatureIndex());
        }

        int validCount = features.size() - errorIndices.size();
        int errorCount = errors.size();

        // Generate preview token
        String previewToken = generatePreviewToken(courseId, uploaderId);
        PreviewState state = new PreviewState(courseId, features, source, license, uploaderId, errors);
        previewTokenStore.put(previewToken, state);

        // Build error summary
        String errorSummary = String.format("%d features, %d valid, %d errors",
            features.size(), validCount, errorIndices.size());

        // Convert errors to DTOs
        List<ValidationErrorDto> errorDtos = errors.stream()
            .map(e -> new ValidationErrorDto(
                e.getFeatureIndex(),
                e.getGeometryType(),
                e.getField(),
                e.getCode().name(),
                e.getMessage(),
                e.getSeverity()))
            .toList();

        return new ImportPreviewDto(
            features.size(),
            validCount,
            errorIndices.size(),
            breakdown,
            errorSummary,
            previewToken,
            errorDtos
        );
    }

    @Override
    @Transactional
    public ImportResultDto commitImport(Long courseId, String previewToken, String uploaderId) {
        log.info("action=COMMIT_IMPORT courseId={} previewToken={} uploaderId={}", courseId, previewToken, uploaderId);

        // Retrieve and validate preview state
        PreviewState state = previewTokenStore.remove(previewToken);
        if (state == null) {
            throw new VspApiException(VspErrorCode.COURSE_IMPORT_004, "Preview token expired or invalid");
        }

        // Verify course ID matches
        if (!state.courseId().equals(courseId)) {
            throw new VspApiException(VspErrorCode.COURSE_IMPORT_004, "Preview token does not match course ID");
        }

        Course course = courseRepository.findById(courseId)
            .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));

        // Check if all features are valid (no errors for any feature index)
        Set<Integer> errorIndices = new HashSet<>();
        for (ValidationError err : state.errors()) {
            errorIndices.add(err.getFeatureIndex());
        }

        if (errorIndices.size() == state.features().size()) {
            throw new VspApiException(VspErrorCode.COURSE_IMPORT_003,
                "All features failed validation — cannot commit");
        }

        // Get next version number
        int nextVersion = dataVersionRepository.findByCourseIdOrderByVersionNumberDesc(courseId).stream()
            .mapToInt(DataVersion::getVersionNumber)
            .max()
            .orElse(0) + 1;

        // Create DRAFT DataVersion
        DataVersion dataVersion = new DataVersion();
        dataVersion.setCourse(course);
        dataVersion.setVersionNumber(nextVersion);
        dataVersion.setStatus(DataVersionStatus.DRAFT);
        dataVersion.getMetadata().setSource(state.source());
        dataVersion.getMetadata().setLicense(state.license());
        dataVersion.getMetadata().setPublisher(uploaderId);
        dataVersion.getMetadata().setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        dataVersion.getMetadata().setConfidence(BigDecimal.ZERO);
        dataVersion.getMetadata().setVerificationStatus(VerificationStatus.UNVERIFIED);
        dataVersion.getMetadata().setEffectiveDate(LocalDate.now());
        dataVersion.getMetadata().setVersion(1);
        entityManager.persist(dataVersion);

        // Persist valid features
        int featureCount = 0;
        for (ParsedFeature feature : state.features()) {
            if (errorIndices.contains(feature.getIndex())) {
                continue; // Skip invalid features
            }

            persistFeature(feature, dataVersion, state);
            featureCount++;
        }

        log.info("action=COMMIT_IMPORT_COMPLETE courseId={} dataVersionId={} featureCount={}",
            courseId, dataVersion.getId(), featureCount);

        return new ImportResultDto(
            courseId,
            dataVersion.getId(),
            nextVersion,
            featureCount,
            "DRAFT"
        );
    }

    private void persistFeature(ParsedFeature feature,
                               DataVersion dataVersion, PreviewState state) {
        TargetEntity entityType = featureTypeMapper.mapToEntity(feature);
        Map<String, Object> props = feature.getProperties() != null
            ? feature.getProperties() : Map.of();

        DataQualityMetadata metadata = new DataQualityMetadata();
        metadata.setSource(state.source());
        metadata.setLicense(state.license());
        metadata.setPublisher(state.uploaderId());
        metadata.setAccuracyClass(AccuracyClass.D_UNVERIFIED_COMMUNITY);
        metadata.setConfidence(BigDecimal.ZERO);
        metadata.setVerificationStatus(VerificationStatus.UNVERIFIED);
        metadata.setEffectiveDate(LocalDate.now());
        metadata.setVersion(1);

        Long holeId = parseLong(props.get("hole_id"));
        Hole hole = holeId != null ? holeRepository.findById(holeId).orElse(null) : null;

        String wkt = buildWkt(feature);
        String location = wkt != null ? wkt : null;

        switch (entityType) {
            case TEE_BOX -> {
                TeeBox teeBox = new TeeBox();
                teeBox.setHole(hole);
                Long teeSetId = parseLong(props.get("tee_set_id"));
                if (teeSetId != null) {
                    TeeSet teeSet = teeSetRepository.findById(teeSetId).orElse(null);
                    teeBox.setTeeSet(teeSet);
                }
                teeBox.setLocation(location);
                teeBox.setMetadata(metadata);
                entityManager.persist(teeBox);
            }
            case FAIRWAY_SEGMENT -> {
                FairwaySegment fs = new FairwaySegment();
                fs.setHole(hole);
                fs.setLocation(location);
                fs.setMetadata(metadata);
                entityManager.persist(fs);
            }
            case GREEN -> {
                Green green = new Green();
                green.setHole(hole);
                green.setLocation(location);
                green.setMetadata(metadata);
                entityManager.persist(green);
            }
            case BUNKER -> {
                Bunker bunker = new Bunker();
                bunker.setHole(hole);
                bunker.setLocation(location);
                bunker.setMetadata(metadata);
                entityManager.persist(bunker);
            }
            case WATER_HAZARD -> {
                WaterHazard wh = new WaterHazard();
                wh.setHole(hole);
                wh.setLocation(location);
                String hazardType = getStringProp(props, "hazard_type");
                wh.setHazardType(hazardType != null ? hazardType : "WATER");
                wh.setMetadata(metadata);
                entityManager.persist(wh);
            }
            case PENALTY_AREA -> {
                PenaltyArea pa = new PenaltyArea();
                pa.setHole(hole);
                pa.setLocation(location);
                pa.setMetadata(metadata);
                entityManager.persist(pa);
            }
            case OUT_OF_BOUNDS -> {
                OutOfBounds ob = new OutOfBounds();
                ob.setHole(hole);
                ob.setLocation(location);
                ob.setMetadata(metadata);
                entityManager.persist(ob);
            }
            case CART_PATH -> {
                CartPath cp = new CartPath();
                cp.setHole(hole);
                cp.setLocation(location);
                String pathType = getStringProp(props, "path_type");
                cp.setPathType(pathType != null ? pathType : "MAIN");
                cp.setMetadata(metadata);
                entityManager.persist(cp);
            }
            case LANDMARK -> {
                Landmark lm = new Landmark();
                lm.setHole(hole);
                lm.setLocation(location);
                lm.setLandmarkType(getStringProp(props, "landmark_type"));
                lm.setName(getStringProp(props, "name"));
                lm.setMetadata(metadata);
                entityManager.persist(lm);
            }
            case PIN_POSITION -> {
                PinPosition pp = new PinPosition();
                pp.setHole(hole);
                pp.setLocation(location);
                pp.setPinPositionType(getStringProp(props, "pin_position_type"));
                pp.setEffectiveDate(LocalDate.now());
                pp.setMetadata(metadata);
                entityManager.persist(pp);
            }
            default -> log.warn("Unknown entity type at index {}: {}", feature.getIndex(), entityType);
        }
    }

    private String buildWkt(ParsedFeature feature) {
        if (feature.getCoordinates() == null) return null;
        try {
            String type = feature.getGeometryType();
            Object coords = feature.getCoordinates();

            if ("Point".equalsIgnoreCase(type) || "POINT".equalsIgnoreCase(type)) {
                if (coords instanceof List && ((List<?>) coords).size() >= 2) {
                    List<?> c = (List<?>) coords;
                    return String.format("POINT(%s %s)", c.get(0), c.get(1));
                }
            } else if ("LineString".equalsIgnoreCase(type) || "LINESTRING".equalsIgnoreCase(type)) {
                return buildWktLineString(coords);
            } else if ("Polygon".equalsIgnoreCase(type) || "POLYGON".equalsIgnoreCase(type)) {
                return buildWktPolygon(coords);
            }
        } catch (Exception e) {
            log.warn("Failed to build WKT at index {}: {}", feature.getIndex(), e.getMessage());
        }
        return null;
    }

    private String buildWktLineString(Object coords) {
        if (!(coords instanceof List)) return null;
        List<Coordinate> points = extractCoordsList((List<?>) coords);
        if (points.isEmpty()) return null;
        StringBuilder sb = new StringBuilder("LINESTRING(");
        for (int i = 0; i < points.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(points.get(i).x).append(" ").append(points.get(i).y);
        }
        sb.append(")");
        return sb.toString();
    }

    private String buildWktPolygon(Object coords) {
        if (!(coords instanceof List)) return null;
        List<?> rings = (List<?>) coords;
        if (rings.isEmpty()) return null;
        StringBuilder sb = new StringBuilder("POLYGON((");
        List<Coordinate> points = extractCoordsList(rings.get(0) instanceof List ? (List<?>) rings.get(0) : rings);
        for (int i = 0; i < points.size(); i++) {
            if (i > 0) sb.append(", ");
            sb.append(points.get(i).x).append(" ").append(points.get(i).y);
        }
        sb.append("))");
        return sb.toString();
    }

    private List<Coordinate> extractCoordsList(List<?> list) {
        List<Coordinate> result = new ArrayList<>();
        for (Object item : list) {
            if (item instanceof List) {
                List<?> inner = (List<?>) item;
                if (inner.size() >= 2 && inner.get(0) instanceof Number && inner.get(1) instanceof Number) {
                    result.add(new Coordinate(
                        ((Number) inner.get(0)).doubleValue(),
                        ((Number) inner.get(1)).doubleValue()));
                }
            }
        }
        return result;
    }

    private Long parseLong(Object value) {
        if (value == null) return null;
        try {
            if (value instanceof Number) return ((Number) value).longValue();
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String getStringProp(Map<String, Object> props, String key) {
        if (props == null) return null;
        Object value = props.get(key);
        if (value == null) {
            for (Map.Entry<String, Object> entry : props.entrySet()) {
                if (entry.getKey().equalsIgnoreCase(key)) {
                    value = entry.getValue();
                    break;
                }
            }
        }
        return value != null ? value.toString() : null;
    }

    private String generatePreviewToken(Long courseId, String uploaderId) {
        return UUID.randomUUID().toString() + "-" + courseId + "-" + uploaderId;
    }

    private record PreviewState(Long courseId, List<ParsedFeature> features,
                                String source, String license, String uploaderId,
                                List<ValidationError> errors) {}
}
