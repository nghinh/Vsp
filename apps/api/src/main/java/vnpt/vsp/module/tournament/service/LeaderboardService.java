package vnpt.vsp.module.tournament.service;

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
     * Subscribes to leaderboard updates for a tournament (SSE connection).
     *
     * @param tournamentId the tournament UUID
     */
    void subscribe(UUID tournamentId);

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
