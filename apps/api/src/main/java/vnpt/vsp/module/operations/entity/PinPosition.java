package vnpt.vsp.module.operations.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.operations.OperationsModule;

/**
 * PinPosition entity — pin location with temporal scheduling for operations portal.
  * Per Story 8.5 AC-1: place/schedule pins with effective + expiration times.
  * Per Architecture §7.3: effective and expiration timestamps for temporal queries.
  *
  * <p>Uses PostGIS POINT with SRID 4326 for pin geometry.
  * Active pins are queried as: now() BETWEEN effectiveFrom AND expiresAt
  * (or expiresAt IS NULL for indefinite).</p>
 */
@Entity(name = "OperationsPinPosition")
@Table(name = "pin_positions_ops")
@OperationsModule
public class PinPosition {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Hole this pin position applies to */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hole_id", nullable = false)
    private Hole hole;

    /** Pin coordinates as PostGIS POINT with SRID 4326 (WGS84) */
    @Column(columnDefinition = "geometry(Point,4326)")
    private String location;

    /** Pin position type: CURRENT, TOURNAMENT, PRACTICE, etc. */
    @Column(name = "pin_position_type", length = 20)
    private String pinPositionType = "CURRENT";

    /** When this pin position becomes active (inclusive) */
    @Column(name = "effective_from", nullable = false)
    private Instant effectiveFrom;

    /** When this pin position expires (NULL = never expires) */
    @Column(name = "expires_at")
    private Instant expiresAt;

    /** User who published/scheduled this pin position */
    @Column(name = "published_by", nullable = false)
    private String publishedBy;

    /** Confidence score 0.0 – 1.0 for this pin position */
    @Column(name = "confidence", precision = 5, scale = 2)
    private BigDecimal confidence;

    /** Shared data quality metadata — source, license, accuracy, verification */
    @Embedded
    @AttributeOverride(name = "confidence", column = @Column(name = "confidence", insertable = false, updatable = false))
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

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    public String getPinPositionType() {
        return pinPositionType;
    }

    public void setPinPositionType(String pinPositionType) {
        this.pinPositionType = pinPositionType;
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

    public BigDecimal getConfidence() {
        return confidence;
    }

    public void setConfidence(BigDecimal confidence) {
        this.confidence = confidence;
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
