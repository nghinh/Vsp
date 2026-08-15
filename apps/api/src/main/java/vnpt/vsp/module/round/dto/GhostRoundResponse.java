package vnpt.vsp.module.round.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * The best round this golfer has completed on a course, hole by hole.
 *
 * <p>The app lays it beside the round being played and says who is ahead —
 * which needs every hole's strokes, not just the total, because the race is
 * read mid-round at whatever hole the golfer is standing on.
 */
public record GhostRoundResponse(
        UUID roundId,
        LocalDate playedOn,
        int totalStrokes,
        int totalPar,
        List<GhostHole> holes) {

    public record GhostHole(int holeNumber, int strokes, int par) {}
}
