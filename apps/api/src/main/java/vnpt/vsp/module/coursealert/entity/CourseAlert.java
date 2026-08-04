package vnpt.vsp.module.coursealert.entity;

import jakarta.persistence.*;
import vnpt.vsp.module.course.entity.DataQualityMetadata;
import vnpt.vsp.module.course.entity.VerificationStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * JPA entity representing a course operation alert sent to golfers.
 * Per Story 8.6 AC-1: supports facility, course, hole, flight, or group targeting.
 * Per Story 8.6 AC-2: alertType drives visual distinction (safety vs promotion).
 * Per Story 8.6 AC-3: delivery, expiry, acknowledgment, and audit status are recorded.
 */
@Entity
@Table(name = "course_alerts", indexes = {
        @Index(name = "idx_course_alert_facility", columnList = "facility_id"),
        @Index(name = "idx_course_alert_course", columnList = "course_id"),
        @Index(name = "idx_course_alert_hole", columnList = "hole_id"),
        @Index(name = "idx_course_alert_flight", columnList = "flight_id"),
        @Index(name = "idx_course_alert_group", columnList = "group_id"),
        @Index(name = "idx_course_alert_type", columnList = "alert_type"),
        @Index(name = "idx_course_alert_delivery", columnList = "delivery_status"),
        @Index(name = "idx_course_alert_effective", columnList = "effective_at"),
        @Index(name = "idx_course_alert_expires", columnList = "expires_at")
})
public class CourseAlert {

    // ─── Primary key ─────────────────────────────────────────────────────────

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ─── Targeting fields (AC-1) ─────────────────────────────────────────────

    @Column(name = "facility_id")
    private UUID facilityId;

    @Column(name = "course_id")
    private UUID courseId;

    @Column(name = "hole_id")
    private UUID holeId;

    @Column(name = "flight_id")
    private UUID flightId;

    @Column(name = "group_id")
    private UUID groupId;

    // ─── Alert classification (AC-2) ───────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "alert_type", nullable = false, length = 20)
    private AlertType alertType;

    // ─── Alert content ────────────────────────────────────────────────────────

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Column(nullable = false)
    private Integer priority = 0;

    // ─── Timing (AC-3) ───────────────────────────────────────────────────────

    @Column(name = "effective_at", nullable = false)
    private OffsetDateTime effectiveAt;

    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;

    // ─── Delivery tracking (AC-3) ────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "delivery_status", nullable = false, length = 20)
    private DeliveryStatus deliveryStatus = DeliveryStatus.PENDING;

    // ─── Acknowledgment (AC-3) ───────────────────────────────────────────────

    @Column(name = "acknowledgment_required", nullable = false)
    private Boolean acknowledgmentRequired = false;

    @Column(name = "acknowledged_at")
    private Instant acknowledgedAt;

    @Column(name = "acknowledged_by")
    private String acknowledgedBy;

    // ─── Audit & versioning ──────────────────────────────────────────────────

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by", nullable = false)
    private String createdBy;

    @Column(name = "published_version", nullable = false)
    private Integer publishedVersion = 1;

    // ─── Data quality fields (Architecture §9.3) ─────────────────────────────

    @Column
    private String source;

    @Column
    private String license;

    @Column(name = "accuracy_class")
    private String accuracyClass;

    @Column(precision = 5, scale = 2)
    private BigDecimal confidence = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(name = "verification_status")
    private VerificationStatus verificationStatus = VerificationStatus.UNVERIFIED;

    @Column(nullable = false)
    private Integer version = 1;

    // ─── Lifecycle callbacks ─────────────────────────────────────────────────

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        if (effectiveAt == null) {
            effectiveAt = OffsetDateTime.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        // no-op: immutable after creation per append-only design
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public UUID getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(UUID facilityId) {
        this.facilityId = facilityId;
    }

    public UUID getCourseId() {
        return courseId;
    }

    public void setCourseId(UUID courseId) {
        this.courseId = courseId;
    }

    public UUID getHoleId() {
        return holeId;
    }

    public void setHoleId(UUID holeId) {
        this.holeId = holeId;
    }

    public UUID getFlightId() {
        return flightId;
    }

    public void setFlightId(UUID flightId) {
        this.flightId = flightId;
    }

    public UUID getGroupId() {
        return groupId;
    }

    public void setGroupId(UUID groupId) {
        this.groupId = groupId;
    }

    public AlertType getAlertType() {
        return alertType;
    }

    public void setAlertType(AlertType alertType) {
        this.alertType = alertType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getBody() {
        return body;
    }

    public void setBody(String body) {
        this.body = body;
    }

    public Integer getPriority() {
        return priority;
    }

    public void setPriority(Integer priority) {
        this.priority = priority;
    }

    public OffsetDateTime getEffectiveAt() {
        return effectiveAt;
    }

    public void setEffectiveAt(OffsetDateTime effectiveAt) {
        this.effectiveAt = effectiveAt;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(OffsetDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public DeliveryStatus getDeliveryStatus() {
        return deliveryStatus;
    }

    public void setDeliveryStatus(DeliveryStatus deliveryStatus) {
        this.deliveryStatus = deliveryStatus;
    }

    public Boolean getAcknowledgmentRequired() {
        return acknowledgmentRequired;
    }

    public void setAcknowledgmentRequired(Boolean acknowledgmentRequired) {
        this.acknowledgmentRequired = acknowledgmentRequired;
    }

    public Instant getAcknowledgedAt() {
        return acknowledgedAt;
    }

    public void setAcknowledgedAt(Instant acknowledgedAt) {
        this.acknowledgedAt = acknowledgedAt;
    }

    public String getAcknowledgedBy() {
        return acknowledgedBy;
    }

    public void setAcknowledgedBy(String acknowledgedBy) {
        this.acknowledgedBy = acknowledgedBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Integer getPublishedVersion() {
        return publishedVersion;
    }

    public void setPublishedVersion(Integer publishedVersion) {
        this.publishedVersion = publishedVersion;
    }

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

    public String getAccuracyClass() {
        return accuracyClass;
    }

    public void setAccuracyClass(String accuracyClass) {
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

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }
}
