package vnpt.vsp.module.operations.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.operations.OperationsModule;

/**
 * GreenCondition entity — green speed, firmness, and moisture readings per hole.
  * Per Story 8.5 AC-2: green speed (stimpmeter), firmness, moisture management.
  * Per Architecture §7.3: effective and expiration timestamps for temporal queries.
  *
  * <p>Stores per-hole green condition readings with temporal validity windows.
  * Active conditions are queried as: now() BETWEEN effectiveFrom AND expiresAt
  * (or expiresAt IS NULL for indefinite).</p>
 */
@Entity
@Table(name = "green_conditions")
@OperationsModule
public class GreenCondition {

    /** Green firmness level */
    public enum Firmness {
        SOFT, MEDIUM, FIRM, HARD
    }

    /** Green moisture level */
    public enum Moisture {
        DRY, NORMAL, WET, SATURATED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Hole this condition applies to */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

    /** Stimpmeter reading in feet — range 6-14 per AC-2 validation */
    @Column(name = "stimpmeter_reading", precision = 4, scale = 1)
    private BigDecimal stimpmeterReading;

    /** Green surface firmness */
    @Enumerated(EnumType.STRING)
    @Column(name = "firmness", length = 10)
    private Firmness firmness;

    /** Green surface moisture */
    @Enumerated(EnumType.STRING)
    @Column(name = "moisture", length = 15)
    private Moisture moisture;

    /** When this condition becomes active (inclusive) */
    @Column(name = "effective_from", nullable = false)
    private Instant effectiveFrom;

    /** When this condition expires (NULL = never expires) */
    @Column(name = "expires_at")
    private Instant expiresAt;

    /** User who recorded this condition */
    @Column(name = "published_by", nullable = false)
    private String publishedBy;

    /** Shared data quality metadata — source, license, accuracy, confidence, verification */
    @Embedded
    private DataQualityMetadata metadata = new DataQualityMetadata();

    @PrePersist
    protected void onCreate() {
        // JPA cascades @PrePersist to @Embedded; metadata timestamps set automatically
    }

    @PreUpdate
    protected void onUpdate() {
        // JPA cascades @PreUpdate to @Embedded; metadata timestamps set automatically
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Hole getHole() {
        return hole;
    }

    public void setHole(Hole hole) {
        this.hole = hole;
    }

    public BigDecimal getStimpmeterReading() {
        return stimpmeterReading;
    }

    public void setStimpmeterReading(BigDecimal stimpmeterReading) {
        this.stimpmeterReading = stimpmeterReading;
    }

    public Firmness getFirmness() {
        return firmness;
    }

    public void setFirmness(Firmness firmness) {
        this.firmness = firmness;
    }

    public Moisture getMoisture() {
        return moisture;
    }

    public void setMoisture(Moisture moisture) {
        this.moisture = moisture;
    }

    public Instant getEffectiveFrom() {
        return effectiveFrom;
    }

    public void setEffectiveFrom(Instant effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public String getPublishedBy() {
        return publishedBy;
    }

    public void setPublishedBy(String publishedBy) {
        this.publishedBy = publishedBy;
    }

    public DataQualityMetadata getMetadata() {
        return metadata;
    }

    /** Alias for getMetadata() — consistent with other entities */
    public DataQualityMetadata getDataQuality() {
        return metadata;
    }

    public void setMetadata(DataQualityMetadata metadata) {
        this.metadata = metadata;
    }
}
