package vnpt.vsp.module.coursealert.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import vnpt.vsp.module.coursealert.entity.AlertType;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Request DTO for creating and sending a course alert.
 * Per Story 8.6 AC-1: targeting scope; AC-2: alertType visual distinction; AC-3: delivery/expiry/acknowledge.
 */
public class CourseAlertCreateRequest {

    // ─── Targeting fields (at least one required) ───────────────────────────

    private UUID facilityId;
    private UUID courseId;
    private UUID holeId;
    private UUID flightId;
    private UUID groupId;

    // ─── Alert classification (AC-2: visual distinction) ─────────────────────

    @NotNull(message = "alertType is required")
    private AlertType alertType;

    // ─── Content ─────────────────────────────────────────────────────────────

    @NotBlank(message = "title is required")
    @Size(max = 120, message = "title must not exceed 120 characters")
    private String title;

    @NotBlank(message = "body is required")
    @Size(max = 500, message = "body must not exceed 500 characters")
    private String body;

    // ─── Timing ──────────────────────────────────────────────────────────────

    private OffsetDateTime effectiveAt;
    private OffsetDateTime expiresAt;

    // ─── Acknowledgment (AC-3) ─────────────────────────────────────────────

    private Boolean acknowledgmentRequired = false;

    // ─── Priority ────────────────────────────────────────────────────────────

    private String priority = "NORMAL";

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getFacilityId() { return facilityId; }
    public void setFacilityId(UUID facilityId) { this.facilityId = facilityId; }

    public UUID getCourseId() { return courseId; }
    public void setCourseId(UUID courseId) { this.courseId = courseId; }

    public UUID getHoleId() { return holeId; }
    public void setHoleId(UUID holeId) { this.holeId = holeId; }

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

    public OffsetDateTime getEffectiveAt() { return effectiveAt; }
    public void setEffectiveAt(OffsetDateTime effectiveAt) { this.effectiveAt = effectiveAt; }

    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime expiresAt) { this.expiresAt = expiresAt; }

    public Boolean getAcknowledgmentRequired() { return acknowledgmentRequired; }
    public void setAcknowledgmentRequired(Boolean acknowledgmentRequired) { this.acknowledgmentRequired = acknowledgmentRequired; }

    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }

    /**
     * Returns true if at least one targeting field is set.
     */
    public boolean hasTargeting() {
        return facilityId != null || courseId != null || holeId != null || flightId != null || groupId != null;
    }
}
