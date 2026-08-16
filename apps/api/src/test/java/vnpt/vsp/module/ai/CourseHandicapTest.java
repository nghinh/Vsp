package vnpt.vsp.module.ai;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The Rules' arithmetic for turning an index into shots on one course.
 *
 * <p>Computed rather than asked of anything: a wrong playing handicap moves
 * every net score on the card and every settlement built on it.
 */
class CourseHandicapTest {

    private static BigDecimal playing(String index, Integer slope, String rating,
                                      Integer par, int holes) {
        return CourseHandicap.playing(
                index == null ? null : new BigDecimal(index),
                slope,
                rating == null ? null : new BigDecimal(rating),
                par, holes);
    }

    /// A course of average difficulty rated exactly to its par gives the
    /// index back — the definition of 113 and of a neutral rating.
    @Test
    @DisplayName("an average course rated at par returns the index")
    void neutralCourseChangesNothing() {
        assertThat(playing("20.0", 113, "72.0", 72, 18))
                .isEqualByComparingTo("20.0");
    }

    /// The half everyone forgets: a course rated above its par plays harder
    /// than par for everybody, scratch included.
    @Test
    @DisplayName("a course rated above par hands out the difference")
    void theRatingTermCounts() {
        assertThat(playing("0.0", 113, "74.5", 72, 18))
                .isEqualByComparingTo("2.5");
    }

    @Test
    @DisplayName("slope scales the index, 113 being average")
    void slopeScalesTheIndex() {
        // 20 × 138/113 = 24.4, plus (72 − 72).
        assertThat(playing("20.0", 138, "72.0", 72, 18))
                .isEqualByComparingTo("24.4");
        // An easier-than-average course gives fewer.
        assertThat(playing("20.0", 100, "72.0", 72, 18))
                .isEqualByComparingTo("17.7");
    }

    @Test
    @DisplayName("both halves together")
    void slopeAndRatingTogether() {
        // 28 × 130/113 = 32.2, plus (73.4 − 72) = 1.4 → 33.6
        assertThat(playing("28.0", 130, "73.4", 72, 18))
                .isEqualByComparingTo("33.6");
    }

    /// Nine holes are played off half an index, against the nine's own
    /// rating and par.
    @Test
    @DisplayName("nine holes take half the index")
    void nineHolesHalveTheIndex() {
        assertThat(playing("20.0", 113, "36.0", 36, 9))
                .isEqualByComparingTo("10.0");
    }

    /// No Vietnamese card in this database carries a rating yet. Without one
    /// the index stands — the app's answer before any of this existed.
    @Test
    @DisplayName("an unrated course returns the index untouched")
    void unratedCourseFallsBackToTheIndex() {
        assertThat(playing("20.0", null, "72.0", 72, 18))
                .isEqualByComparingTo("20.0");
        assertThat(playing("20.0", 130, null, 72, 18))
                .isEqualByComparingTo("20.0");
        assertThat(playing("20.0", 130, "73.4", null, 18))
                .isEqualByComparingTo("20.0");
    }

    @Test
    @DisplayName("no index is no answer")
    void noIndexIsNull() {
        assertThat(playing(null, 130, "73.4", 72, 18)).isNull();
    }

    /// A plus handicap still gets the rating adjustment, and can cross zero.
    @Test
    @DisplayName("a plus handicap keeps its sign through the arithmetic")
    void plusHandicapsSurvive() {
        // −2 × 113/113 = −2, plus 1.5 → −0.5
        assertThat(playing("-2.0", 113, "73.5", 72, 18))
                .isEqualByComparingTo("-0.5");
    }
}
