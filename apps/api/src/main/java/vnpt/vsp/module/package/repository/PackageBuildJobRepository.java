package vnpt.vsp.module.pkg.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.pkg.entity.PackageBuildJob;
import vnpt.vsp.module.pkg.entity.PackageBuildStatus;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for PackageBuildJob entities.
 *
 * Provides queries for:
 * - Idempotency: find existing non-terminal job for same course (prevents duplicates)
 * - Worker polling: find oldest QUEUED job to process
 * - Portal: list job history for a course, poll job status by ID
 *
 * Per Story 4.2 PKG-PUBLISH-1.
 */
@Repository
public interface PackageBuildJobRepository extends JpaRepository<PackageBuildJob, UUID> {

    /**
     * Find the most recent non-terminal job for a course.
     * Used by triggerPackageBuild() for idempotency — returns the existing
     * job ID without creating a duplicate if a build is already in progress.
     */
    Optional<PackageBuildJob> findFirstByCourseIdAndStatusIn(
        @Param("courseId") Long courseId,
        @Param("statuses") List<PackageBuildStatus> statuses
    );

    /**
     * Find the most recent non-terminal job for a course+version combination.
     * Used by queueBuildForCourse() for per-version idempotency — returns the
     * existing job without creating a duplicate if a build is already in
     * progress for the same course AND data version.
     */
    Optional<PackageBuildJob> findFirstByCourseIdAndDataVersionIdAndStatusIn(
        @Param("courseId") Long courseId,
        @Param("dataVersionId") Long dataVersionId,
        @Param("statuses") List<PackageBuildStatus> statuses
    );

    /**
     * Get full job history for a course, newest first.
     * Used by portal job history page.
     */
    List<PackageBuildJob> findByCourseIdOrderByCreatedAtDesc(Long courseId);

    /**
     * Find the oldest QUEUED (or otherwise in-progress) job.
     * Used by the async worker to claim the next job to process.
     */
    Optional<PackageBuildJob> findFirstByStatusInOrderByCreatedAtAsc(
        @Param("statuses") List<PackageBuildStatus> statuses
    );

    /**
     * Find a specific job by ID and course ID.
     * Used by portal polling to verify the job belongs to the requested course.
     */
    Optional<PackageBuildJob> findByIdAndCourseId(UUID id, Long courseId);

    /**
     * Count non-terminal jobs for a course.
     * Used as a quick existence check before claiming a job.
     */
    @Query("SELECT COUNT(j) FROM PackageBuildJob j " +
           "WHERE j.courseId = :courseId " +
           "AND j.status NOT IN (:terminalStatuses)")
    long countInProgressByCourseId(
        @Param("courseId") Long courseId,
        @Param("terminalStatuses") List<PackageBuildStatus> terminalStatuses
    );
}
