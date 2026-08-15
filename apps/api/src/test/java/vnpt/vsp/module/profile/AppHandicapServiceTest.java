package vnpt.vsp.module.profile;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The society handicap's arithmetic.
 *
 * <p>This number decides how many strokes a golfer receives, so a wrong answer
 * changes who pays in a game and what net par means on every hole. The rules
 * are few and each is asserted: best-8, the nine-hole scaling, the floor at
 * zero, and the refusal to answer at all on too little data.
 */
class AppHandicapServiceTest {

    @Test
    void averagesTheBestEightOfTheWindow() {
        // Twenty rounds: eight at +10, twelve at +30. Best 8 → 10.0.
        var diffs = new java.util.ArrayList<Double>();
        for (int i = 0; i < 8; i++) diffs.add(10.0);
        for (int i = 0; i < 12; i++) diffs.add(30.0);

        assertThat(AppHandicapService.fromDifferentials(diffs))
                .isEqualByComparingTo("10.0");
    }

    @Test
    void usesWhatThereIsWhenFewerThanEight() {
        assertThat(AppHandicapService.fromDifferentials(List.of(12.0, 18.0, 24.0)))
                .isEqualByComparingTo("18.0");
    }

    /// Two rounds is an anecdote. The features that consume this treat null as
    /// "not known", which is the honest state.
    @Test
    void refusesToAnswerOnTooFewRounds() {
        assertThat(AppHandicapService.fromDifferentials(List.of(10.0, 12.0)))
                .isNull();
        assertThat(AppHandicapService.fromDifferentials(List.of())).isNull();
    }

    /// "Plus" claims better than scratch, and casual rounds cannot support
    /// that claim — the floor is zero.
    @Test
    void neverGoesPlus() {
        assertThat(AppHandicapService.fromDifferentials(List.of(-4.0, -2.0, -6.0)))
                .isEqualByComparingTo("0.0");
    }

    @Test
    void roundsToOneDecimal() {
        assertThat(AppHandicapService.fromDifferentials(List.of(10.0, 11.0, 12.0)))
                .isEqualByComparingTo("11.0");
        assertThat(AppHandicapService.fromDifferentials(List.of(10.0, 10.0, 11.0)))
                .isEqualByComparingTo("10.3");
    }
}
