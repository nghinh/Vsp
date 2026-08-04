package vnpt.vsp.module.geometry.dto;

import jakarta.validation.constraints.NotBlank;
import vnpt.vsp.module.geometry.LayerType;

/**
 * Request DTO for updating an existing draft geometry feature.
 * Per Story 8.2 Slice 6.
 */
public class DraftFeatureUpdateRequest {

    /**
     * Updated GeoJSON geometry string (RFC 7946). Must be valid SRID 4326.
     */
    @NotBlank(message = "Geometry is required")
    private String geometry;

    /**
     * Updated layer type (optional — allows moving a feature between layers).
     */
    private LayerType layerType;

    /**
     * Updated hole association.
     */
    private Long holeId;

    /**
     * Updated feature name.
     */
    private String featureName;

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getGeometry() {
        return geometry;
    }

    public void setGeometry(String geometry) {
        this.geometry = geometry;
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

    public String getFeatureName() {
        return featureName;
    }

    public void setFeatureName(String featureName) {
        this.featureName = featureName;
    }
}
