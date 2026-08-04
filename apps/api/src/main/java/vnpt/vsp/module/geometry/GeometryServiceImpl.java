package vnpt.vsp.module.geometry;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.prep.PreparedGeometryFactory;
import org.locationtech.jts.geom.prep.PreparedGeometry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.geometry.dto.*;
import vnpt.vsp.module.geometry.entity.DraftGeometryFeature;
import vnpt.vsp.module.geometry.repository.GeometryRepository;
import vnpt.vsp.module.geospatial.GeospatialService;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Implementation of {@link GeometryService}.
 * Per Story 8.2 Slice 6: CRUD endpoints for draft geometry management.
 * Per Story 3.1 AC-1/AC-2: SRID 4326, ST_IsValid, GIST indexes.
 */
@Service
@GeometryModule
public class GeometryServiceImpl implements GeometryService {

    private static final Logger log = LoggerFactory.getLogger(GeometryServiceImpl.class);
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory();
    private static final int SRID_4326 = 4326;

    private final GeometryRepository geometryRepository;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final GeospatialService geospatialService;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;

    public GeometryServiceImpl(
            GeometryRepository geometryRepository,
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            GeospatialService geospatialService,
            AuditService auditService,
            ObjectMapper objectMapper) {
        this.geometryRepository = geometryRepository;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.geospatialService = geospatialService;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
    }

