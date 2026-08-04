package vnpt.vsp.module.privacy.dto;

import vnpt.vsp.module.privacy.entity.PrivacyRequest;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.RequestType;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.Status;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for a privacy request.
 * Per Story 2.5 AC-3: includes request type, status, target round, timestamps.
 */
public class PrivacyRequestResponse {

    private Long id;
    private Long requesterGolferAccountId;
    private String requestType;
    private String status;
    private UUID targetRoundId;
    private Instant requestedAt;
    private Instant processedAt;
    private Long processedBy;
    private String rejectionReason;
    private Instant createdAt;
    private Instant updatedAt;

    public PrivacyRequestResponse() {
    }

    public static PrivacyRequestResponse fromEntity(PrivacyRequest entity) {
        PrivacyRequestResponse dto = new PrivacyRequestResponse();
        dto.setId(entity.getId());
        dto.setRequesterGolferAccountId(entity.getRequesterGolferAccountId());
        dto.setRequestType(entity.getRequestType().name());
        dto.setStatus(entity.getStatus().name());
        dto.setTargetRoundId(entity.getTargetRoundId());
        dto.setRequestedAt(entity.getRequestedAt());
        dto.setProcessedAt(entity.getProcessedAt());
        dto.setProcessedBy(entity.getProcessedBy());
        dto.setRejectionReason(entity.getRejectionReason());
        dto.setCreatedAt(entity.getCreatedAt());
        dto.setUpdatedAt(entity.getUpdatedAt());
        return dto;
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRequesterGolferAccountId() {
        return requesterGolferAccountId;
    }

    public void setRequesterGolferAccountId(Long requesterGolferAccountId) {
        this.requesterGolferAccountId = requesterGolferAccountId;
    }

    public String getRequestType() {
        return requestType;
    }

    public void setRequestType(String requestType) {
        this.requestType = requestType;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public UUID getTargetRoundId() {
        return targetRoundId;
    }

    public void setTargetRoundId(UUID targetRoundId) {
        this.targetRoundId = targetRoundId;
    }

    public Instant getRequestedAt() {
        return requestedAt;
    }

    public void setRequestedAt(Instant requestedAt) {
        this.requestedAt = requestedAt;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt) {
        this.processedAt = processedAt;
    }

    public Long getProcessedBy() {
        return processedBy;
    }

    public void setProcessedBy(Long processedBy) {
        this.processedBy = processedBy;
    }

    public String getRejectionReason() {
        return rejectionReason;
    }

    public void setRejectionReason(String rejectionReason) {
        this.rejectionReason = rejectionReason;
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
}
