package vnpt.vsp.module.ai;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * How many shots a golfer actually gets on this course, from this tee.
 *
 * <p>A handicap index is a measure of the golfer. It is not a number of
 * shots: the same 20-index receives more on a hard course from the back tees
 * than on an easy one from the front, and the Rules say by how much —
 *
 * <pre>Course Handicap = Index × (Slope ÷ 113) + (Course Rating − Par)</pre>
 *
 * <p>113 is the slope of a course of average difficulty, which is what makes
 * the ratio a multiplier rather than a unit. The rating term is the second
 * half and the one people forget: a course rated 74.5 to a par of 72 plays
 * two and a half shots harder than its par admits, for everybody.
 *
 * <p>Nine holes take half the index and the nine's own rating and par.
 *
 * <h2>Silence where the club published nothing</h2>
 *
 * <p>No Vietnamese card in this database carries a rating yet — the box is
 * printed on many of them and nobody has photographed one into the system.
 * Without both numbers this returns the index unchanged, which is what the
 * app did before and is honest: it is the golfer's own measure, applied
 * without a course adjustment nobody can compute.
 */
public final class CourseHandicap {

    /// The slope of a course of average difficulty. Fixed by the Rules.
    private static final BigDecimal NEUTRAL_SLOPE = new BigDecimal("113");

    private CourseHandicap() {}

    /**
     * The playing handicap, or {@code index} where the club published no
     * rating.
     *
     * @param index      the golfer's handicap index; null returns null
     * @param slope      slope rating of the tee played, 55–155
     * @param rating     course rating of the tee played
     * @param par        par of what is being played — the nine or the eighteen
     * @param holes      9 or 18
     */
    public static BigDecimal playing(BigDecimal index, Integer slope,
                                     BigDecimal rating, Integer par, int holes) {
        if (index == null) {
            return null;
        }
        if (slope == null || rating == null || par == null) {
            return index;
        }
        // Nine holes are played off half the index, against the nine's own
        // rating and par — which is what a nine-hole rating is.
        BigDecimal effectiveIndex = holes == 9
                ? index.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP)
                : index;

        BigDecimal slopeAdjusted = effectiveIndex
                .multiply(new BigDecimal(slope))
                .divide(NEUTRAL_SLOPE, 4, RoundingMode.HALF_UP);
        BigDecimal ratingAdjustment = rating.subtract(new BigDecimal(par));

        return slopeAdjusted.add(ratingAdjustment).setScale(1, RoundingMode.HALF_UP);
    }
}