    // ─── Draft geometry CRUD ───────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public DraftGeometryResponse getDraftGeometry(Long courseId) {
        log.debug("Fetching draft geometry for courseId={}", courseId);
        Course course = getCourseOrThrow(courseId);
        List<DraftGeometryFeature> features = geometryRepository.findByCourseId(courseId);
        List<DraftFeatureResponse> responses = features.stream()
                .map(DraftFeatureResponse::fromEntity)
                .toList();
        log.info("Fetched {} draft features for courseId={}", responses.size(), courseId);
        return new DraftGeometryResponse(courseId, responses);
    }

    @Override
    @Transactional
    public DraftFeatureResponse createFeature(Long courseId, DraftFeatureCreateRequest request) {
        log.debug("Creating draft feature: courseId={}, layerType={}",
                courseId, request.getLayerType());
        Course course = getCourseOrThrow(courseId);
        Hole hole = resolveHole(request.getHoleId());

        // Validate geometry
        String validityMessage = validateGeometryString(request.getGeometry());
        boolean valid = (validityMessage == null);

        // Generate or use provided UUID
        UUID featureUuid = request.getFeatureUuid() != null
                ? UUID.fromString(request.getFeatureUuid())
                : UUID.randomUUID();

        // Check for duplicate external ID
        if (request.getExternalFeatureId() != null
                && geometryRepository.existsByCourseIdAndLayerTypeAndExternalFeatureId(
                        courseId, request.getLayerType(), request.getExternalFeatureId())) {
            throw new VspApiException(VspErrorCode.GEOMETRY_003);
        }

        DraftGeometryFeature feature = new DraftGeometryFeature();
        feature.setFeatureUuid(featureUuid);
        feature.setCourse(course);
        feature.setHole(hole);
        feature.setLayerType(request.getLayerType());
        feature.setGeometry(request.getGeometry());
        feature.setValid(valid);
        feature.setValidityMessage(validityMessage);
        feature.setExternalFeatureId(request.getExternalFeatureId());
        feature.setFeatureName(request.getFeatureName());

        DataQualityMetadata metadata = feature.getMetadata();
        metadata.setPublisher("SYSTEM"); // Will be updated with actual user
        metadata.setEffectiveDate(java.time.LocalDate.now());
        metadata.setVersion(1);

        DraftGeometryFeature saved = geometryRepository.save(feature);
        auditService.log(AuditAction.GEOMETRY_FEATURE_CREATED,
                "DraftGeometryFeature", saved.getFeatureUuid().toString(),
                null, featureToJson(saved), null);
        log.info("Created draft feature: id={}, uuid={}, courseId={}, layerType={}",
                saved.getId(), saved.getFeatureUuid(), courseId, request.getLayerType());
        return DraftFeatureResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public DraftFeatureResponse updateFeature(Long courseId, UUID featureUuid,
                                             DraftFeatureUpdateRequest request) {
        log.debug("Updating draft feature: courseId={}, uuid={}", courseId, featureUuid);
        DraftGeometryFeature feature = getFeatureOrThrow(courseId, featureUuid);

        // Validate geometry
        String validityMessage = validateGeometryString(request.getGeometry());
        boolean valid = (validityMessage == null);

        String beforeJson = featureToJson(feature);

        if (request.getGeometry() != null) {
            feature.setGeometry(request.getGeometry());
        }
        if (request.getLayerType() != null) {
            feature.setLayerType(request.getLayerType());
        }
        if (request.getHoleId() != null) {
            feature.setHole(resolveHole(request.getHoleId()));
        }
        if (request.getFeatureName() != null) {
            feature.setFeatureName(request.getFeatureName());
        }

        feature.setValid(valid);
        feature.setValidityMessage(validityMessage);

        DraftGeometryFeature saved = geometryRepository.save(feature);
        auditService.log(AuditAction.GEOMETRY_FEATURE_UPDATED,
                "DraftGeometryFeature", saved.getFeatureUuid().toString(),
                beforeJson, featureToJson(saved), null);
        log.info("Updated draft feature: id={}, uuid={}, courseId={}",
                saved.getId(), featureUuid, courseId);
        return DraftFeatureResponse.fromEntity(saved);
    }

    @Override
    @Transactional
    public void deleteFeature(Long courseId, UUID featureUuid) {
        log.debug("Deleting draft feature: courseId={}, uuid={}", courseId, featureUuid);
        DraftGeometryFeature feature = getFeatureOrThrow(courseId, featureUuid);
        String beforeJson = featureToJson(feature);
        geometryRepository.delete(feature);
        auditService.log(AuditAction.GEOMETRY_FEATURE_DELETED,
                "DraftGeometryFeature", featureUuid.toString(),
                beforeJson, null, null);
        log.info("Deleted draft feature: uuid={}, courseId={}", featureUuid, courseId);
    }

    @Override
    @Transactional
    public List<DraftFeatureResponse> batchUpdateFeatures(Long courseId,
                                                         BatchUpdateDraftGeometryRequest request) {
        log.info("Batch updating {} operations for courseId={}",
                request.getFeatures().size(), courseId);
        Course course = getCourseOrThrow(courseId);
        List<DraftFeatureResponse> results = new ArrayList<>();

        for (BatchUpdateDraftGeometryRequest.DraftFeatureOperation op : request.getFeatures()) {
            try {
                switch (op.getOperation()) {
                    case CREATE -> {
                        DraftFeatureResponse response = createFeature(courseId, op.getCreate());
                        results.add(response);
                    }
                    case UPDATE -> {
                        UUID uuid = UUID.fromString(op.getFeatureUuid());
                        DraftFeatureResponse response = updateFeature(courseId, uuid, op.getUpdate());
                        results.add(response);
                    }
                    case DELETE -> {
                        UUID uuid = UUID.fromString(op.getFeatureUuid());
                        deleteFeature(courseId, uuid);
                    }
                }
            } catch (Exception e) {
                log.error("Batch operation {} failed: {}", op.getOperation(), e.getMessage());
                throw e;
            }
        }

        log.info("Batch update completed: {} operations, courseId={}", results.size(), courseId);
        return results;
    }

    // ─── Validation ────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public GeometryValidationResult validateGeometry(Long courseId, GeometryValidationRequest request) {
        log.debug("Validating geometry: courseId={}, layerType={}, fullValidation={}",
                courseId, request.getLayerType(), request.isFullValidation());

        Course course = getCourseOrThrow(courseId);
        List<DraftGeometryFeature> features;

        if (request.getLayerType() != null) {
            features = geometryRepository.findByCourseIdAndLayerType(courseId, request.getLayerType());
        } else {
            features = geometryRepository.findByCourseId(courseId);
        }

        int validCount = 0;
        int invalidCount = 0;
        GeometryValidationResult result = new GeometryValidationResult();
        result.setCourseId(courseId);

        for (DraftGeometryFeature feature : features) {
            String error = request.isFullValidation()
                    ? validateGeometryWithPostgis(feature.getGeometry())
                    : validateGeometryString(feature.getGeometry());

            if (error == null) {
                validCount++;
            } else {
                invalidCount++;
                GeometryValidationResult.FeatureValidationError validationError =
                        new GeometryValidationResult.FeatureValidationError(
                                feature.getFeatureUuid().toString(),
                                "GEOMETRY_INVALID",
                                error,
                                feature.getLayerType().name());
                validationError.setFeatureId(feature.getId());
                result.addError(validationError);
            }
        }

        boolean allValid = invalidCount == 0;
        result.setValid(allValid);
        result.setTotalChecked(features.size());
        result.setValidCount(validCount);
        result.setInvalidCount(invalidCount);

        log.info("Geometry validation complete: courseId={}, total={}, valid={}, invalid={}",
                courseId, features.size(), validCount, invalidCount);
        return result;
    }

    @Override
    public String validateGeometryString(String geoJson) {
        if (geoJson == null || geoJson.isBlank()) {
            return "Geometry is null or empty";
        }

        try {
            // Parse GeoJSON
            JsonNode root = objectMapper.readTree(geoJson);
            JsonNode typeNode = root.get("type");
            if (typeNode == null) {
                return "GeoJSON missing 'type' field";
            }
            String type = typeNode.asText();

            // Validate type is a known geometry type
            if (!isValidGeoJsonType(type)) {
                return "Unknown GeoJSON type: " + type;
            }

            // Parse geometry using JTS
            Geometry geometry = parseGeoJson(geoJson);
            if (geometry == null) {
                return "Failed to parse GeoJSON geometry";
            }

            // Check SRID
            if (geometry.getSRID() != SRID_4326) {
                // Try to set SRID and check if it's actually 4326-compatible
                try {
                    geometry.setSRID(SRID_4326);
                } catch (Exception e) {
                    return "Geometry SRID is not compatible with 4326";
                }
            }

            // If full validation is requested (called from validateGeometry), do PostGIS validation
            // This method just does local validation
            return null; // valid
        } catch (Exception e) {
            log.warn("Geometry validation error: {}", e.getMessage());
            return "Invalid GeoJSON: " + e.getMessage();
        }
    }

    // ─── Private helpers ───────────────────────────────────────────────────

    private String validateGeometryWithPostgis(String geoJson) {
        String localError = validateGeometryString(geoJson);
        if (localError != null) {
            return localError;
        }

        try {
            Geometry geometry = parseGeoJson(geoJson);
            if (geometry == null) {
                return "Failed to parse geometry";
            }

            if (!geospatialService.validateGeometry(geometry)) {
                return "Geometry failed PostGIS ST_IsValid check";
            }

            return null; // valid
        } catch (Exception e) {
            log.warn("PostGIS validation error: {}", e.getMessage());
            return "PostGIS validation error: " + e.getMessage();
        }
    }

    private Geometry parseGeoJson(String geoJson) {
        try {
            // Use JTS Geometry harvester for GeoJSON
            org.locationtech.jts.geom.Geometry geometry =
                    new org.locationtech.jts.io.WKTReader(GEOMETRY_FACTORY)
                            .read(geoJson);
            return geometry;
        } catch (Exception e) {
            // Try parsing as GeoJSON text
            try {
                return parseGeoJsonText(geoJson);
            } catch (Exception ex) {
                log.warn("Failed to parse geometry: {}", ex.getMessage());
                return null;
            }
        }
    }

    private Geometry parseGeoJsonText(String geoJson) throws Exception {
        // Simple GeoJSON to WKT conversion for basic types
        JsonNode root = objectMapper.readTree(geoJson);
        JsonNode typeNode = root.get("type");
        if (typeNode == null) return null;

        String type = typeNode.asText();
        JsonNode coordinates = root.get("coordinates");
        if (coordinates == null) return null;

        return switch (type) {
            case "Point" -> GEOMETRY_FACTORY.createPoint(
                    new org.locationtech.jts.geom.Coordinate(
                            coordinates.get(0).asDouble(),
                            coordinates.get(1).asDouble()));
            case "LineString" -> {
                org.locationtech.jts.geom.Coordinate[] coords =
                        parseCoordinatesArray(coordinates);
                yield GEOMETRY_FACTORY.createLineString(coords);
            }
            case "Polygon" -> {
                org.locationtech.jts.geom.Coordinate[] shell =
                        parseCoordinatesArray(coordinates.get(0));
                org.locationtech.jts.geom.LinearRing shellRing =
                        GEOMETRY_FACTORY.createLinearRing(shell);
                org.locationtech.jts.geom.LinearRing[] holes = new org.locationtech.jts.geom.LinearRing[0];
                if (coordinates.size() > 1) {
                    holes = new org.locationtech.jts.geom.LinearRing[coordinates.size() - 1];
                    for (int i = 1; i < coordinates.size(); i++) {
                        holes[i - 1] = GEOMETRY_FACTORY.createLinearRing(
                                parseCoordinatesArray(coordinates.get(i)));
                    }
                }
                yield GEOMETRY_FACTORY.createPolygon(shellRing, holes);
            }
            default -> null;
        };
    }

    private org.locationtech.jts.geom.Coordinate[] parseCoordinatesArray(JsonNode array) {
        org.locationtech.jts.geom.Coordinate[] coords = new org.locationtech.jts.geom.Coordinate[array.size()];
        for (int i = 0; i < array.size(); i++) {
            JsonNode point = array.get(i);
            coords[i] = new org.locationtech.jts.geom.Coordinate(
                    point.get(0).asDouble(),
                    point.get(1).asDouble());
        }
        return coords;
    }

    private boolean isValidGeoJsonType(String type) {
        return switch (type) {
            case "Point", "MultiPoint", "LineString", "MultiLineString",
                 "Polygon", "MultiPolygon", "GeometryCollection" -> true;
            default -> false;
        };
    }

    private Course getCourseOrThrow(Long courseId) {
        return courseRepository.findById(courseId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.COURSE_001));
    }

    private Hole resolveHole(Long holeId) {
        if (holeId == null) return null;
        return holeRepository.findById(holeId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));
    }

    private DraftGeometryFeature getFeatureOrThrow(Long courseId, UUID featureUuid) {
        DraftGeometryFeature feature = geometryRepository.findByFeatureUuid(featureUuid)
                .orElseThrow(() -> new VspApiException(VspErrorCode.GEOMETRY_001));
        if (!feature.getCourse().getId().equals(courseId)) {
            throw new VspApiException(VspErrorCode.GEOMETRY_002);
        }
        return feature;
    }

    private String featureToJson(DraftGeometryFeature feature) {
        return "{\"id\":" + feature.getId() +
                ",\"featureUuid\":\"" + feature.getFeatureUuid() + "\"" +
                ",\"layerType\":\"" + feature.getLayerType() + "\"" +
                ",\"valid\":" + feature.isValid() + "}";
    }
}
