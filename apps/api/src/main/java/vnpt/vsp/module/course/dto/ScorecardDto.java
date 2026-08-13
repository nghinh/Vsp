package vnpt.vsp.module.course.dto;

import java.math.BigDecimal;
import java.util.List;

/** A published card, as the phone and the portal read it. */
public record ScorecardDto(
        Long scorecardId,
        Long facilityId,
        String name,
        Integer holesCount,
        Integer parTotal,
        List<Long> segmentCourseIds,
        List<Line> holes,
        List<Tee> tees) {

    /** One numbered line: the hole the golfer counts, its par and its index. */
    public record Line(Integer hole, Integer par, Integer strokeIndex) {}

    /**
     * One tee row of the card, in the order the card prints them.
     *
     * <p>Course rating and slope are the only ones in the database at all —
     * neither {@code courses} nor {@code tee_sets} has ever had a column for
     * them — so a client that wants to tell the golfer what they are playing,
     * or work a handicap differential out of what they shot, has this and
     * nothing else to read.
     *
     * <p>Both ratings are nullable and often absent together: a card
     * photographed with its rating table outside the frame still publishes its
     * yardages, and a card that prints yardages and no ratings at all is
     * common enough.
     */
    public record Tee(
            String name,
            BigDecimal courseRating,
            Integer slopeRating,
            List<Yardage> yardages) {}

    /** What one tee measures on one hole, by the card's numbering. */
    public record Yardage(Integer hole, Integer yards) {}
}
