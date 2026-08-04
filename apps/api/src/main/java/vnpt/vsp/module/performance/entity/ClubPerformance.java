package vnpt.vsp.module.performance.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Cached club performance statistics entity.
 * Per Story 11.1 Slice 1: computed stats cached in club_performance table,
 * invalidated on new shot sync.
 *
 * <p>Stores all ClubPerformanceStats fields plus ownership and staleness metadata.
 */
@Entity
@Table(name = "club_performance", indexes = {
    @Index(name = "idx_club_perf_club", columnList = "club_id"),
    @Index(name = "idx_club_perf_bag", columnList = "golf_bag_id"),
    @Index(name = "idx_club_perf_golfer", columnList = "golfer_account_id")
})
@vnpt.vsp.module.performance.PerformanceModule
public class ClubPerformance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** The club these stats belong to. */
    @Column(name = "club_id", nullable = false)
    private Long clubId;

    /** The bag containing the club (denormalised for faster queries). */
    @Column(name = "golf_bag_id", nullable = false)
    private Long golfBagId;

    /** The golfer who owns the bag. */
    @Column(name = "golfer_account_id", nullable = false)
    private Long golferAccountId;

    // ─── Sample Quality ───────────────────────────────────────────────────────

    @Column(name = "sample_size", nullable = false)
    private int sampleSize;

    @Enumerated(EnumType.STRING)
    @Column(name = "sample_size_label", length = 20, nullable = false)
    private ClubPerformanceStats.SampleSizeLabel sampleSizeLabel;

    @Enumerated(EnumType.STRING)
    @Column(name = "confidence_level", length = 20, nullable = false)
    private ClubPerformanceStats.ConfidenceLevel confidenceLevel;

    @Column(name = "recommendations_locked", nullable = false)
    private boolean recommendationsLocked;

    // ─── Carry Distance Stats (meters) ───────────────────────────────────────

    @Column(name = "carry_avg", precision = 10, scale = 2)
    private BigDecimal carryAvg;

    @Column(name = "carry_median", precision = 10, scale = 2)
    private BigDecimal carryMedian;

    @Column(name = "carry_std_dev", precision = 10, scale = 2)
    private BigDecimal carryStdDev;

    @Column(name = "carry_min", precision = 10, scale = 2)
    private BigDecimal carryMin;

    @Column(name = "carry_max", precision = 10, scale = 2)
    private BigDecimal carryMax;

    // ─── Total Distance Stats (meters) ────────────────────────────────────────

    @Column(name = "total_avg", precision = 10, scale = 2)
    private BigDecimal totalAvg;

    @Column(name = "total_median", precision = 10, scale = 2)
    private BigDecimal totalMedian;

    @Column(name = "total_std_dev", precision = 10, scale = 2)
    private BigDecimal totalStdDev;

    @Column(name = "total_min", precision = 10, scale = 2)
    private BigDecimal totalMin;

    @Column(name = "total_max", precision = 10, scale = 2)
    private BigDecimal totalMax;

    // ─── Directional Deviation Stats (meters) ────────────────────────────────

    @Column(name = "left_right_avg", precision = 10, scale = 2)
    private BigDecimal leftRightAvg;

    @Column(name = "left_right_std_dev", precision = 10, scale = 2)
    private BigDecimal leftRightStdDev;

    @Column(name = "short_long_avg", precision = 10, scale = 2)
    private BigDecimal shortLongAvg;

    @Column(name = "short_long_std_dev", precision = 10, scale = 2)
    private BigDecimal shortLongStdDev;

    // ─── Staleness ───────────────────────────────────────────────────────────

    /** When these stats were last computed. */
    @Column(name = "computed_at", nullable = false)
    private Instant computedAt;

    /** The most recent shot timestamp used in the computation. */
    @Column(name = "based_on_shot_at")
    private Instant basedOnShotAt;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
        if (computedAt == null) computedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Conversion from Domain ───────────────────────────────────────────────

    /**
     * Populate this entity from a {@link ClubPerformanceStats} domain object.
     */
    public void fromDomain(ClubPerformanceStats stats) {
        this.sampleSize = stats.getSampleSize();
        this.sampleSizeLabel = stats.getSampleSizeLabel();
        this.confidenceLevel = stats.getConfidenceLevel();
        this.recommendationsLocked = stats.isRecommendationsLocked();
        this.carryAvg = stats.getCarryAvg();
        this.carryMedian = stats.getCarryMedian();
        this.carryStdDev = stats.getCarryStdDev();
        this.carryMin = stats.getCarryMin();
        this.carryMax = stats.getCarryMax();
        this.totalAvg = stats.getTotalAvg();
        this.totalMedian = stats.getTotalMedian();
        this.totalStdDev = stats.getTotalStdDev();
        this.totalMin = stats.getTotalMin();
        this.totalMax = stats.getTotalMax();
        this.leftRightAvg = stats.getLeftRightAvg();
        this.leftRightStdDev = stats.getLeftRightStdDev();
        this.shortLongAvg = stats.getShortLongAvg();
        this.shortLongStdDev = stats.getShortLongStdDev();
    }

    /**
     * Convert this entity to a {@link ClubPerformanceStats} domain object.
     */
    public ClubPerformanceStats toDomain() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(this.sampleSize);
        stats.setSampleSizeLabel(this.sampleSizeLabel);
        stats.setConfidenceLevel(this.confidenceLevel);
        stats.setRecommendationsLocked(this.recommendationsLocked);
        stats.setCarryAvg(this.carryAvg);
        stats.setCarryMedian(this.carryMedian);
        stats.setCarryStdDev(this.carryStdDev);
        stats.setCarryMin(this.carryMin);
        stats.setCarryMax(this.carryMax);
        stats.setTotalAvg(this.totalAvg);
        stats.setTotalMedian(this.totalMedian);
        stats.setTotalStdDev(this.totalStdDev);
        stats.setTotalMin(this.totalMin);
        stats.setTotalMax(this.totalMax);
        stats.setLeftRightAvg(this.leftRightAvg);
        stats.setLeftRightStdDev(this.leftRightStdDev);
        stats.setShortLongAvg(this.shortLongAvg);
        stats.setShortLongStdDev(this.shortLongStdDev);
        return stats;
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getClubId() { return clubId; }
    public void setClubId(Long clubId) { this.clubId = clubId; }

    public Long getGolfBagId() { return golfBagId; }
    public void setGolfBagId(Long golfBagId) { this.golfBagId = golfBagId; }

    public Long getGolferAccountId() { return golferAccountId; }
    public void setGolferAccountId(Long golferAccountId) { this.golferAccountId = golferAccountId; }

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

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
