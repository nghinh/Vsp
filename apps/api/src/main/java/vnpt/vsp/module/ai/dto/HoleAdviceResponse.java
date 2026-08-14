package vnpt.vsp.module.ai.dto;

import java.math.BigDecimal;

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

        /// Null when no model is configured. Never a placeholder sentence.
        String advice,

        /// True when the sentence came from the cache rather than the model.
        /// Surfaced so a "làm mới" control can exist without guessing.
        boolean cached) {}
