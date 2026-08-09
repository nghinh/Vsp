package vnpt.vsp.module.course;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for catching a par its own hole contradicts.
 *
 * <p>Par came from the seed script that invented the coordinates, and the OSM
 * import replaced every length with a measured one while leaving par alone. The
 * two now disagree on 42 of the 100 matched holes. Long Thành ships a par 5 of
 * 326 m and a par 4 of 476 m, and every over/under-par figure on the scorecard
 * is arithmetic against those.</p>
 *
 * <p>The bands are deliberately loose. A rule that flagged unusual holes would
 * bury the impossible ones in noise, and a reviewer who learns to dismiss the
 * flag is worse off than one who never had it.</p>
 */
class ParPlausibilityTest {

    private static BigDecimal m(double metres) {
        return BigDecimal.valueOf(metres);
    }

    // ─── The holes that started this ───────────────────────────────────────

    @Test
    void aParFiveOfThreeHundredMetresIsImpossible() {
        // Long Thành hole 13, exactly as it ships today.
        assertThat(ParPlausibility.isPlausible(5, m(326))).isFalse();
        assertThat(ParPlausibility.suggestionFor(5, m(326))).contains(4);
    }

    @Test
    void aParFourOfNearlyFiveHundredMetresIsImpossible() {
        // Long Thành hole 17.
        assertThat(ParPlausibility.isPlausible(4, m(476))).isFalse();
        assertThat(ParPlausibility.suggestionFor(4, m(476))).contains(5);
    }

    @Test
    void aParThreeTheLengthOfAParFourIsImpossible() {
        assertThat(ParPlausibility.isPlausible(3, m(380))).isFalse();
        assertThat(ParPlausibility.suggestionFor(3, m(380))).contains(4);
    }

    // ─── What must not be flagged ──────────────────────────────────────────

    @Test
    void ordinaryHolesPass() {
        assertThat(ParPlausibility.isPlausible(3, m(178))).isTrue();
        assertThat(ParPlausibility.isPlausible(4, m(361))).isTrue();
        assertThat(ParPlausibility.isPlausible(5, m(439))).isTrue();
    }

    @Test
    void anUnusuallyLongParThreeIsSurprisingRatherThanWrong() {
        // 250 m par 3s exist on championship courses. Flagging them would
        // teach a reviewer to ignore the flag.
        assertThat(ParPlausibility.isPlausible(3, m(250))).isTrue();
    }

    @Test
    void aShortDriveableParFourPasses() {
        assertThat(ParPlausibility.isPlausible(4, m(250))).isTrue();
    }

    @Test
    void aHoleAtTheBandEdgeIsNotFlagged() {
        assertThat(ParPlausibility.isPlausible(4, m(470))).isTrue();
        assertThat(ParPlausibility.isPlausible(5, m(380))).isTrue();
    }

    // ─── Missing data is not a contradiction ───────────────────────────────

    @Test
    void aHoleWithNoLengthCannotContradictItsPar() {
        assertThat(ParPlausibility.isPlausible(4, null)).isTrue();
        assertThat(ParPlausibility.suggestionFor(4, null)).isEmpty();
    }

    @Test
    void aHoleWithNoParIsNotJudged() {
        assertThat(ParPlausibility.isPlausible(null, m(326))).isTrue();
    }

    @Test
    void aZeroLengthIsAbsentRatherThanShort() {
        // The seed wrote 0 in places. Zero is "we do not know", and calling
        // every such hole's par wrong would flag hundreds of holes over a
        // missing field.
        assertThat(ParPlausibility.isPlausible(5, m(0))).isTrue();
        assertThat(ParPlausibility.suggestFor(m(0))).isEmpty();
    }

    // ─── A par that is not a par ───────────────────────────────────────────

    @Test
    void aParOutsideThreeToSixIsWrongWhateverTheLength() {
        assertThat(ParPlausibility.isPlausible(0, m(361))).isFalse();
        assertThat(ParPlausibility.isPlausible(9, m(361))).isFalse();
    }

    // ─── Suggestions ───────────────────────────────────────────────────────

    @Test
    void noSuggestionIsOfferedForAHoleThatIsAlreadyConsistent() {
        // A reviewer holding the scorecard does not need a second opinion on a
        // hole that agrees with itself.
        assertThat(ParPlausibility.suggestionFor(4, m(361))).isEmpty();
    }

    @Test
    void theSuggestionFollowsTheLength() {
        assertThat(ParPlausibility.suggestFor(m(150))).contains(3);
        assertThat(ParPlausibility.suggestFor(m(350))).contains(4);
        assertThat(ParPlausibility.suggestFor(m(480))).contains(5);
        assertThat(ParPlausibility.suggestFor(m(600))).contains(6);
    }
}
