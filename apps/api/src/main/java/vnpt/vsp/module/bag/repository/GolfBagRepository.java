package vnpt.vsp.module.bag.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.bag.entity.GolfBag;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link GolfBag} entities.
 */
@Repository
public interface GolfBagRepository extends JpaRepository<GolfBag, Long> {

    /**
     * Find all bags belonging to a golfer account.
     */
    List<GolfBag> findByGolferAccountId(Long golferAccountId);

    /**
     * Find the currently active bag for a golfer.
     * Per Story 2.4 AC-2: exactly one bag is active at a time.
     */
    Optional<GolfBag> findByGolferAccountIdAndIsActiveTrue(Long golferAccountId);

    /**
     * Find a specific bag by ID and golfer account.
     * Used to verify ownership before mutations.
     */
    Optional<GolfBag> findByIdAndGolferAccountId(Long id, Long golferAccountId);

    /**
     * Count total bags for a golfer.
     * Used to prevent deleting the last bag.
     */
    long countByGolferAccountId(Long golferAccountId);

    /**
     * Deactivate all bags for a golfer.
     * Used by setActiveBag() before activating the target bag.
     */
    @Modifying
    @Query("UPDATE GolfBag b SET b.isActive = false WHERE b.golferAccountId = :accountId AND b.isActive = true")
    int deactivateAllForAccount(@Param("accountId") Long golferAccountId);
}
