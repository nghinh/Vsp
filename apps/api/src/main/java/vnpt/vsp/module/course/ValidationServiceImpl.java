package vnpt.vsp.module.course;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.*;
import vnpt.vsp.module.course.repository.*;
import vnpt.vsp.module.geospatial.GeospatialService;

import java.util.List;
import java.util.Set;

/**
 * Implementation of {@link ValidationService}.
 * Per Story 8.3 AC-1.
 */
@Service
@CourseModule
@Transactional(readOnly = true)
public class ValidationServiceImpl implements ValidationService {

    private static final Logger log = LoggerFactory.getLogger(ValidationServiceImpl.class);

    /**
     * The geometry tables {@link #checkGeometryValidity} is allowed to name.
     * That method interpolates its table and column arguments straight into a
     * native query — safe only while both come from this fixed set. Every
     * caller today passes a literal from here; the allowlist is what keeps that
     * true if a future caller ever wires a request value in by mistake. A value
     * outside the set is a programming error, not user input, so it fails the
     * validation loudly rather than reaching the database.
     */
    private static final Set<String> ALLOWED_GEOMETRY_TABLES = Set.of(
            "greens", "fairway_segments", "tee_boxes", "bunkers", "water_hazards",
            "penalty_areas", "out_of_bounds", "cart_paths", "landmarks");

    /** The only geometry column any of those tables exposes. */
    private static final String GEOMETRY_COLUMN = "location";

    private final DataVersionRepository dataVersionRepository;
    private final HoleRepository holeRepository;
    private final FairwaySegmentRepository fairwaySegmentRepository;
    private final GreenRepository greenRepository;
    private final TeeSetRepository teeSetRepository;
    private final TeeBoxRepository teeBoxRepository;
    private final BunkerRepository bunkerRepository;
    private final WaterHazardRepository waterHazardRepository;
    private final PenaltyAreaRepository penaltyAreaRepository;
    private final OutOfBoundsRepository outOfBoundsRepository;
    private final CartPathRepository cartPathRepository;
    private final LandmarkRepository landmarkRepository;
    private final GeospatialService geospatialService;
    private final EntityManager entityManager;

    public ValidationServiceImpl(
            DataVersionRepository dataVersionRepository,
            HoleRepository holeRepository,
            FairwaySegmentRepository fairwaySegmentRepository,
            GreenRepository greenRepository,
            TeeSetRepository teeSetRepository,
            TeeBoxRepository teeBoxRepository,
            BunkerRepository bunkerRepository,
            WaterHazardRepository waterHazardRepository,
            PenaltyAreaRepository penaltyAreaRepository,
            OutOfBoundsRepository outOfBoundsRepository,
            CartPathRepository cartPathRepository,
            LandmarkRepository landmarkRepository,
            GeospatialService geospatialService,
            EntityManager entityManager) {
        this.dataVersionRepository = dataVersionRepository;
        this.holeRepository = holeRepository;
        this.fairwaySegmentRepository = fairwaySegmentRepository;
        this.greenRepository = greenRepository;
        this.teeSetRepository = teeSetRepository;
        this.teeBoxRepository = teeBoxRepository;
        this.bunkerRepository = bunkerRepository;
        this.waterHazardRepository = waterHazardRepository;
        this.penaltyAreaRepository = penaltyAreaRepository;
        this.outOfBoundsRepository = outOfBoundsRepository;
        this.cartPathRepository = cartPathRepository;
        this.landmarkRepository = landmarkRepository;
        this.geospatialService = geospatialService;
        this.entityManager = entityManager;
    }

