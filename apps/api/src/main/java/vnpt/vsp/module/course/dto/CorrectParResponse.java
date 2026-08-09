package vnpt.vsp.module.course.dto;

import java.time.Instant;
import java.util.List;

/**
 * Outcome of a par correction.
 *
 * @param changedHoleNumbers  holes whose par is now different
 * @param unchangedHoleNumbers holes already carrying the par submitted — not an
 *                            error, and worth separating so a reviewer can see
 *                            their eighteen entries produced five changes
 * @param unknownHoleNumbers  hole numbers this course does not have
 * @param stillImplausible    holes whose new par still contradicts their
 *                            length. Applied anyway — a reviewer holding the
 *                            scorecard outranks a rule of thumb — but recorded,
 *                            because a scorecard and a measured length that
 *                            disagree mean one of them is wrong.
 * @param correctedAt         when
 * @param reviewer            who
 */
public record CorrectParResponse(
        List<Integer> changedHoleNumbers,
        List<Integer> unchangedHoleNumbers,
        List<Integer> unknownHoleNumbers,
        List<Integer> stillImplausible,
        Instant correctedAt,
        String reviewer
) {}
