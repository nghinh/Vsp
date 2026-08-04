package vnpt.vsp.module.geometry;

import vnpt.vsp.module.geometry.dto.*;
import vnpt.vsp.module.geometry.entity.DraftGeometryFeature;

import java.util.List;
import java.util.UUID;

/**
 * Geometry module public service interface.
 * Exposes draft geometry CRUD and validation operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 * Per Story 8.2 Slice 6: CRUD endpoints for draft geometry management.
 */
public interface GeometryService {

    // ─── Draft geometry CRUD ───────────────────────────────────────────────

    /**
     * Fetch all draft geometry features for a course.
     */
    DraftGeometryResponse getDraftGeometry(Long courseId);

    /**
     * Create a new draft geometry feature.
     */
    DraftFeatureResponse createFeature(Long courseId, DraftFeatureCreateRequest request);

    /**
     * Update an existing draft geometry feature.
     */
    DraftFeatureResponse updateFeature(Long courseId, UUID featureUuid, DraftFeatureUpdateRequest request);

    /**
     * Delete a draft geometry feature.
     */
    void deleteFeature(Long courseId, UUID featureUuid);

    /**
     * Batch update draft geometry features (create, update, delete).
     */
    List<DraftFeatureResponse> batchUpdateFeatures(Long courseId, BatchUpdateDraftGeometryRequest request);

    // ─── Validation ──────────────────────────────────────────────────────

    /**
     * Validate all draft geometry for a course before publish.
     * Checks SRID 4326 and geometry validity (ST_IsValid).
     */
    GeometryValidationResult validateGeometry(Long courseId, GeometryValidationRequest request);

    /**
     * Validate a single geometry string.
     * Returns null if valid, or an error message if invalid.
     */
    String validateGeometryString(String geoJson);
}
