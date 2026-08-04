package vnpt.vsp.module.performance;

import vnpt.vsp.module.performance.dto.BagPerformanceResponse;
import vnpt.vsp.module.performance.dto.ClubPerformanceResponse;

import java.util.List;
import java.util.UUID;

/**
 * Service interface for club performance statistics.
 * Per Story 11.1 Slice 1: AC-1, AC-2.
 */
@vnpt.vsp.module.performance.PerformanceModule
public interface PerformanceService {

    // ─── Per-Club Performance ────────────────────────────────────────────────

    /**
     * Get performance statistics for a specific club.
     * Returns cached stats if available and fresh, otherwise computes from shot data.
     *
     * @param golferAccountId authenticated golfer account ID
     * @param bagId            golf bag ID
     * @param clubId           club ID
     * @return club performance response (never null; returns empty stats for insufficient data)
     */
    ClubPerformanceResponse getClubPerformance(Long golferAccountId, Long bagId, Long clubId);

    // ─── Bag-Level Batch Performance ─────────────────────────────────────────

    /**
     * Get performance statistics for all clubs in a bag.
     * Per Story 11.1 Slice 1: batch endpoint.
     *
     * @param golferAccountId authenticated golfer account ID
     * @param bagId            golf bag ID
     * @return bag performance response with all club stats
     */
    BagPerformanceResponse getBagPerformance(Long golferAccountId, Long bagId);

    // ─── Cache Invalidation ──────────────────────────────────────────────────

    /**
     * Invalidate cached performance stats for a club when new shots are synced.
     * Called by shot sync logic after new shots are persisted.
     *
     * @param clubId           club ID
     * @param mostRecentShotAt timestamp of the most recent synced shot
     */
    void invalidateIfStale(Long clubId, UUID shotId, java.time.Instant mostRecentShotAt);
}
