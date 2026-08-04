package vnpt.vsp.module.score.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for a successful score correction submission.
 * Per Story 5.5 Slice 4.
 */
public class ScoreCorrectionResponse {

    private UUID correctionId;
    private Instant appliedAt;
    private UUID auditId;

    public ScoreCorrectionResponse() {}

    public ScoreCorrectionResponse(UUID correctionId, Instant appliedAt, UUID auditId) {
        this.correctionId = correctionId;
        this.appliedAt = appliedAt;
        this.auditId = auditId;
    }

    public UUID getCorrectionId() { return correctionId; }
    public void setCorrectionId(UUID correctionId) { this.correctionId = correctionId; }
    public Instant getAppliedAt() { return appliedAt; }
    public void setAppliedAt(Instant appliedAt) { this.appliedAt = appliedAt; }
    public UUID getAuditId() { return auditId; }
    public void setAuditId(UUID auditId) { this.auditId = auditId; }
}
