package vnpt.vsp.module.correction.dto;

import java.time.Instant;

/**
 * Response after a successful correction resolution (approve or reject).
 * Per Story 9.3 AC-1 (linked through publication), AC-2 (reporter notified),
 * and AC-3 (audit history).
 *
 * @param correctionId     ID of the resolved Correction
 * @param status           new status (APPROVED or REJECTED)
 * @param resultingVersionId ID of the DataVersion once the approved draft is published
 *                           (null until publish; populated by Story 9.4 Wave 4)
 * @param auditId          ID of the CORRECTION_RESOLVED audit entry
 * @param notifiedAt        Instant when the reporter notification was dispatched
 */
public record CorrectionResolutionResponse(
        Long correctionId,
        String status,
        Long resultingVersionId,
        Long auditId,
        Instant notifiedAt
) {}
