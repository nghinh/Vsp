package vnpt.vsp.module.ai.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * One hole, as this golfer should see it before they play it.
 *
 * <p>The facts and the sentence are separate on purpose. The facts come from
 * rows and are always there; {@code advice} is null when the deployment has no
 * model configured, and the screen is expected to draw the hole anyway. A
 * client that treats a missing sentence as a failed request would hide a
 * golfer's own scoring record from them over a server-side setting.
 */
public record HoleAdviceResponse(

        int par,

        /// Null where the club published no index row — most of the country.
        Integer strokeIndex,

        /// The tee's own yardage, and the hole's measured length in metres.
        /// Both, because the card and the coordinates are different evidence
        /// and a golfer's unit preference decides which is shown.
        Integer yards,
        BigDecimal meters,
        String tee,

        /// How often this golfer has played this hole, and how it went.
        int roundsPlayed,
        BigDecimal averageStrokes,
        Integer bestStrokes,
        Integer fairwaysHit,
        Integer greensInRegulation,

        /// How many shots this golfer receives on this hole, from their
        /// handicap and the hole's stroke index. Null when either is unknown.
        ///
        /// Computed, not asked of a model: it is arithmetic the Rules define
        /// exactly, and a model that got it wrong would be wrong in a way that
        /// changes a net score.
        Integer strokesReceived,
        BigDecimal handicapUsed,

        /// Net par — what this golfer is really playing the hole in.
        Integer netPar,

        /// Which club to hit, for each shot the hole asks for, from the carry
        /// distances in this golfer's own bag. Empty when the bag has none.
        List<ClubForShot> clubs,

        /// True when every club distance behind {@code clubs} is still the
        /// seeded standard rather than something this golfer measured.
        ///
        /// The screen says so. A seeded 128 m is indistinguishable from a
        /// measured one once written, and advice built on it is advice for
        /// somebody else's swing — worth acting on, worth knowing about.
        boolean clubsAreStandard,

        /// Null when no model is configured. Never a placeholder sentence.
        String advice,

        /// True when the sentence came from the cache rather than the model.
        /// Surfaced so a "làm mới" control can exist without guessing.
        boolean cached) {

    /**
     * One shot of the hole, and the club that covers it.
     *
     * <p>{@code remainingMeters} is what is left standing at the ball, so the
     * first entry of a par 4 is the tee shot and the second is the approach.
     * A club is named only when the golfer's bag says how far it carries —
     * there is no table of averages here, because a 7-iron is not a distance.
     */
    public record ClubForShot(
            int shot,
            String label,
            int remainingMeters,
            String club,
            Integer carryMeters) {}
}
