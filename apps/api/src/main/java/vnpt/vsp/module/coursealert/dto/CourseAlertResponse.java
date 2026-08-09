package vnpt.vsp.module.coursealert.dto;

import vnpt.vsp.module.coursealert.entity.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Response DTO for a course alert.
 * Per Story 8.6 AC-1, AC-2, AC-3.
 */
public class CourseAlertResponse {

    private Long id;

    // Targeting fields (AC-1)
    private Long facilityId;
    private Long courseId;
    private Long holeId;
    private UUID flightId;
    private UUID groupId;

    // Alert classification (AC-2)
    private AlertType alertType;

    // Content
    private String title;
    private String body;
    private Integer priority;

    // Timing
    private OffsetDateTime effectiveAt;
    private OffsetDateTime expiresAt;

    // Delivery tracking (AC-3)
    private DeliveryStatus deliveryStatus;
    private Instant deliveredAt;

    // Acknowledgment (AC-3)
    private Boolean acknowledgmentRequired;
    private Instant acknowledgedAt;
    private String acknowledgedBy;

    // Audit fields
    private Instant createdAt;
    private String createdBy;
    private Integer publishedVersion;

    // Data quality fields (Architecture §9.3)
    private String source;
    private String license;
    private String accuracyClass;
    private BigDecimal confidence;
    private String verificationStatus;
    private Integer version;

    // ─── Factory method ───────────────────────────────────────────────────

    public static CourseAlertResponse fromEntity(CourseAlert alert) {
        CourseAlertResponse r = new CourseAlertResponse();
        r.setId(alert.getId());
        r.setFacilityId(alert.getFacilityId());
        r.setCourseId(alert.getCourseId());
        r.setHoleId(alert.getHoleId());
        r.setFlightId(alert.getFlightId());
        r.setGroupId(alert.getGroupId());
        r.setAlertType(alert.getAlertType());
        r.setTitle(alert.getTitle());
        r.setBody(alert.getBody());
        r.setPriority(alert.getPriority());
        r.setEffectiveAt(alert.getEffectiveAt());
        r.setExpiresAt(alert.getExpiresAt());
        r.setDeliveryStatus(alert.getDeliveryStatus());
        r.setAcknowledgmentRequired(alert.getAcknowledgmentRequired());
        r.setAcknowledgedAt(alert.getAcknowledgedAt());
        r.setAcknowledgedBy(alert.getAcknowledgedBy());
        r.setCreatedAt(alert.getCreatedAt());
        r.setCreatedBy(alert.getCreatedBy());
        r.setPublishedVersion(alert.getPublishedVersion());
        r.setSource(alert.getSource());
        r.setLicense(alert.getLicense());
        r.setAccuracyClass(alert.getAccuracyClass());
        r.setConfidence(alert.getConfidence());
        r.setVerificationStatus(alert.getVerificationStatus() != null ? alert.getVerificationStatus().name() : null);
        r.setVersion(alert.getVersion());
        return r;
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getFacilityId() { return facilityId; }
    public void setFacilityId(Long facilityId) { this.facilityId = facilityId; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getHoleId() { return holeId; }
    public void setHoleId(Long holeId) { this.holeId = holeId; }

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }

    public UUID getGroupId() { return groupId; }
    public void setGroupId(UUID groupId) { this.groupId = groupId; }

    public AlertType getAlertType() { return alertType; }
    public void setAlertType(AlertType alertType) { this.alertType = alertType; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }

    public Integer getPriority() { return priority; }
    public void setPriority(Integer priority) { this.priority = priority; }

    public OffsetDateTime getEffectiveAt() { return effectiveAt; }
    public void setEffectiveAt(OffsetDateTime effectiveAt) { this.effectiveAt = effectiveAt; }

    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime expiresAt) { this.expiresAt = expiresAt; }

    public DeliveryStatus getDeliveryStatus() { return deliveryStatus; }
    public void setDeliveryStatus(DeliveryStatus deliveryStatus) { this.deliveryStatus = deliveryStatus; }

    public Instant getDeliveredAt() { return deliveredAt; }
    public void setDeliveredAt(Instant deliveredAt) { this.deliveredAt = deliveredAt; }

    public Boolean getAcknowledgmentRequired() { return acknowledgmentRequired; }
    public void setAcknowledgmentRequired(Boolean acknowledgmentRequired) { this.acknowledgmentRequired = acknowledgmentRequired; }

    public Instant getAcknowledgedAt() { return acknowledgedAt; }
    public void setAcknowledgedAt(Instant acknowledgedAt) { this.acknowledgedAt = acknowledgedAt; }

    public String getAcknowledgedBy() { return acknowledgedBy; }
    public void setAcknowledgedBy(String acknowledgedBy) { this.acknowledgedBy = acknowledgedBy; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public String getCreatedBy() { return createdBy; }
    public void setCreatedBy(String createdBy) { this.createdBy = createdBy; }

    public Integer getPublishedVersion() { return publishedVersion; }
    public void setPublishedVersion(Integer publishedVersion) { this.publishedVersion = publishedVersion; }

    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }

    public String getLicense() { return license; }
    public void setLicense(String license) { this.license = license; }

    public String getAccuracyClass() { return accuracyClass; }
    public void setAccuracyClass(String accuracyClass) { this.accuracyClass = accuracyClass; }

    public BigDecimal getConfidence() { return confidence; }
    public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }

    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }
}
