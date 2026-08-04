package vnpt.vsp.module.operations.dto;

import java.time.Instant;

/**
 * Request DTO for updating an existing course condition.
 * Per Story 8.5 AC-2: update course status, maintenance, alerts.
 */
public class CourseConditionUpdateRequest {

    private String conditionType; // GREEN_SPEED, GREEN_FIRMNESS, FAIRWAY_FIRMNESS, etc.
    private String severity;  // LOW, MODERATE, HIGH, CRITICAL
    private String description;
    private Instant effectiveFrom;
    private Instant expiresAt;

    // Getters / Setters

    public String getConditionType() {
        return conditionType;
    }

    public void setConditionType(String conditionType) {
        this.conditionType = conditionType;
    }

    public String getSeverity() {
        return severity;
    }

    public void setSeverity(String severity) {
        this.severity = severity;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
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
}
