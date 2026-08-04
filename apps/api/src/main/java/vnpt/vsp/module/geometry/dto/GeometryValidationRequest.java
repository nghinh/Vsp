package vnpt.vsp.module.geometry.dto;

import vnpt.vsp.module.geometry.LayerType;

/**
 * Request DTO for validating draft geometry before publish.
 * Per Story 8.2 Slice 6.
 */
public class GeometryValidationRequest {

    /**
     * Optional: validate only this layer type.
     * If null, validates all layers.
     */
    private LayerType layerType;

    /**
     * If true, performs full PostGIS validation including ST_IsValid.
     * If false, only checks SRID and basic GeoJSON structure.
     */
    private boolean fullValidation = true;

    public GeometryValidationRequest() {
    }

    public GeometryValidationRequest(LayerType layerType, boolean fullValidation) {
        this.layerType = layerType;
        this.fullValidation = fullValidation;
    }

    public LayerType getLayerType() {
        return layerType;
    }

    public void setLayerType(LayerType layerType) {
        this.layerType = layerType;
    }

    public boolean isFullValidation() {
        return fullValidation;
    }

    public void setFullValidation(boolean fullValidation) {
        this.fullValidation = fullValidation;
    }
}
