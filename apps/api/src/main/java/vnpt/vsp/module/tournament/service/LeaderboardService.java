package vnpt.vsp.module.tournament.service;

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vnpt.vsp.module.tournament.dto.LeaderboardResponse;

import java.util.UUID;

/**
 * Service interface for live leaderboard.
 * Per Story 12.1 Slice E: maintains in-memory leaderboard state,
 * publishes score updates via Redis pub/sub, handles SSE streaming.
 */
public interface LeaderboardService {

    /**
     * Gets the current leaderboard state for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return the current leaderboard response
     */
    LeaderboardResponse getLeaderboard(UUID tournamentId);

    /**
     * Subscribes to leaderboard updates for a tournament and returns the live
     * {@link SseEmitter} to stream to the client. The emitter immediately receives
     * the current leaderboard snapshot and then a {@code leaderboard} event on every
     * recalculation until the client disconnects or the emitter times out.
     *
     * @param tournamentId the tournament UUID
     * @return an open SSE emitter registered for this tournament
     */
    SseEmitter subscribe(UUID tournamentId);

    /**
     * Publishes a score update and triggers leaderboard recalculation.
     * Called when a score is confirmed.
     *
     * @param tournamentId the tournament UUID
     * @param playerId the player ID
     * @param score the new score
     */
    void publishScoreUpdate(UUID tournamentId, Long playerId, int score);

    /**
     * Recalculates and broadcasts the leaderboard for a tournament.
     *
     * @param tournamentId the tournament UUID
     */
    void recalculateAndBroadcast(UUID tournamentId);
}
