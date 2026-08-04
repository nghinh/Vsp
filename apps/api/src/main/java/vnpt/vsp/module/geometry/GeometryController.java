package vnpt.vsp.module.geometry;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.idempotency.Idempotent;
import vnpt.vsp.module.geometry.dto.*;
import vnpt.vsp.api.idempotency.Idempotent;

import java.util.List;
import java.util.UUID;

/**
 * REST controller for course geometry editor endpoints.
 * Per Story 8.2 Slice 6: CRUD endpoints for draft geometry management.
 *
 * <p>All endpoints require Course Admin or higher RBAC role.
 * Geometry is stored as GeoJSON (SRID 4326) and validated using PostGIS ST_IsValid.</p>
 */
@RestController
@RequestMapping("/admin/courses/{courseId}/geometry")
@GeometryModule
public class GeometryController {

    private static final Logger log = LoggerFactory.getLogger(GeometryController.class);

    private final GeometryService geometryService;

    public GeometryController(GeometryService geometryService) {
        this.geometryService = geometryService;
    }

    /**
     * Fetch all draft geometry features for a course.
     *
     * @param courseId the course ID
     * @return all draft features grouped by layer
     */
    @GetMapping("/draft")
    public ResponseEntity<DraftGeometryResponse> getDraftGeometry(
            @PathVariable Long courseId) {
        log.info("GET /admin/courses/{}/geometry/draft", courseId);
        DraftGeometryResponse response = geometryService.getDraftGeometry(courseId);
        return ResponseEntity.ok(response);
    }

    /**
     * Batch update draft geometry features (create, update, delete).
     *
     * @param courseId the course ID
     * @param request the batch update request containing multiple operations
     * @return the results of create/update operations
     */
    @PutMapping("/draft")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<List<DraftFeatureResponse>> batchUpdateDraftGeometry(
            @PathVariable Long courseId,
            @Valid @RequestBody BatchUpdateDraftGeometryRequest request) {
        log.info("PUT /admin/courses/{}/geometry/draft - {} operations",
                courseId, request.getFeatures().size());
        List<DraftFeatureResponse> responses = geometryService.batchUpdateFeatures(courseId, request);
        return ResponseEntity.ok(responses);
    }

    /**
     * Create a new draft geometry feature.
     *
     * @param courseId the course ID
     * @param request the feature creation request
     * @return the created feature
     */
    @PostMapping("/draft/features")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<DraftFeatureResponse> createFeature(
            @PathVariable Long courseId,
            @Valid @RequestBody DraftFeatureCreateRequest request) {
        log.info("POST /admin/courses/{}/geometry/draft/features - layerType={}",
                courseId, request.getLayerType());
        DraftFeatureResponse response = geometryService.createFeature(courseId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Update an existing draft geometry feature.
     *
     * @param courseId the course ID
     * @param featureId the feature UUID
     * @param request the feature update request
     * @return the updated feature
     */
    @PutMapping("/draft/features/{featureId}")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<DraftFeatureResponse> updateFeature(
            @PathVariable Long courseId,
            @PathVariable UUID featureId,
            @Valid @RequestBody DraftFeatureUpdateRequest request) {
        log.info("PUT /admin/courses/{}/geometry/draft/features/{}", courseId, featureId);
        UUID uuid = UUID.fromString(featureId.toString());
        DraftFeatureResponse response = geometryService.updateFeature(courseId, uuid, request);
        return ResponseEntity.ok(response);
    }

    /**
     * Delete a draft geometry feature.
     *
     * @param courseId the course ID
     * @param featureId the feature UUID
     * @return 204 No Content
     */
    @DeleteMapping("/draft/features/{featureId}")
    @Idempotent(ttlSeconds = 86400)
    public ResponseEntity<Void> deleteFeature(
            @PathVariable Long courseId,
            @PathVariable UUID featureId) {
        log.info("DELETE /admin/courses/{}/geometry/draft/features/{}", courseId, featureId);
        UUID uuid = UUID.fromString(featureId.toString());
        geometryService.deleteFeature(courseId, uuid);
        return ResponseEntity.noContent().build();
    }

    /**
     * Validate draft geometry for a course before publish.
     * Checks SRID 4326 and PostGIS ST_IsValid for all features.
     *
     * @param courseId the course ID
     * @param request the validation request (optional layer type filter)
     * @return validation result with error details
     */
    @PostMapping("/validate")
    public ResponseEntity<GeometryValidationResult> validateGeometry(
            @PathVariable Long courseId,
            @RequestBody(required = false) GeometryValidationRequest request) {
        log.info("POST /admin/courses/{}/geometry/validate", courseId);
        if (request == null) {
            request = new GeometryValidationRequest();
        }
        GeometryValidationResult result = geometryService.validateGeometry(courseId, request);
        return ResponseEntity.ok(result);
    }
}
