package vnpt.vsp.module.performance.dispersion;

import vnpt.vsp.module.performance.PerformanceModule;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * API response DTO for dispersion overlay with GeoJSON FeatureCollections.
 * Per Story 11.1 Slice 2: scatter points, hazard features, and distance metrics.
 */
@PerformanceModule
public class DispersionOverlayResponse {

    // ─── Header ───────────────────────────────────────────────────────────

    private Long clubId;
    private Long bagId;
    private Long holeId;
    private Long layoutId;

    /** Number of shots used in this dispersion. */
    private int shotCount;

    private Instant computedAt;

    // ─── GeoJSON Content ─────────────────────────────────────────────────

    /**
     * GeoJSON FeatureCollection containing scatter points.
     * Each feature: { "type": "Feature", "geometry": { "type": "Point", ... }, "properties": { "result": "FAIRWAY" } }
     */
    private Map<String, Object> scatterGeoJSON;

    /**
     * GeoJSON FeatureCollection containing hazard polygons projected to hole local coordinates.
     * Features: bunker, water, OB polygons with properties: { "hazardType": "BUNKER", "hazardId": "..." }
     */
    private Map<String, Object> hazardGeoJSON;

    // ─── Distance Metrics ────────────────────────────────────────────────

    /** Average center of scatter points (hole local coords). */
    private BigDecimal centerX;
    private BigDecimal centerY;

    /**
     * Distance from scatter center to nearest hazard edge (meters).
     * null if no hazards within reasonable range.
     */
    private BigDecimal centerToHazardMeters;

    /**
     * Hazard type of the nearest hazard (for labeling).
     */
    private String nearestHazardType;

    /**
     * Count of shots by outcome category.
     */
    private Map<String, Integer> outcomeCounts;

    // ─── Getters and Setters ───────────────────────────────────────────────

    public Long getClubId() { return clubId; }
    public void setClubId(Long clubId) { this.clubId = clubId; }

    public Long getBagId() { return bagId; }
    public void setBagId(Long bagId) { this.bagId = bagId; }

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public Long getLayoutId() { return layoutId; }
    public void setLayoutId(Long layoutId) { this.layoutId = layoutId; }

    public int getShotCount() { return shotCount; }
    public void setShotCount(int shotCount) { this.shotCount = shotCount; }

    public Instant getComputedAt() { return computedAt; }
    public void setComputedAt(Instant computedAt) { this.computedAt = computedAt; }

    public Map<String, Object> getScatterGeoJSON() { return scatterGeoJSON; }
    public void setScatterGeoJSON(Map<String, Object> scatterGeoJSON) { this.scatterGeoJSON = scatterGeoJSON; }

    public Map<String, Object> getHazardGeoJSON() { return hazardGeoJSON; }
    public void setHazardGeoJSON(Map<String, Object> hazardGeoJSON) { this.hazardGeoJSON = hazardGeoJSON; }

    public BigDecimal getCenterX() { return centerX; }
    public void setCenterX(BigDecimal centerX) { this.centerX = centerX; }

    public BigDecimal getCenterY() { return centerY; }
    public void setCenterY(BigDecimal centerY) { this.centerY = centerY; }

    public BigDecimal getCenterToHazardMeters() { return centerToHazardMeters; }
    public void setCenterToHazardMeters(BigDecimal centerToHazardMeters) { this.centerToHazardMeters = centerToHazardMeters; }

    public String getNearestHazardType() { return nearestHazardType; }
    public void setNearestHazardType(String nearestHazardType) { this.nearestHazardType = nearestHazardType; }

    public Map<String, Integer> getOutcomeCounts() { return outcomeCounts; }
    public void setOutcomeCounts(Map<String, Integer> outcomeCounts) { this.outcomeCounts = outcomeCounts; }
}
