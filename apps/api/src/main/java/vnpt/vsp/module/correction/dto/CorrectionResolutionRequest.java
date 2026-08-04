package vnpt.vsp.module.correction.dto;

import jakarta.validation.constraints.NotNull;

/**
 * Request body for POST /admin/corrections/{id}/resolve.
 * Per Story 9.3 AC-1 and AC-2.
 *
 * @param decision    REQUIRED — APPROVE or REJECT
 * @param reason      optional reviewer reason / notes
 * @param produceDraftChange REQUIRED for APPROVE — whether to create draft entity edits
 */
public record CorrectionResolutionRequest(
        @NotNull(message = "decision is required")
        Decision decision,

        String reason,

        @NotNull(message = "produceDraftChange is required")
        Boolean produceDraftChange
) {
    /** Resolution decision made by the reviewer. */
    public enum Decision {
        APPROVE,
        REJECT
    }
}
