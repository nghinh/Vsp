package vnpt.vsp.module.course.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.course.entity.CourseCondition;

import java.time.LocalDate;
import java.util.List;

@Repository("courseDataConditionRepository")
public interface CourseConditionRepository extends JpaRepository<CourseCondition, Long> {
    List<CourseCondition> findByCourseId(Long courseId);

    List<CourseCondition> findByCourseIdAndEffectiveDateLessThanEqualAndExpiryDateIsNull(Long courseId, LocalDate date);

    /**
     * Returns active conditions for a course: effectiveDate <= today AND (expiryDate IS NULL OR expiryDate >= today).
     * Per Story 3.3 CD-BACK-1: AC-1 conditions section.
     */
    @Query("SELECT cc FROM CourseDataCondition cc WHERE cc.course.id = :courseId " +
           "AND cc.effectiveDate <= :today AND (cc.expiryDate IS NULL OR cc.expiryDate >= :today) " +
           "ORDER BY cc.effectiveDate DESC")
    List<CourseCondition> findActiveByCourseId(@Param("courseId") Long courseId, @Param("today") LocalDate today);
}
