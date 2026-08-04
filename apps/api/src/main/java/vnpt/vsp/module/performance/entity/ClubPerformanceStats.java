package vnpt.vsp.module.performance.entity;

import java.math.BigDecimal;

/**
 * Domain model representing computed club performance statistics.
 * Per Story 11.1 AC-1: avg/median carry, total, variability, left/right, short/long, confidence.
 *
 * <p>This is a pure domain object (not a JPA entity) that is computed from
 * shot data and returned via the API. It may also be cached in the
 * {@link ClubPerformance} JPA entity.
 */
@vnpt.vsp.module.performance.PerformanceModule
public class ClubPerformanceStats {

    // ─── Sample Size & Confidence ───────────────────────────────────────────────

    /** Total number of shots used in this calculation. */
    private int sampleSize;

    /**
     * Sample size label per Story 11.1 slice plan §6.
     * insufficient (<5), limited (5–9), moderate (10–29), robust (≥30)
     */
    private SampleSizeLabel sampleSizeLabel;

    /**
     * Confidence level per Story 11.1 slice plan §6.
     * insufficient, low, medium, high
     */
    private ConfidenceLevel confidenceLevel;

    /**
     * If true, recommendations are locked due to insufficient sample size.
     * Per Story 11.1 AC-2: recommendations remain locked until ≥30 shots.
     */
    private boolean recommendationsLocked;

    // ─── Carry Distance Stats (meters) ───────────────────────────────────────

    private BigDecimal carryAvg;
    private BigDecimal carryMedian;
    private BigDecimal carryStdDev;
    private BigDecimal carryMin;
    private BigDecimal carryMax;

    // ─── Total Distance Stats (meters) ────────────────────────────────────────

    private BigDecimal totalAvg;
    private BigDecimal totalMedian;
    private BigDecimal totalStdDev;
    private BigDecimal totalMin;
    private BigDecimal totalMax;

    // ─── Directional Deviation Stats (meters) ────────────────────────────────
    // Left/right: lateral offset from intended shot line (positive = right, negative = left)
    // Short/long: longitudinal offset from target (positive = long, negative = short)

    private BigDecimal leftRightAvg;      // mean lateral deviation
    private BigDecimal leftRightStdDev;   // std dev of lateral deviation
    private BigDecimal shortLongAvg;      // mean longitudinal deviation
    private BigDecimal shortLongStdDev;   // std dev of longitudinal deviation

    // ─── Static Factory ───────────────────────────────────────────────────────

    public static ClubPerformanceStats empty() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.sampleSize = 0;
        stats.sampleSizeLabel = SampleSizeLabel.INSUFFICIENT;
        stats.confidenceLevel = ConfidenceLevel.INSUFFICIENT;
        stats.recommendationsLocked = true;
        stats.carryAvg = BigDecimal.ZERO;
        stats.carryMedian = BigDecimal.ZERO;
        stats.carryStdDev = BigDecimal.ZERO;
        stats.carryMin = BigDecimal.ZERO;
        stats.carryMax = BigDecimal.ZERO;
        stats.totalAvg = BigDecimal.ZERO;
        stats.totalMedian = BigDecimal.ZERO;
        stats.totalStdDev = BigDecimal.ZERO;
        stats.totalMin = BigDecimal.ZERO;
        stats.totalMax = BigDecimal.ZERO;
        stats.leftRightAvg = BigDecimal.ZERO;
        stats.leftRightStdDev = BigDecimal.ZERO;
        stats.shortLongAvg = BigDecimal.ZERO;
        stats.shortLongStdDev = BigDecimal.ZERO;
        return stats;
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public int getSampleSize() { return sampleSize; }
    public void setSampleSize(int sampleSize) { this.sampleSize = sampleSize; }

    public SampleSizeLabel getSampleSizeLabel() { return sampleSizeLabel; }
    public void setSampleSizeLabel(SampleSizeLabel sampleSizeLabel) { this.sampleSizeLabel = sampleSizeLabel; }

    public ConfidenceLevel getConfidenceLevel() { return confidenceLevel; }
    public void setConfidenceLevel(ConfidenceLevel confidenceLevel) { this.confidenceLevel = confidenceLevel; }

