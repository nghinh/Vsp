package vnpt.vsp.module.ai.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * The whole card, as this golfer should play it — the page a caddie would
 * pencil before the round rather than the sentence they say on each tee.
 *
 * <p>Facts only, no model call. Eighteen holes of the same arithmetic the
 * per-hole advice runs — shots received, net par, which club covers what —
 * is a page a golfer reads in the cart and shares to the flight's Zalo, and
 * paying for eighteen model sentences to build it would price it out of
 * being opened.
 */
public record CourseStrategyResponse(

        String courseName,

        /// Present when the round is two nines from different courses; the
        /// holes list then runs 1–18 with the back nine's holes renumbered.
        String backNineCourseName,

        /// The handicap the allocation ran off — the profile's where one
        /// exists, the one computed from their own rounds otherwise. Null
        /// when neither exists, and every strokesReceived below is too.
        BigDecimal handicapUsed,

        /// True while every carry behind the club picks is still the seeded
        /// standard rather than something this golfer measured.
        boolean clubsAreStandard,

        /// Net strokes the golfer receives across the card, and what that
        /// makes their personal par. Null when the allocation could not run.
        Integer strokesReceivedTotal,
        Integer netParTotal,

        List<StrategyHole> holes) {

    /** One row of the page. */
    public record StrategyHole(
            /// 1–18 as the golfer plays them, even when the back nine's card
            /// numbers its holes 1–9.
            int displayHole,
            int par,
            Integer strokeIndex,
            Integer yards,
            BigDecimal meters,
            Integer strokesReceived,
            Integer netPar,
            int roundsPlayed,
            BigDecimal averageStrokes,
            Integer bestStrokes,
            List<HoleAdviceResponse.ClubForShot> clubs) {}
}
