package vnpt.vsp.module.coursealert.dto;

import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/**
 * Request DTO for updating a course alert.
 * Per Story 8.6 AC-3: updates only allowed before effectiveAt.
 */
public class CourseAlertUpdateRequest {

    @Size(max = 120, message = "title must not exceed 120 characters")
    private String title;

    @Size(max = 500, message = "body must not exceed 500 characters")
    private String body;

    private String priority;

    private OffsetDateTime effectiveAt;

    private OffsetDateTime expiresAt;

    // ─── Getters and Setters ───────────────────────────────────────────────

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }

    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }

    public OffsetDateTime getEffectiveAt() { return effectiveAt; }
    public void setEffectiveAt(OffsetDateTime effectiveAt) { this.effectiveAt = effectiveAt; }

    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime expiresAt) { this.expiresAt = expiresAt; }
}
