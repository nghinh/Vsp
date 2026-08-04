package vnpt.vsp.module.performance.dispersion;

import vnpt.vsp.module.performance.PerformanceModule;

/**
 * Domain model representing a single dispersion scatter point.
 * Per Story 11.1 Slice 2: normalized coordinates and shot outcome.
 *
 * <p>Coordinates are normalized relative to the hole's local coordinate system
 * (typically centered at the tee box or a reference point on the hole).
 * Positive X = right of intended line, Negative X = left of intended line.
 * Positive Y = beyond target (long), Negative Y = before target (short).
 */
@PerformanceModule
public class DispersionPoint {

    /**
     * Normalized X coordinate (meters from intended line center).
     * Positive = right, negative = left.
     */
    private double relativeX;

    /**
     * Normalized Y coordinate (meters from target distance).
     * Positive = long, negative = short.
     */
    private double relativeY;

    /**
     * Shot outcome classification for coloring/labeling in the overlay.
     */
    private DispersionResult result;

    /**
     * Shot timestamp (for staleness tracking).
     */
    private java.time.Instant shotAt;

    // ─── Factory ────────────────────────────────────────────────────────────

    public static DispersionPoint create(double relativeX, double relativeY, DispersionResult result) {
        DispersionPoint point = new DispersionPoint();
        point.relativeX = relativeX;
        point.relativeY = relativeY;
        point.result = result;
        return point;
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public double getRelativeX() { return relativeX; }
    public void setRelativeX(double relativeX) { this.relativeX = relativeX; }

    public double getRelativeY() { return relativeY; }
    public void setRelativeY(double relativeY) { this.relativeY = relativeY; }

    public DispersionResult getResult() { return result; }
    public void setResult(DispersionResult result) { this.result = result; }

    public java.time.Instant getShotAt() { return shotAt; }
    public void setShotAt(java.time.Instant shotAt) { this.shotAt = shotAt; }

    // ─── Result Enum ───────────────────────────────────────────────────────

    public enum DispersionResult {
        /** Shot ended on the fairway. */
        FAIRWAY,
        /** Shot ended in the rough (near fairway). */
        ROUGH,
        /** Shot ended in a bunker. */
        BUNKER,
        /** Shot ended in a water hazard. */
        WATER,
        /** Shot ended out of bounds. */
        OUT_OF_BOUNDS,
        /** Shot ended on the green. */
        GREEN,
        /** Unable to classify outcome. */
        UNKNOWN
    }
}
