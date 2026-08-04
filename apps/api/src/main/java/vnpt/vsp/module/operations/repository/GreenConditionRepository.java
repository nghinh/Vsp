package vnpt.vsp.module.operations.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.operations.entity.GreenCondition;

import java.time.Instant;
import java.util.List;

/**
 * Repository for GreenCondition entities in the operations module.
 * Provides temporal queries for active green conditions per Story 8.5 AC-2.
 *
 * <p>Active green conditions are queried as:
 * effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf)</p>
 */
@Repository
public interface GreenConditionRepository extends JpaRepository<GreenCondition, Long> {

    /**
     * Find all green conditions for a hole.
     */
    List<GreenCondition> findByHoleId(Long holeId);

    /**
     * Find active green conditions for a hole as of a given instant.
     * Active = effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf).
     */
    @Query("SELECT g FROM GreenCondition g WHERE g.hole.id = :holeId " +
           "AND g.effectiveFrom <= :asOf AND (g.expiresAt IS NULL OR g.expiresAt > :asOf)")
    List<GreenCondition> findActiveByHoleId(@Param("holeId") Long holeId, @Param("asOf") Instant asOf);

    /**
     * Find all active green conditions for a course (all holes) as of a given instant.
     */
    @Query("SELECT g FROM GreenCondition g WHERE g.hole.course.id = :courseId " +
           "AND g.effectiveFrom <= :asOf AND (g.expiresAt IS NULL OR g.expiresAt > :asOf)")
    List<GreenCondition> findActiveByCourseId(@Param("courseId") Long courseId, @Param("asOf") Instant asOf);
}
