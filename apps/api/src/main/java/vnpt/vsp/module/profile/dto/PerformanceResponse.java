package vnpt.vsp.module.profile.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * A golfer's own record, as they would read it about themselves.
 *
 * <p>Every number here is counted from this golfer's score entries. Nothing
 * is modelled, averaged against other players, or estimated: where the rows
 * do not say, the field is null and the screen shows a dash. A statistic a
 * golfer cannot trace back to a round they remember playing is worse than an
 * empty tile.
 */
public record PerformanceResponse(

        /// How many completed rounds the window covers, and how many holes
        /// of scoring those rounds hold.
        int rounds,
        int holes,

        /// The app-computed handicap, where there are enough rounds for one.
        BigDecimal handicap,

        /// The best round in the window against par, and how many holes that
        /// round had — "+9" means something different over nine than over
        /// eighteen, so both travel together.
        Integer bestToPar,
        Integer bestToParHoles,

        /// Strokes over par per hole, across the window.
        BigDecimal strokesOverParPerHole,

        /// Putts per hole, over the holes where putts were actually recorded.
        /// Null when nobody recorded any — most golfers, most rounds.
        BigDecimal puttsPerHole,
        int holesWithPutts,

        /// Greens in regulation and fairways hit, as percentages of the holes
        /// where the golfer marked them either way.
        BigDecimal girPercent,
        int holesWithGir,
        BigDecimal fairwayPercent,
        int holesWithFairway,

        /// Penalty strokes per round.
        BigDecimal penaltiesPerRound,

        /// How the holes fell out: eagles through triple-bogey-or-worse.
        List<ScoreBucket> distribution,

        /// What each par costs this golfer.
        List<ParAverage> byPar) {

    /// One pile of holes — "birdie", and how many, and what share of the
    /// window that is.
    public record ScoreBucket(String label, int holes, BigDecimal percent) {}

    /// Average strokes on par 3s, 4s and 5s, with the best and worst seen.
    public record ParAverage(int par, int holes, BigDecimal average,
                             Integer best, Integer worst) {}
}