    public boolean isRecommendationsLocked() { return recommendationsLocked; }
    public void setRecommendationsLocked(boolean recommendationsLocked) { this.recommendationsLocked = recommendationsLocked; }

    public BigDecimal getCarryAvg() { return carryAvg; }
    public void setCarryAvg(BigDecimal carryAvg) { this.carryAvg = carryAvg; }

    public BigDecimal getCarryMedian() { return carryMedian; }
    public void setCarryMedian(BigDecimal carryMedian) { this.carryMedian = carryMedian; }

    public BigDecimal getCarryStdDev() { return carryStdDev; }
    public void setCarryStdDev(BigDecimal carryStdDev) { this.carryStdDev = carryStdDev; }

    public BigDecimal getCarryMin() { return carryMin; }
    public void setCarryMin(BigDecimal carryMin) { this.carryMin = carryMin; }

    public BigDecimal getCarryMax() { return carryMax; }
    public void setCarryMax(BigDecimal carryMax) { this.carryMax = carryMax; }

    public BigDecimal getTotalAvg() { return totalAvg; }
    public void setTotalAvg(BigDecimal totalAvg) { this.totalAvg = totalAvg; }

    public BigDecimal getTotalMedian() { return totalMedian; }
    public void setTotalMedian(BigDecimal totalMedian) { this.totalMedian = totalMedian; }

    public BigDecimal getTotalStdDev() { return totalStdDev; }
    public void setTotalStdDev(BigDecimal totalStdDev) { this.totalStdDev = totalStdDev; }

    public BigDecimal getTotalMin() { return totalMin; }
    public void setTotalMin(BigDecimal totalMin) { this.totalMin = totalMin; }

    public BigDecimal getTotalMax() { return totalMax; }
    public void setTotalMax(BigDecimal totalMax) { this.totalMax = totalMax; }

    public BigDecimal getLeftRightAvg() { return leftRightAvg; }
    public void setLeftRightAvg(BigDecimal leftRightAvg) { this.leftRightAvg = leftRightAvg; }

    public BigDecimal getLeftRightStdDev() { return leftRightStdDev; }
    public void setLeftRightStdDev(BigDecimal leftRightStdDev) { this.leftRightStdDev = leftRightStdDev; }

    public BigDecimal getShortLongAvg() { return shortLongAvg; }
    public void setShortLongAvg(BigDecimal shortLongAvg) { this.shortLongAvg = shortLongAvg; }

    public BigDecimal getShortLongStdDev() { return shortLongStdDev; }
    public void setShortLongStdDev(BigDecimal shortLongStdDev) { this.shortLongStdDev = shortLongStdDev; }

    // ─── Enums ───────────────────────────────────────────────────────────────

    public enum SampleSizeLabel {
        /** Less than 5 shots — no stats displayed, recommendations locked. */
        INSUFFICIENT,
        /** 5–9 shots — limited confidence, recommendations locked. */
        LIMITED,
        /** 10–29 shots — moderate confidence, recommendations locked. */
        MODERATE,
        /** 30+ shots — robust sample, recommendations unlocked. */
        ROBUST
    }

    public enum ConfidenceLevel {
        INSUFFICIENT, LOW, MEDIUM, HIGH
    }

    // ─── Builder helper ───────────────────────────────────────────────────────

    /**
     * Derives sampleSizeLabel, confidenceLevel, and recommendationsLocked
     * from the current sampleSize value.
     * Call this after setting sampleSize.
     */
    public void deriveSampleQuality() {
        if (sampleSize < 5) {
            sampleSizeLabel = SampleSizeLabel.INSUFFICIENT;
            confidenceLevel = ConfidenceLevel.INSUFFICIENT;
            recommendationsLocked = true;
        } else if (sampleSize < 10) {
            sampleSizeLabel = SampleSizeLabel.LIMITED;
            confidenceLevel = ConfidenceLevel.LOW;
            recommendationsLocked = true;
        } else if (sampleSize < 30) {
            sampleSizeLabel = SampleSizeLabel.MODERATE;
            confidenceLevel = ConfidenceLevel.MEDIUM;
            recommendationsLocked = true;
        } else {
            sampleSizeLabel = SampleSizeLabel.ROBUST;
            confidenceLevel = ConfidenceLevel.HIGH;
            recommendationsLocked = false;
        }
    }
}
