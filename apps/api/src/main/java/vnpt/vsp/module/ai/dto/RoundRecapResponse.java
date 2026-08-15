package vnpt.vsp.module.ai.dto;

import java.time.LocalDate;

/**
 * One round, told as the message a golfer pastes into the flight's Zalo.
 *
 * <p>The facts and the sentence are separate, as everywhere else in this
 * module: the counts come from this golfer's own score rows and are always
 * present; {@code recap} is null when no model is configured, and the app is
 * expected to share the numbers anyway.
 */
public record RoundRecapResponse(

        String courseName,
        LocalDate playedOn,

        int holes,
        int totalStrokes,
        int totalPar,

        /// The card, sorted into the piles golfers actually talk in.
        int eagleOrBetter,
        int birdies,
        int pars,
        int bogeys,
        int doubleOrWorse,

        int penalties,
        int fairwaysHit,
        int greensInRegulation,

        /// The best hole against par, because that is the one retold at
        /// dinner. Ties break to the earlier hole.
        Integer bestHoleNumber,
        Integer bestHoleStrokes,
        Integer bestHolePar,

        /// How many rounds this golfer has on record, and whether this one is
        /// their best against par — the fact worth a sentence when true.
        int roundsOnRecord,
        boolean isBestRound,

        /// Null when no model is configured. Never a placeholder sentence.
        String recap,

        /// True when the sentence came from the cache rather than the model.
        boolean cached) {}
