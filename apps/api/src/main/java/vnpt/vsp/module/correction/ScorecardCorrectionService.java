package vnpt.vsp.module.correction;

import vnpt.vsp.module.correction.dto.ScorecardSubmissionRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;

/**
 * Scorecards arrive the way every other course correction does: a golfer
 * submits, an admin decides.
 */
public interface ScorecardCorrectionService {

    /** Queue a proposed card for review. */
    CourseCorrection submit(Long courseId, Long reporterId, ScorecardSubmissionRequest request);

    /**
     * Write an approved card into {@code scorecards}.
     *
     * <p>Called from the review flow when the approved correction is a
     * SCORECARD; a no-op for every other type.
     */
    void applyIfScorecard(CourseCorrection correction);
}
