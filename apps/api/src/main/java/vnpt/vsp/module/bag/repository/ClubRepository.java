package vnpt.vsp.module.bag.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.bag.entity.Club;

import java.util.List;
import java.util.Optional;

/**
 * Repository for {@link Club} entities.
 */
@Repository
public interface ClubRepository extends JpaRepository<Club, Long> {

    /**
     * Find all clubs belonging to a golf bag.
     */
    List<Club> findByGolfBagId(Long golfBagId);

    /**
     * Find a specific club by ID within a golf bag.
     * Used to verify ownership before mutations.
     */
    Optional<Club> findByIdAndGolfBagId(Long id, Long golfBagId);

    /**
     * Count clubs in a golf bag.
     * Per Story 2.4 AC-3: used to check minimum data threshold.
     */
    long countByGolfBagId(Long golfBagId);

    /**
     * Count clubs with non-null carryDistance in a golf bag.
     * Per Story 2.4 AC-3: minimum threshold = at least one club with carryDistance.
     */
    @Query("SELECT COUNT(c) FROM Club c WHERE c.golfBag.id = :bagId AND c.carryDistance IS NOT NULL")
    long countByGolfBagIdAndCarryDistanceIsNotNull(@Param("bagId") Long bagId);
}
