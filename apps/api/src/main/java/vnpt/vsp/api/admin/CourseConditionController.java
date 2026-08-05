package vnpt.vsp.api.admin;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.operations.OperationsService;
import vnpt.vsp.module.operations.dto.*;
import vnpt.vsp.module.role.entity.RoleName;
import vnpt.vsp.module.role.RoleService;

import java.time.Instant;
import java.util.List;

/**
 * REST controller for course condition admin endpoints.
 * Per Story 8.5 AC-2: course status, maintenance, and alert management.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Endpoints:
 * - POST   /admin/courses/{courseId}/conditions       — create
 * - PUT    /admin/courses/{courseId}/conditions/{conditionId} — update
 * - GET    /admin/courses/{courseId}/conditions      — list
 */
@RestController
@RequestMapping("/admin")
public class CourseConditionController {

    private static final Logger log = LoggerFactory.getLogger(CourseConditionController.class);

    private final OperationsService operationsService;
    private final RoleService roleService;

    public CourseConditionController(OperationsService operationsService, RoleService roleService) {
        this.operationsService = operationsService;
        this.roleService = roleService;
    }

    @PostMapping("/courses/{courseId}/conditions")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseConditionDto> createCourseCondition(
            Authentication authentication,
            @PathVariable Long courseId,
            @Valid @RequestBody CourseConditionCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        String publishedBy = authentication.getName();
        log.info("POST /admin/courses/{}/conditions - accountId={}, publishedBy={}",
                courseId, accountId, publishedBy);

        CourseConditionDto dto = operationsService.createCourseCondition(
                courseId,
                request.getConditionType(),
                request.getSeverity(),
                request.getDescription(),
                request.getEffectiveFrom(),
                request.getExpiresAt(),
                publishedBy);

        return ResponseEntity.status(HttpStatus.CREATED).body(dto);
    }

    @PutMapping("/courses/{courseId}/conditions/{conditionId}")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseConditionDto> updateCourseCondition(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Long conditionId,
            @Valid @RequestBody CourseConditionUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("PUT /admin/courses/{}/conditions/{} - accountId={}",
                courseId, conditionId, accountId);

        CourseConditionDto dto = operationsService.updateCourseCondition(
                conditionId,
                request.getConditionType(),
                request.getSeverity(),
                request.getDescription(),
                request.getEffectiveFrom(),
                request.getExpiresAt());

        return ResponseEntity.ok(dto);
    }

    @GetMapping("/courses/{courseId}/conditions")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<CourseConditionDto>> getCourseConditions(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam(required = false) Instant asOfDate) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("GET /admin/courses/{}/conditions - accountId={}, asOfDate={}",
                courseId, accountId, asOfDate);

        List<CourseConditionDto> conditions = operationsService.getCourseConditions(courseId, asOfDate);
        return ResponseEntity.ok(conditions);
    }

    private void requireGreenkeeperRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.GREENKEEPER) &&
                !roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new vnpt.vsp.api.error.VspApiException(
                    vnpt.vsp.api.error.VspErrorCode.AUTH_005,
                    "GREENKEEPER, COURSE_ADMIN, or SUPER_ADMIN role required");
        }
    }
}
