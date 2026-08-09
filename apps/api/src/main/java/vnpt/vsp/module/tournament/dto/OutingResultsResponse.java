package vnpt.vsp.module.tournament.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * The prize table, ready to read out.
 *
 * Everything the club house screen shows in one response, because it is one
 * screen and it is refreshed while people are waiting: the divisions in order,
 * the technical prizes, and an honest count of who is still out.
 */
public record OutingResultsResponse(
        UUID tournamentId,
        Instant computedAt,
        /** Null until published — a result nobody has frozen is not quotable. */
        Instant publishedAt,
        int rosterSize,
        int scoresEntered,
        /** Ranked entries per division code, in the rules' division order. */
        Map<String, List<Entry>> divisions,
        List<TechnicalAwardResponse> technicalAwards,
        /**
         * Players the rules could not place in any division, by name.
         *
         * A handicap outside every configured band is silent otherwise: the
         * player simply never appears on the board, and nobody notices until
         * they ask why they were not called up.
         */
        List<String> unplaced) {

    /** One player's line on the board. */
    public record Entry(
            UUID tournamentPlayerId,
            String displayName,
            String vgaCode,
            Integer flightNumber,
            int playingHandicap,
            Integer gross,
            Integer net,
            Integer judgingScore,
            int rank,
            String prizeTitle,
            boolean countbackAvailable,
            boolean tiedAndUnresolved,
            Integer dailyCapAdjustment,
            int birdies,
            int eagles) {}

    /** A technical prize and who took it. */
    public record TechnicalAwardResponse(
            String prizeCode,
            String prizeLabel,
            int holeNumber,
            UUID tournamentPlayerId,
            String displayName,
            double measurement,
            String unit) {}
}
