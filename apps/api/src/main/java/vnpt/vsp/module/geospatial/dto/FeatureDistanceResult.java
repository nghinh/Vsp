package vnpt.vsp.module.geospatial.dto;

import java.math.BigDecimal;

/**
 * Result of a spatial query returning a feature ID and its distance from a reference point.
 * Used by findFeaturesWithinRadius and findNearestFeature.
 */
public class FeatureDistanceResult {

    private final Long featureId;
    private final BigDecimal distanceMeters;

    public FeatureDistanceResult(Long featureId, BigDecimal distanceMeters) {
        this.featureId = featureId;
        this.distanceMeters = distanceMeters;
    }

    public Long getFeatureId() {
        return featureId;
    }

    public BigDecimal getDistanceMeters() {
        return distanceMeters;
    }
}
