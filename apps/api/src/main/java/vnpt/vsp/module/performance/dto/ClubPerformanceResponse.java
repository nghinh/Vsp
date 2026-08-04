package vnpt.vsp.module.performance.dto;

import vnpt.vsp.module.performance.entity.ClubPerformance;
import vnpt.vsp.module.performance.entity.ClubPerformanceStats;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * API response DTO for per-club performance statistics.
 * Per Story 11.1 AC-1: all statistical fields plus sample quality and lock state.
 */
@vnpt.vsp.module.performance.PerformanceModule
public class ClubPerformanceResponse {

    private Long clubId;
    private Long bagId;

    // ─── Sample Quality ───────────────────────────────────────────────────────

    private int sampleSize;
    private ClubPerformanceStats.SampleSizeLabel sampleSizeLabel;
    private ClubPerformanceStats.ConfidenceLevel confidenceLevel;
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

    private BigDecimal leftRightAvg;
    private BigDecimal leftRightStdDev;
    private BigDecimal shortLongAvg;
    private BigDecimal shortLongStdDev;

    // ─── Staleness ───────────────────────────────────────────────────────────

    private Instant computedAt;
    private Instant basedOnShotAt;

    // ─── Factory Methods ─────────────────────────────────────────────────────

    public static ClubPerformanceResponse fromDomain(
            Long clubId,
            Long bagId,
            ClubPerformanceStats stats,
            Instant computedAt,
            Instant basedOnShotAt) {
        ClubPerformanceResponse response = new ClubPerformanceResponse();
        response.clubId = clubId;
        response.bagId = bagId;
        response.sampleSize = stats.getSampleSize();
        response.sampleSizeLabel = stats.getSampleSizeLabel();
        response.confidenceLevel = stats.getConfidenceLevel();
        response.recommendationsLocked = stats.isRecommendationsLocked();
        response.carryAvg = stats.getCarryAvg();
        response.carryMedian = stats.getCarryMedian();
        response.carryStdDev = stats.getCarryStdDev();
        response.carryMin = stats.getCarryMin();
        response.carryMax = stats.getCarryMax();
        response.totalAvg = stats.getTotalAvg();
        response.totalMedian = stats.getTotalMedian();
        response.totalStdDev = stats.getTotalStdDev();
        response.totalMin = stats.getTotalMin();
        response.totalMax = stats.getTotalMax();
        response.leftRightAvg = stats.getLeftRightAvg();
        response.leftRightStdDev = stats.getLeftRightStdDev();
        response.shortLongAvg = stats.getShortLongAvg();
        response.shortLongStdDev = stats.getShortLongStdDev();
        response.computedAt = computedAt;
        response.basedOnShotAt = basedOnShotAt;
        return response;
    }

    public static ClubPerformanceResponse fromEntity(ClubPerformance entity) {
        ClubPerformanceStats stats = entity.toDomain();
        return fromDomain(
                entity.getClubId(),
                entity.getGolfBagId(),
                stats,
                entity.getComputedAt(),
                entity.getBasedOnShotAt());
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public Long getClubId() { return clubId; }
    public void setClubId(Long clubId) { this.clubId = clubId; }

    public Long getBagId() { return bagId; }
    public void setBagId(Long bagId) { this.bagId = bagId; }

    public int getSampleSize() { return sampleSize; }
    public void setSampleSize(int sampleSize) { this.sampleSize = sampleSize; }

    public ClubPerformanceStats.SampleSizeLabel getSampleSizeLabel() { return sampleSizeLabel; }
    public void setSampleSizeLabel(ClubPerformanceStats.SampleSizeLabel sampleSizeLabel) { this.sampleSizeLabel = sampleSizeLabel; }

    public ClubPerformanceStats.ConfidenceLevel getConfidenceLevel() { return confidenceLevel; }
    public void setConfidenceLevel(ClubPerformanceStats.ConfidenceLevel confidenceLevel) { this.confidenceLevel = confidenceLevel; }

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

    public Instant getComputedAt() { return computedAt; }
    public void setComputedAt(Instant computedAt) { this.computedAt = computedAt; }

    public Instant getBasedOnShotAt() { return basedOnShotAt; }
    public void setBasedOnShotAt(Instant basedOnShotAt) { this.basedOnShotAt = basedOnShotAt; }
}
