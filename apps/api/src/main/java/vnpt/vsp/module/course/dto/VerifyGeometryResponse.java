package vnpt.vsp.module.course.dto;

import java.time.Instant;
import java.util.List;

/**
 * Outcome of a review.
 *
 * @param verifiedHoleNumbers holes now marked VERIFIED
 * @param refusedHoleNumbers  holes the service would not verify, because their
 *                            coordinates are still the seed's invention — there
 *                            is nothing there to confirm
 * @param verifiedAt          when
 * @param reviewer            who, as recorded in the audit trail
 */
public record VerifyGeometryResponse(
        List<Integer> verifiedHoleNumbers,
        List<Integer> refusedHoleNumbers,
        Instant verifiedAt,
        String reviewer
) {}
