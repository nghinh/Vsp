package vnpt.vsp.module.score.dto;

import java.util.List;
import java.util.UUID;

/**
 * Request DTO for batch score sync endpoint.
 *
 * Per Story 5.4: client sends local score events queued in SQLite.
 *
 * @param roundId      the round these scores belong to
 * @param flightId      the flight within the round
 * @param scores        list of per-hole score updates
 * @param clientEventId client-side UUID for this sync batch (matches {@code Idempotency-Key})
 */
public record ScoreSyncRequest(
        UUID roundId,
        UUID flightId,
        List<ScoreUpdate> scores,
        UUID clientEventId
) {

    /**
     * A single per-hole score update from the local queue.
     *
     * @param scoreId      local score UUID
     * @param holeIndex    1-based hole index
     * @param playerId     golfer account ID
     * @param grossScore   strokes taken (null if not yet entered)
     * @param putts        putt count
     * @param penalties    penalty strokes
     * @param fairwayHit   fairway hit (par-4/5)
     * @param gir          green in regulation
     * @param bunker       bunker shot
     * @param notes        free-text notes
     * @param version      optimistic concurrency version
     */
    public record ScoreUpdate(
            UUID scoreId,
            int holeIndex,
            Long playerId,
            Integer grossScore,
            Integer putts,
            Integer penalties,
            Boolean fairwayHit,
            Boolean gir,
            Boolean bunker,
            String notes,
            int version
    ) {}
}
