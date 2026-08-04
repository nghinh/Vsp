package vnpt.vsp.module.operations.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.operations.entity.PinPosition;

import java.time.Instant;
import java.util.List;

/**
 * Repository for PinPosition entities in the operations module.
 * Provides temporal queries for active pin positions per Story 8.5 AC-1.
 *
 * <p>Active pin positions are queried as:
 * effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf)
 * Per stale pin handling in slice plan constraints.</p>
 */
@Repository("operationsPinPositionRepository")
public interface PinPositionRepository extends JpaRepository<PinPosition, Long> {

    /**
     * Find all pin positions for a hole.
     */
    List<PinPosition> findByHoleId(Long holeId);

    /**
     * Find active pin positions for a hole as of a given instant.
     * Active = effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf).
     */
    @Query("SELECT p FROM OperationsPinPosition p WHERE p.hole.id = :holeId " +
           "AND p.effectiveFrom <= :asOf AND (p.expiresAt IS NULL OR p.expiresAt > :asOf)")
    List<PinPosition> findActiveByHoleId(@Param("holeId") Long holeId, @Param("asOf") Instant asOf);

    /**
     * Find all active pin positions for a course (all holes) as of a given instant.
     */
    @Query("SELECT p FROM OperationsPinPosition p WHERE p.hole.course.id = :courseId " +
           "AND p.effectiveFrom <= :asOf AND (p.expiresAt IS NULL OR p.expiresAt > :asOf)")
    List<PinPosition> findActiveByCourseId(@Param("courseId") Long courseId, @Param("asOf") Instant asOf);
}
