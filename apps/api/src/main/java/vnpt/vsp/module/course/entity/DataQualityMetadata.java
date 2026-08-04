package vnpt.vsp.module.course.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

/**
 * Shared embeddable data-quality metadata carried by every course geometry entity.
 * Per Story 3.1 AC-3 and Architecture §7.4 Data Quality Model:
 * every data object carries source, license, quality, confidence, verification,
 * effective/expiry, publisher, and version metadata.
 *
 * <p>This is an {@link Embeddable} class — it has no own identity and is
 * inlined (as a column group) into every owning entity.  Column names are
 * fixed here; owning entities use {@link AttributeOverride} if the same
 * metadata block appears at a non-default position in the table.</p>
 */
@Embeddable
public class DataQualityMetadata {

    /** Origin of this data (e.g., provider name, survey team, community source) */
    @Column(name = "source")
    private String source;

    /** License governing use of this data (e.g., "CC BY 4.0", "Proprietary") */
    @Column(name = "license")
    private String license;

    /** Accuracy class — Per PRD §9.4 priority A → B → C → D */
    @Enumerated(EnumType.STRING)
    @Column(name = "accuracy_class")
    private AccuracyClass accuracyClass = AccuracyClass.D_UNVERIFIED_COMMUNITY;

    /** Confidence score 0.00 – 100.00 */
    @Column(name = "confidence", precision = 5, scale = 2)
    private BigDecimal confidence = BigDecimal.ZERO;

    /** Current verification state */
    @Enumerated(EnumType.STRING)
    @Column(name = "verification_status")
    private VerificationStatus verificationStatus = VerificationStatus.UNVERIFIED;

    /** Immutable creation timestamp */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** Last modification timestamp */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** When data was last verified by an authoritative source */
    @Column(name = "last_verified_at")
    private Instant lastVerifiedAt;

    /** When this data becomes authoritative (inclusive) */
    @Column(name = "effective_date", nullable = false)
    private LocalDate effectiveDate = LocalDate.now();

    /** When this data expires (NULL = never expires) */
    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    /** Entity responsible for publishing this data */
    @Column(name = "publisher", nullable = false)
    private String publisher;

    /** Monotonically increasing version number */
    @Column(name = "version", nullable = false)
    private Integer version = 1;

    @PrePersist
    public void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    public void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public String getLicense() {
        return license;
    }

    public void setLicense(String license) {
        this.license = license;
    }

    public AccuracyClass getAccuracyClass() {
        return accuracyClass;
    }

    public void setAccuracyClass(AccuracyClass accuracyClass) {
        this.accuracyClass = accuracyClass;
    }

    public BigDecimal getConfidence() {
        return confidence;
    }

    public void setConfidence(BigDecimal confidence) {
        this.confidence = confidence;
    }

    public VerificationStatus getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(VerificationStatus verificationStatus) {
        this.verificationStatus = verificationStatus;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    public Instant getLastVerifiedAt() {
        return lastVerifiedAt;
    }

    public void setLastVerifiedAt(Instant lastVerifiedAt) {
        this.lastVerifiedAt = lastVerifiedAt;
    }

    public LocalDate getEffectiveDate() {
        return effectiveDate;
    }

    public void setEffectiveDate(LocalDate effectiveDate) {
        this.effectiveDate = effectiveDate;
    }

    public LocalDate getExpiryDate() {
        return expiryDate;
    }

    public void setExpiryDate(LocalDate expiryDate) {
        this.expiryDate = expiryDate;
    }

    public String getPublisher() {
        return publisher;
    }

    public void setPublisher(String publisher) {
        this.publisher = publisher;
    }

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }
}
