package vnpt.vsp.module.correction.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.correction.entity.CorrectionReviewAction;

/**
 * Request DTO for the correction review action endpoint.
 *
 * <p>Per Story 9.2 AC-3: Reviewer can approve, reject, request information,
 * or convert to draft edit.</p>
 *
 * <ul>
 *   <li>{@code APPROVE} — no reason required; creates audit entry, status → APPROVED</li>
 *   <li>{@code REJECT} — reason required; status → REJECTED</li>
 *   <li>{@code REQUEST_INFO} — message required; status → INFO_REQUESTED</li>
 *   <li>{@code CONVERT_TO_DRAFT} — optional note; creates draft in geometry editor</li>
 * </ul>
 *
 * Per Slice Plan §Slice A.
 */
public class CorrectionReviewRequest {

    @NotNull(message = "Action is required")
    private CorrectionReviewAction action;

    /**
     * Human-readable reason for REJECT or REQUEST_INFO.
     * Required for REJECT and REQUEST_INFO.
     */
    private String reason;

    /**
     * Optional reviewer note (visible in audit trail).
     */
    private String note;

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public CorrectionReviewAction getAction() { return action; }
    public void setAction(CorrectionReviewAction action) { this.action = action; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
}
