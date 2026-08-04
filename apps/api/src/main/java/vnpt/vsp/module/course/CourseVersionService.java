package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.CourseVersionDto;
import vnpt.vsp.module.course.dto.PageResponse;
import vnpt.vsp.module.course.dto.RollbackImpactDto;
import vnpt.vsp.module.course.entity.DataVersion;

import java.util.UUID;

/**
 * Service interface for course version operations.
 * Handles version listing, impact preview, and rollback.
 * Per Story 8.4 AC-1, AC-2, AC-3: rollback creates a new published version,
 * never deletes history, and triggers package rebuild.
 */
public interface CourseVersionService {

    /**
     * List all versions for a course (newest first).
     *
     * @param courseId the course
     * @param page zero-based page number
     * @param size page size
     * @return paginated list of version summaries
     */
    PageResponse<CourseVersionDto> listVersions(Long courseId, int page, int size);

    /**
     * Get a single version with full metadata.
     *
     * @param courseId the course
     * @param versionId the version
     * @return version detail DTO
     * @throws vnpt.vsp.api.error.VspApiException with DATA_VERSION_001 if not found or belongs to different course
     */
    CourseVersionDto getVersion(Long courseId, Long versionId);

    /**
     * Preview what would change if a rollback were executed to the target version.
     *
     * @param courseId the course
     * @param targetVersionId the candidate rollback target
     * @return impact summary showing current vs target version
     * @throws vnpt.vsp.api.error.VspApiException with DATA_VERSION_001 if version not found
     */
    RollbackImpactDto getRollbackImpact(Long courseId, Long targetVersionId);

    /**
     * Roll back a course to a prior archived version.
     *
     * <p>Workflow per Architecture §7.3 and PRD §8.11:
     * <ol>
     *   <li>Current PUBLISHED version → ARCHIVED</li>
     *   <li>Selected prior ARCHIVED version → re-PUBLISHED (publishedAt updated, publishedBy set to actor)</li>
     *   <li>Async package build triggered for the re-published version</li>
     *   <li>Audit entry written for COURSE_ROLLBACK</li>
     * </ol>
     *
     * @param courseId the course to roll back
     * @param targetVersionId the archived version to re-activate
     * @param actor the user performing the rollback
     * @param rollbackNote the reason for the rollback (required)
     * @return the re-published DataVersion
     * @throws vnpt.vsp.api.error.VspApiException with DATA_VERSION_001 if version not found
     * @throws vnpt.vsp.api.error.VspApiException with DATA_VERSION_002 if version is not ARCHIVED
     * @throws vnpt.vsp.api.error.VspApiException with DATA_VERSION_003 if no currently published version exists
     */
    DataVersion rollbackToVersion(Long courseId, Long targetVersionId, String actor, String rollbackNote);

    /**
     * Trigger an async package build for a course after a version change.
     *
     * @param courseId the course
     * @param dataVersionId the version to build against
     * @param triggeredBy the user who triggered the build
     * @return the build job ID
     */
    UUID triggerPackageBuild(Long courseId, Long dataVersionId, String triggeredBy);
}
