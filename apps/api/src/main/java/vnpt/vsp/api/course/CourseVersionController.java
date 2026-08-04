package vnpt.vsp.api.course;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.course.CourseVersionService;
import vnpt.vsp.module.course.dto.*;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.UUID;

/**
 * REST controller for course version operations.
 * Per Story 8.4 AC-1, AC-2, AC-3: version listing, impact preview, and rollback.
 *
 * Endpoints:
 * - GET  /courses/{courseId}/versions                        — list all versions (paginated)
 * - GET  /courses/{courseId}/versions/{versionId}           — get version detail
 * - GET  /courses/{courseId}/versions/rollback-impact      — preview rollback impact
 * - POST /courses/{courseId}/versions/{versionId}/rollback — execute rollback
 *
 * All endpoints require COURSE_ADMIN or SUPER_ADMIN role.
 */
@RestController
@RequestMapping("/courses/{courseId}/versions")
public class CourseVersionController {

    private static final Logger log = LoggerFactory.getLogger(CourseVersionController.class);

    private final CourseVersionService courseVersionService;
    private final RoleService roleService;

    public CourseVersionController(CourseVersionService courseVersionService, RoleService roleService) {
        this.courseVersionService = courseVersionService;
        this.roleService = roleService;
    }

    /**
     * List all versions for a course (newest first).
     *
     * @param courseId course ID
     * @param page zero-based page number (default 0)
     * @param size page size (default 20)
     * @return paginated list of versions
     */
    @GetMapping
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<PageResponse<CourseVersionDto>> listVersions(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /courses/{}/versions - accountId={}, page={}, size={}", courseId, accountId, page, size);

        PageResponse<CourseVersionDto> versions = courseVersionService.listVersions(courseId, page, size);
        return ResponseEntity.ok(versions);
    }

    /**
     * Get a single version with full metadata.
     *
     * @param courseId course ID
     * @param versionId version ID
     * @return version detail
     */
    @GetMapping("/{versionId}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CourseVersionDto> getVersion(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long versionId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /courses/{}/versions/{} - accountId={}", courseId, versionId, accountId);

        CourseVersionDto version = courseVersionService.getVersion(courseId, versionId);
        return ResponseEntity.ok(version);
    }

    /**
     * Preview what would change if a rollback were executed to the target version.
     *
     * @param courseId course ID
     * @param targetVersionId the candidate rollback target
     * @return impact summary showing current vs target version
     */
    @GetMapping("/rollback-impact")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<RollbackImpactDto> getRollbackImpact(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam("targetVersionId") Long targetVersionId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /courses/{}/versions/rollback-impact?targetVersionId={} - accountId={}",
                courseId, targetVersionId, accountId);

        RollbackImpactDto impact = courseVersionService.getRollbackImpact(courseId, targetVersionId);
        return ResponseEntity.ok(impact);
    }

    /**
     * Execute a rollback — re-activates an archived version as the current published version.
     *
     * <p>Per Story 8.4 AC-2: rollback creates a new published version rather than deleting history.
     * Per Story 8.4 AC-3: new package generation and audit record are triggered.
     *
     * @param courseId course ID
     * @param versionId the archived version to roll back to
     * @param request rollback request containing the required rollbackNote
     * @return rollback response with new job ID and version info
     */
    @PostMapping("/{versionId}/rollback")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<RollbackResponse> executeRollback(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long versionId,
            @Valid @RequestBody RollbackRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        String actor = authentication.getName();
        requireAdminRole(accountId);

        log.info("POST /courses/{}/versions/{}/rollback - accountId={}, actor={}, reason={}",
                courseId, versionId, accountId, actor, request.rollbackNote());

        DataVersion result = courseVersionService.rollbackToVersion(
                courseId, versionId, actor, request.rollbackNote());

        UUID newJobId = courseVersionService.triggerPackageBuild(courseId, result.getId(), actor);

        return ResponseEntity.ok(RollbackResponse.fromDataVersion(result, newJobId));
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }
}
