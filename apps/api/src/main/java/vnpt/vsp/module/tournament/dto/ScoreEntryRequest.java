package vnpt.vsp.module.tournament.dto;

import java.util.UUID;

/**
 * One player's card, as typed — a partial update.
 *
 * A class with setters rather than a record, and that is the whole point.
 * Jackson calls a setter only for a key that is actually present in the JSON,
 * so this can tell "the client did not mention birdies" from "the client says
 * there are no birdies". A record cannot: both arrive as null.
 *
 * That distinction is not academic. Two screens write scores and they write
 * different fields — the fast list writes a total plus birdie and eagle counts,
 * the hole-by-hole grid writes eighteen holes plus a total. Applying every
 * field unconditionally meant each one erased what the other had entered: type
 * three birdies in the fast list, open the grid, correct a hole, save, and the
 * birdies are gone. Silently, and only visible later when the prize for most
 * birdies is worked out.
 *
 * So: absent means leave alone, and an explicit null means clear.
 */
public class ScoreEntryRequest {

    private UUID tournamentPlayerId;

    private Integer grossTotal;
    private boolean grossTotalSet;

    private Integer[] holeScores;
    private boolean holeScoresSet;

    private Integer birdieCount;
    private boolean birdieCountSet;

    private Integer eagleCount;
    private boolean eagleCountSet;

    public UUID getTournamentPlayerId() { return tournamentPlayerId; }
    public void setTournamentPlayerId(UUID tournamentPlayerId) {
        this.tournamentPlayerId = tournamentPlayerId;
    }

    /**
     * The round's gross, when only a total was entered.
     *
     * The hole scores win where both are present: eighteen numbers are the
     * scorecard and this is the shortcut that gets a leaderboard up first.
     */
    public Integer getGrossTotal() { return grossTotal; }
    public void setGrossTotal(Integer grossTotal) {
        this.grossTotal = grossTotal;
        this.grossTotalSet = true;
    }
    public boolean hasGrossTotal() { return grossTotalSet; }

    /** Strokes per hole in play order; 0 or null means not entered. */
    public Integer[] getHoleScores() { return holeScores; }
    public void setHoleScores(Integer[] holeScores) {
        this.holeScores = holeScores;
        this.holeScoresSet = true;
    }
    public boolean hasHoleScores() { return holeScoresSet; }

    /**
     * Birdies as the flight reported them.
     *
     * Only consulted when the hole scores are absent — with eighteen numbers
     * they are counted. Without them there is nothing to count from, and
     * "Golfer đạt điểm birdies sẽ có phần thưởng" still has to be answerable.
     */
    public Integer getBirdieCount() { return birdieCount; }
    public void setBirdieCount(Integer birdieCount) {
        this.birdieCount = birdieCount;
        this.birdieCountSet = true;
    }
    public boolean hasBirdieCount() { return birdieCountSet; }

    public Integer getEagleCount() { return eagleCount; }
    public void setEagleCount(Integer eagleCount) {
        this.eagleCount = eagleCount;
        this.eagleCountSet = true;
    }
    public boolean hasEagleCount() { return eagleCountSet; }
}
