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
 * REST controller for green condition admin endpoints.
 * Per Story 8.5 AC-2: update green speed (stimpmeter), firmness, moisture.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Endpoints:
 * - POST   /admin/courses/{courseId}/holes/{holeNumber}/green-conditions       — create
 * - PUT    /admin/courses/{courseId}/holes/{holeNumber}/green-conditions/{conditionId} — update
 * - GET    /admin/courses/{courseId}/holes/{holeNumber}/green-conditions      — list for hole
 * - GET    /admin/courses/{courseId}/green-conditions                         — list all for course
 */
@RestController
@RequestMapping("/admin")
public class GreenConditionController {

    private static final Logger log = LoggerFactory.getLogger(GreenConditionController.class);

    private final OperationsService operationsService;
    private final RoleService roleService;

    public GreenConditionController(OperationsService operationsService, RoleService roleService) {
        this.operationsService = operationsService;
        this.roleService = roleService;
    }

    @PostMapping("/courses/{courseId}/holes/{holeNumber}/green-conditions")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<GreenConditionDto> createGreenCondition(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @Valid @RequestBody GreenConditionCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        String publishedBy = authentication.getName();
        log.info("POST /admin/courses/{}/holes/{}/green-conditions - accountId={}, publishedBy={}",
                courseId, holeNumber, accountId, publishedBy);

        GreenConditionDto dto = operationsService.createGreenCondition(
                courseId, holeNumber,
                request.getStimpmeter(),
                request.getFirmness(),
                request.getMoisture(),
                request.getEffectiveFrom(),
                request.getExpiresAt(),
                publishedBy);

        return ResponseEntity.status(HttpStatus.CREATED).body(dto);
    }

    @PutMapping("/courses/{courseId}/holes/{holeNumber}/green-conditions/{conditionId}")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<GreenConditionDto> updateGreenCondition(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @PathVariable Long conditionId,
            @Valid @RequestBody GreenConditionUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("PUT /admin/courses/{}/holes/{}/green-conditions/{} - accountId={}",
                courseId, holeNumber, conditionId, accountId);

        GreenConditionDto dto = operationsService.updateGreenCondition(
                conditionId,
                request.getStimpmeter(),
                request.getFirmness(),
                request.getMoisture(),
                request.getEffectiveFrom(),
                request.getExpiresAt());

        return ResponseEntity.ok(dto);
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/green-conditions")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<GreenConditionDto>> getGreenConditionsForHole(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @RequestParam(required = false) Instant asOfDate) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("GET /admin/courses/{}/holes/{}/green-conditions - accountId={}, asOfDate={}",
                courseId, holeNumber, accountId, asOfDate);

        List<GreenConditionDto> conditions = operationsService.getGreenConditions(courseId, holeNumber, asOfDate);
        return ResponseEntity.ok(conditions);
    }

    @GetMapping("/courses/{courseId}/green-conditions")
    @PreAuthorize("hasAnyRole('GREENKEEPER', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<GreenConditionDto>> getAllGreenConditionsForCourse(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam(required = false) Instant asOfDate) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("GET /admin/courses/{}/green-conditions - accountId={}, asOfDate={}",
                courseId, accountId, asOfDate);

        List<GreenConditionDto> conditions = operationsService.getAllGreenConditions(courseId, asOfDate);
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
