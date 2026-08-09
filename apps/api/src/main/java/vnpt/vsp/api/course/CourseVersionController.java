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
import vnpt.vsp.module.course.PublishService;
import vnpt.vsp.module.course.ValidationService;
import vnpt.vsp.module.course.VersionDiffService;
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
 * - POST /courses/{courseId}/versions/{versionId}/validate — validate a draft
 * - GET  /courses/{courseId}/versions/{versionId}/diff     — diff against published
 * - POST /courses/{courseId}/versions/{versionId}/publish  — publish a draft
 *
 * All endpoints require COURSE_ADMIN or SUPER_ADMIN role.
 */
@RestController
@RequestMapping("/courses/{courseId}/versions")
public class CourseVersionController {

    private static final Logger log = LoggerFactory.getLogger(CourseVersionController.class);

    private final CourseVersionService courseVersionService;
    private final RoleService roleService;
    private final ValidationService validationService;
    private final VersionDiffService versionDiffService;
    private final PublishService publishService;

    public CourseVersionController(
            CourseVersionService courseVersionService,
            RoleService roleService,
            ValidationService validationService,
            VersionDiffService versionDiffService,
            PublishService publishService) {
        this.courseVersionService = courseVersionService;
        this.roleService = roleService;
        this.validationService = validationService;
        this.versionDiffService = versionDiffService;
        this.publishService = publishService;
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
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
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
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
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
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
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
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
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

    /**
     * Validate a draft version before publishing.
     *
     * Story 8.3 AC-1. {@link ValidationService} and its DTOs were written and
     * this endpoint was not, so the portal's publish page called
     * {@code POST /admin/courses/{id}/versions/{vid}/validate} — a path with no
     * handler behind it, under an {@code /admin} prefix this controller has
     * never had. The whole publish flow was a registered route with live UI and
     * three 404s underneath.
     *
     * @return the validation report, whether or not it blocks publication
     */
    @PostMapping("/{versionId}/validate")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<ValidationResponse> validateVersion(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long versionId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /courses/{}/versions/{}/validate - accountId={}",
                courseId, versionId, accountId);

        return ResponseEntity.ok(validationService.validateForPublish(versionId));
    }

    /**
     * Diff a draft version against the latest published one.
     *
     * Story 8.3 AC-2 — what the administrator reviews before writing a publish
     * note.
     */
    @GetMapping("/{versionId}/diff")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<VersionDiff> getVersionDiff(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long versionId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /courses/{}/versions/{}/diff - accountId={}",
                courseId, versionId, accountId);

        return ResponseEntity.ok(versionDiffService.generateDiff(versionId));
    }

    /**
     * Publish a draft version.
     *
     * Story 8.3 AC-3. Delegates to {@link PublishService}, which validates,
     * transitions DRAFT → PUBLISHED, writes the audit record and queues the
     * package build.
     *
     * A version that fails validation is refused with 422 and the report that
     * refused it, so the portal can show the administrator what to fix rather
     * than a bare failure.
     */
    @PostMapping("/{versionId}/publish")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<?> publishVersion(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long versionId,
            @Valid @RequestBody PublishVersionRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        String actor = authentication.getName();
        requireAdminRole(accountId);

        log.info("POST /courses/{}/versions/{}/publish - accountId={}, actor={}",
                courseId, versionId, accountId, actor);

        try {
            return ResponseEntity.ok(
                    publishService.publishVersion(versionId, request.publishNote(), actor));
        } catch (PublishService.PublishValidationException e) {
            // The report is the useful part of this failure: it says which
            // geometry, metadata or licence check blocked the publish.
            return ResponseEntity.unprocessableEntity().body(e.getValidationResponse());
        }
    }

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }
}
