package vnpt.vsp.module.geometry.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.geometry.LayerType;

/**
 * Request DTO for creating a new draft geometry feature.
 * Per Story 8.2 Slice 6.
 */
public class DraftFeatureCreateRequest {

    /**
     * Client-generated UUID for idempotency. If not provided, a UUID will be generated.
     */
    private String featureUuid;

    /**
     * The layer type for this feature.
     */
    @NotNull(message = "Layer type is required")
    private LayerType layerType;

    /**
     * The hole this feature belongs to (optional for course-level features).
     */
    private Long holeId;

    /**
     * GeoJSON geometry string (RFC 7946). Must be valid SRID 4326.
     */
    @NotBlank(message = "Geometry is required")
    private String geometry;

    /**
     * External feature ID for duplicate detection.
     */
    private String externalFeatureId;

    /**
     * Optional feature name.
     */
    private String featureName;

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getFeatureUuid() {
        return featureUuid;
    }

    public void setFeatureUuid(String featureUuid) {
        this.featureUuid = featureUuid;
    }

    public LayerType getLayerType() {
        return layerType;
    }

    public void setLayerType(LayerType layerType) {
        this.layerType = layerType;
    }

    public Long getHoleId() {
        return holeId;
    }

    public void setHoleId(Long holeId) {
        this.holeId = holeId;
    }

    public String getGeometry() {
        return geometry;
    }

    public void setGeometry(String geometry) {
        this.geometry = geometry;
    }

    public String getExternalFeatureId() {
        return externalFeatureId;
    }

    public void setExternalFeatureId(String externalFeatureId) {
        this.externalFeatureId = externalFeatureId;
    }

    public String getFeatureName() {
        return featureName;
    }

    public void setFeatureName(String featureName) {
        this.featureName = featureName;
    }
}
