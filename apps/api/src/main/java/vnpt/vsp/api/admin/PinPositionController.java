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
import java.util.stream.Collectors;

/**
 * REST controller for pin position admin endpoints.
 * Per Story 8.5 AC-1: place/schedule pins with effective + expiration times.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Endpoints:
 * - POST   /admin/courses/{courseId}/holes/{holeNumber}/pins       — create pin
 * - PUT    /admin/courses/{courseId}/holes/{holeNumber}/pins/{pinId} — update pin
 * - GET    /admin/courses/{courseId}/holes/{holeNumber}/pins      — list pins for hole
 * - GET    /admin/courses/{courseId}/pins                         — list all pins for course
 */
@RestController
@RequestMapping("/admin")
public class PinPositionController {

    private static final Logger log = LoggerFactory.getLogger(PinPositionController.class);

    private final OperationsService operationsService;
    private final RoleService roleService;

    public PinPositionController(OperationsService operationsService, RoleService roleService) {
        this.operationsService = operationsService;
        this.roleService = roleService;
    }

    @PostMapping("/courses/{courseId}/holes/{holeNumber}/pins")
    @PreAuthorize("hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<PinPositionDto> createPin(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @Valid @RequestBody PinPositionCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        String publishedBy = authentication.getName();
        log.info("POST /admin/courses/{}/holes/{}/pins - accountId={}, publishedBy={}",
                courseId, holeNumber, accountId, publishedBy);

        PinPositionDto dto = operationsService.createPinPosition(
                courseId, holeNumber,
                request.getPosition(),
                request.getEffectiveFrom(),
                request.getExpiresAt(),
                publishedBy,
                request.getConfidence());

        return ResponseEntity.status(HttpStatus.CREATED).body(dto);
    }

    @PutMapping("/courses/{courseId}/holes/{holeNumber}/pins/{pinId}")
    @PreAuthorize("hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<PinPositionDto> updatePin(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @PathVariable Long pinId,
            @Valid @RequestBody PinPositionUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("PUT /admin/courses/{}/holes/{}/pins/{} - accountId={}",
                courseId, holeNumber, pinId, accountId);

        PinPositionDto dto = operationsService.updatePinPosition(
                pinId,
                request.getPosition(),
                request.getEffectiveFrom(),
                request.getExpiresAt());

        return ResponseEntity.ok(dto);
    }

    @GetMapping("/courses/{courseId}/holes/{holeNumber}/pins")
    @PreAuthorize("hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<List<PinPositionDto>> getPinsForHole(
            Authentication authentication,
            @PathVariable Long courseId,
            @PathVariable Integer holeNumber,
            @RequestParam(required = false) Instant asOfDate) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("GET /admin/courses/{}/holes/{}/pins - accountId={}, asOfDate={}",
                courseId, holeNumber, accountId, asOfDate);

        List<PinPositionDto> pins = operationsService.getPinPositions(courseId, holeNumber, asOfDate);
        return ResponseEntity.ok(pins);
    }

    @GetMapping("/courses/{courseId}/pins")
    @PreAuthorize("hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<List<PinPositionDto>> getAllPinsForCourse(
            Authentication authentication,
            @PathVariable Long courseId,
            @RequestParam(required = false) Instant asOfDate) {

        Long accountId = (Long) authentication.getPrincipal();
        requireGreenkeeperRole(accountId);

        log.info("GET /admin/courses/{}/pins - accountId={}, asOfDate={}",
                courseId, accountId, asOfDate);

        List<PinPositionDto> pins = operationsService.getAllPinPositions(courseId, asOfDate);
        return ResponseEntity.ok(pins);
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
