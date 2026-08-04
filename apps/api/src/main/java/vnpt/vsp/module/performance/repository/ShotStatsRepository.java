package vnpt.vsp.module.performance.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.shot.entity.Shot;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Repository for shot-based performance statistics queries.
 * Per Story 11.1 Slice 1: aggregates shots by clubId + golferAccountId.
 *
 * <p>All distance values are returned in meters (canonical unit).
 * Shot location data (start/end) is stored as GeoJSON Point strings (SRID 4326).
 */
@Repository
public interface ShotStatsRepository extends JpaRepository<Shot, UUID> {

    // ─── Basic Shot Count ────────────────────────────────────────────────────

    /**
     * Count non-deleted shots for a specific club by a specific golfer.
     */
    @Query(value = """
        SELECT COUNT(s)
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        """, nativeQuery = true)
    long countShotsByClubAndGolfer(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    /**
     * Count non-deleted shots for all clubs in a bag by a specific golfer.
     */
    @Query(value = """
        SELECT COUNT(s)
        FROM shots s
        JOIN clubs c ON s.club_id = c.id
        WHERE c.golf_bag_id = :golfBagId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        """, nativeQuery = true)
    long countShotsByBagAndGolfer(
            @Param("golfBagId") Long golfBagId,
            @Param("golferAccountId") Long golferAccountId);

    // ─── Carry Distance Aggregates ───────────────────────────────────────────

    /**
     * Compute carry distance aggregates for a club.
     * Returns: [avg, min, max, stdDev] or empty if no shots.
     */
    @Query(value = """
        SELECT
            COALESCE(AVG(s.distance_meters), 0) as avg_val,
            COALESCE(MIN(s.distance_meters), 0) as min_val,
            COALESCE(MAX(s.distance_meters), 0) as max_val,
            COALESCE(STDDEV(s.distance_meters), 0) as stddev_val
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        """, nativeQuery = true)
    Object[] computeCarryAggregates(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    // ─── Total Distance Aggregates ──────────────────────────────────────────

    /**
     * Compute total distance aggregates for a club.
     * Note: total distance may be derived differently per club type.
     * Returns: [avg, min, max, stdDev] or empty if no shots.
     */
    @Query(value = """
        SELECT
            COALESCE(AVG(s.distance_meters), 0) as avg_val,
            COALESCE(MIN(s.distance_meters), 0) as min_val,
            COALESCE(MAX(s.distance_meters), 0) as max_val,
            COALESCE(STDDEV(s.distance_meters), 0) as stddev_val
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        """, nativeQuery = true)
    Object[] computeTotalAggregates(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    // ─── Shot List for Median and Directional Deviation ─────────────────────

    /**
     * Get sorted carry distances for median calculation and directional deviation.
     */
    @Query(value = """
        SELECT s.distance_meters
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        ORDER BY s.distance_meters ASC
        """, nativeQuery = true)
    List<BigDecimal> getSortedCarryDistances(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    /**
     * Get sorted total distances for median calculation.
     */
    @Query(value = """
        SELECT s.distance_meters
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        ORDER BY s.distance_meters ASC
        """, nativeQuery = true)
    List<BigDecimal> getSortedTotalDistances(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    // ─── Most Recent Shot Timestamp ─────────────────────────────────────────

    /**
     * Get the most recent shot timestamp for staleness checking.
     */
    @Query(value = """
        SELECT MAX(s.ended_at)
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
        """, nativeQuery = true)
    java.time.Instant getMostRecentShotAt(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);

    // ─── All Shots for Directional Deviation Calculation ─────────────────────

    /**
     * Get all shot data needed for directional deviation calculation.
     * Returns: [distance_meters, start_location (GeoJSON), end_location (GeoJSON)]
     */
    @Query(value = """
        SELECT s.distance_meters, s.start_location, s.end_location
        FROM shots s
        WHERE s.club_id = :clubId
          AND s.player_id = :golferAccountId
          AND s.deleted_at IS NULL
          AND s.distance_meters IS NOT NULL
        """, nativeQuery = true)
    List<Object[]> getShotsForDeviation(
            @Param("clubId") Long clubId,
            @Param("golferAccountId") Long golferAccountId);
}