    @Override
    public ValidationResponse validateForPublish(Long versionId) {
        ValidationResponse response = new ValidationResponse();
        response.setVersionId(versionId);

        DataVersion version = dataVersionRepository.findById(versionId).orElse(null);
        if (version == null) {
            response.setResult(ValidationResponse.Result.VALIDATION_ERROR);
            response.addError(new ValidationError(
                    "DataVersion", versionId, "id",
                    "VERSION_NOT_FOUND",
                    "DataVersion " + versionId + " not found"));
            return response;
        }

        if (version.getStatus() != DataVersionStatus.DRAFT) {
            response.setResult(ValidationResponse.Result.VALIDATION_ERROR);
            response.addError(new ValidationError(
                    "DataVersion", versionId, "status",
                    "INVALID_STATUS",
                    "Only DRAFT versions can be validated for publish, found: " + version.getStatus()));
            return response;
        }

        Course course = version.getCourse();
        List<Hole> holes = holeRepository.findByCourseIdOrderByHoleNumber(course.getId());
        List<Long> holeIds = holes.stream().map(Hole::getId).toList();

        // 1. Geometry validity checks via native PostGIS queries
        // Note: tee_sets has NO location column (TeeSet is course-scoped; geometry lives in TeeBox.location)
        checkGeometryValidity("greens", "location", holeIds, response);
        checkGeometryValidity("fairway_segments", "location", holeIds, response);
        checkGeometryValidity("tee_boxes", "location", holeIds, response);
        checkGeometryValidity("bunkers", "location", holeIds, response);
        checkGeometryValidity("water_hazards", "location", holeIds, response);
        checkGeometryValidity("penalty_areas", "location", holeIds, response);
        checkGeometryValidity("out_of_bounds", "location", holeIds, response);
        checkGeometryValidity("cart_paths", "location", holeIds, response);
        checkGeometryValidity("landmarks", "location", holeIds, response);

        // 2. Metadata presence checks for each geometry type
        for (Long holeId : holeIds) {
            checkMetadataPresence(fairwaySegmentRepository.findByHoleId(holeId), "FairwaySegment", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(greenRepository.findByHoleId(holeId), "Green", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(teeSetRepository.findByHoleId(holeId), "TeeSet", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(teeBoxRepository.findByHoleId(holeId), "TeeBox", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(bunkerRepository.findByHoleId(holeId), "Bunker", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(waterHazardRepository.findByHoleId(holeId), "WaterHazard", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(penaltyAreaRepository.findByHoleId(holeId), "PenaltyArea", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(outOfBoundsRepository.findByHoleId(holeId), "OutOfBounds", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(cartPathRepository.findByHoleId(holeId), "CartPath", response);
        }
        for (Long holeId : holeIds) {
            checkMetadataPresence(landmarkRepository.findByHoleId(holeId), "Landmark", response);
        }

        // 3. Data license presence
        if (version.getDataLicenses() == null || version.getDataLicenses().isEmpty()) {
            response.addError(new ValidationError(
                    "DataVersion", versionId, "dataLicenses",
                    "LICENSE_MISSING",
                    "At least one data license is required"));
        }

        // Determine overall result
        if (response.hasErrors()) {
            if (response.getErrors().stream().anyMatch(e -> e.getCode().equals("GEOMETRY_INVALID"))) {
                response.setResult(ValidationResponse.Result.GEOMETRY_INVALID);
            } else if (response.getErrors().stream().anyMatch(e -> e.getCode().equals("METADATA_MISSING"))) {
                response.setResult(ValidationResponse.Result.METADATA_MISSING);
            } else if (response.getErrors().stream().anyMatch(e -> e.getCode().equals("LICENSE_MISSING"))) {
                response.setResult(ValidationResponse.Result.LICENSE_MISSING);
            } else if (response.getErrors().stream().anyMatch(e -> e.getCode().equals("QUALITY_INSUFFICIENT"))) {
                response.setResult(ValidationResponse.Result.QUALITY_INSUFFICIENT);
            } else if (response.getErrors().stream().anyMatch(e -> e.getCode().equals("SOURCE_MISSING"))) {
                response.setResult(ValidationResponse.Result.SOURCE_MISSING);
            } else {
                response.setResult(ValidationResponse.Result.VALIDATION_ERROR);
            }
        } else if (!response.getWarnings().isEmpty()) {
            response.setResult(ValidationResponse.Result.VALID);
        } else {
            response.setResult(ValidationResponse.Result.VALID);
        }

        return response;
    }

    /**
     * Native PostGIS query to check geometry validity for a table.
     * Reports each invalid geometry as an error.
     */
    private void checkGeometryValidity(String tableName, String geometryColumn,
                                     List<Long> holeIds, ValidationResponse response) {
        if (holeIds == null || holeIds.isEmpty()) return;

        // The identifiers below are interpolated into the SQL text, not bound as
        // parameters, so they must never be anything but a name from the
        // allowlist. All callers pass one; this refuses a stray value before it
        // can reach the database.
        if (!ALLOWED_GEOMETRY_TABLES.contains(tableName) || !GEOMETRY_COLUMN.equals(geometryColumn)) {
            throw new IllegalArgumentException(
                    "Refusing to build a geometry query for unrecognised identifiers: table="
                            + tableName + ", column=" + geometryColumn);
        }

        try {
            String sql = String.format("""
                SELECT id, hole_id, ST_IsValidReason(CAST(%s AS geometry))
                FROM %s
                WHERE hole_id IN (:holeIds) AND NOT ST_IsValid(CAST(%s AS geometry))
                """, geometryColumn, tableName, geometryColumn);

            Query query = entityManager.createNativeQuery(sql);
            query.setParameter("holeIds", holeIds);

            @SuppressWarnings("unchecked")
            List<Object[]> results = query.getResultList();
            for (Object[] row : results) {
                Long entityId = ((Number) row[0]).longValue();
                Long holeId = ((Number) row[1]).longValue();
                String reason = (String) row[2];
                response.addError(new ValidationError(
                        tableName, entityId, geometryColumn,
                        "GEOMETRY_INVALID",
                        "Geometry is not valid: " + reason));
            }
        } catch (Exception e) {
            log.warn("Geometry validity check failed for table {}: {}", tableName, e.getMessage());
            response.addError(new ValidationError(
                    tableName, null, geometryColumn,
                    "VALIDATION_ERROR",
                    "Could not check geometry validity for " + tableName + ": " + e.getMessage()));
        }
    }

    /**
     * Check that metadata source and license are present, and accuracy class >= D.
     * Adds errors for missing source/license, warnings for quality class D.
     */
    private void checkMetadataPresence(List<?> entities, String entityType,
                                     ValidationResponse response) {
        for (Object entity : entities) {
            DataQualityMetadata md = getMetadata(entity);
            if (md == null) {
                Long id = getEntityId(entity);
                response.addError(new ValidationError(
                        entityType, id, "metadata",
                        "METADATA_MISSING",
                        "Metadata is missing"));
                continue;
            }

            Long id = getEntityId(entity);

            // Source check
            if (md.getSource() == null || md.getSource().isBlank()) {
                response.addError(new ValidationError(
                        entityType, id, "metadata.source",
                        "SOURCE_MISSING",
                        "Source is required but is null or blank"));
            }

            // License check (from DataQualityMetadata)
            if (md.getLicense() == null || md.getLicense().isBlank()) {
                response.addError(new ValidationError(
                        entityType, id, "metadata.license",
                        "LICENSE_MISSING",
                        "License is required but is null or blank"));
            }

            // Quality class >= D (D is the minimum allowed)
            AccuracyClass acc = md.getAccuracyClass();
            if (acc == null) {
                response.addError(new ValidationError(
                        entityType, id, "metadata.accuracyClass",
                        "QUALITY_INSUFFICIENT",
                        "Accuracy class is required but is null"));
            }
            // No explicit QUALITY_INSUFFICIENT error for D class — D is allowed (minimum)
            // Warn if quality is below B (recommendation level)
            if (acc != null && acc == AccuracyClass.D_UNVERIFIED_COMMUNITY) {
                response.addWarning(new ValidationWarning(
                        entityType, id, "metadata.accuracyClass",
                        "QUALITY_CLASS_D",
                        "Accuracy class D (unverified community) is acceptable but below recommended minimum B"));
            }
        }
    }

    private DataQualityMetadata getMetadata(Object entity) {
        // TeeSet uses getDataQuality(); all hole-scoped geometry entities use getMetadata()
        try {
            return (DataQualityMetadata) entity.getClass().getMethod("getMetadata").invoke(entity);
        } catch (NoSuchMethodException e) {
            // TeeSet does not have getMetadata() — it has getDataQuality() instead
            try {
                return (DataQualityMetadata) entity.getClass().getMethod("getDataQuality").invoke(entity);
            } catch (Exception ex) {
                return null;
            }
        } catch (Exception e) {
            return null;
        }
    }

    private Long getEntityId(Object entity) {
        try {
            return (Long) entity.getClass().getMethod("getId").invoke(entity);
        } catch (Exception e) {
            return null;
        }
    }
}
