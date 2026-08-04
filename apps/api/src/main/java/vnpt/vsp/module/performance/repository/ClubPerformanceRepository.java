package vnpt.vsp.module.performance.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.performance.entity.ClubPerformance;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link ClubPerformance} cached stats.
 * Per Story 11.1 Slice 1: invalidate on new shot sync.
 */
@Repository
public interface ClubPerformanceRepository extends JpaRepository<ClubPerformance, Long> {

    /**
     * Find cached stats for a specific club.
     */
    Optional<ClubPerformance> findByClubId(Long clubId);

    /**
     * Find cached stats for a club belonging to a specific golfer.
     */
    Optional<ClubPerformance> findByClubIdAndGolferAccountId(Long clubId, Long golferAccountId);

    /**
     * Find all cached stats for clubs in a specific bag.
     */
    List<ClubPerformance> findByGolfBagId(Long golfBagId);

    /**
     * Find all cached stats for clubs in a bag belonging to a specific golfer.
     */
    List<ClubPerformance> findByGolfBagIdAndGolferAccountId(Long golfBagId, Long golferAccountId);

    /**
     * Delete cached stats for a specific club.
     */
    @Modifying
    @Query("DELETE FROM ClubPerformance cp WHERE cp.clubId = :clubId")
    void deleteByClubId(@Param("clubId") Long clubId);

    /**
     * Delete all cached stats for clubs in a specific bag.
     */
    @Modifying
    @Query("DELETE FROM ClubPerformance cp WHERE cp.golfBagId = :golfBagId")
    void deleteByGolfBagId(@Param("golfBagId") Long golfBagId);

    /**
     * Delete all cached stats for all bags belonging to a specific golfer.
     */
    @Modifying
    @Query("DELETE FROM ClubPerformance cp WHERE cp.golferAccountId = :golferAccountId")
    void deleteByGolferAccountId(@Param("golferAccountId") Long golferAccountId);

    /**
     * Invalidate (delete) cached stats for a club if the shot is newer than the last computation.
     * Used by shot-sync invalidation logic.
     */
    @Modifying
    @Query("DELETE FROM ClubPerformance cp WHERE cp.clubId = :clubId AND (cp.basedOnShotAt IS NULL OR cp.basedOnShotAt < :shotAt)")
    int invalidateIfStale(@Param("clubId") Long clubId, @Param("shotAt") Instant shotAt);
}
