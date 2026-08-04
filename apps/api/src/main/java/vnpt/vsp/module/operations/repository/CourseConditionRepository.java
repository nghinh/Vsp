package vnpt.vsp.module.operations.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.operations.entity.CourseCondition;

import java.time.Instant;
import java.util.List;

/**
 * Repository for CourseCondition entities in the operations module.
 * Provides temporal queries for active course conditions per Story 8.5 AC-2.
 *
 * <p>Active course conditions are queried as:
 * effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf)</p>
 */
@Repository("operationsCourseConditionRepository")
public interface CourseConditionRepository extends JpaRepository<CourseCondition, Long> {

    /**
     * Find all course conditions for a course.
     */
    List<CourseCondition> findByCourseId(Long courseId);

    /**
     * Find active course conditions for a course as of a given instant.
     * Active = effectiveFrom <= asOf AND (expiresAt IS NULL OR expiresAt > asOf).
     */
    @Query("SELECT c FROM OperationsCourseCondition c WHERE c.course.id = :courseId " +
           "AND c.effectiveFrom <= :asOf AND (c.expiresAt IS NULL OR c.expiresAt > :asOf)")
    List<CourseCondition> findActiveByCourseId(@Param("courseId") Long courseId, @Param("asOf") Instant asOf);
}
