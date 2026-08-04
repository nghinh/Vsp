package vnpt.vsp.module.correction.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.CorrectionStatus;

import java.util.List;

/**
 * JPA repository for {@link CourseCorrection} persistence and filtered queries.
 *
 * <p>Uses {@link JpaSpecificationExecutor} for the dynamic filter combinations
 * required by the queue list endpoint.</p>
 *
 * Per Story 9.2 AC-1 and Slice Plan §Slice A.
 */
@Repository
public interface CourseCorrectionRepository
        extends JpaRepository<CourseCorrection, Long>,
                JpaSpecificationExecutor<CourseCorrection> {

    /**
     * Find all corrections for a specific course (newest first).
     */
    List<CourseCorrection> findByCourseIdOrderBySubmittedAtDesc(Long courseId);

    /**
     * Find corrections by status (newest first).
     */
    List<CourseCorrection> findByStatusOrderBySubmittedAtDesc(CorrectionStatus status);

    /**
     * Count corrections by status for a given course.
     */
    long countByCourseIdAndStatus(Long courseId, CorrectionStatus status);
}
