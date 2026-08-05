package vnpt.vsp.api.admin;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.api.pagination.PageTokenService;
import vnpt.vsp.module.coursealert.CourseAlertService;
import vnpt.vsp.module.coursealert.dto.CourseAlertCreateRequest;
import vnpt.vsp.module.coursealert.dto.CourseAlertListResponse;
import vnpt.vsp.module.coursealert.dto.CourseAlertResponse;
import vnpt.vsp.module.coursealert.dto.CourseAlertUpdateRequest;
import vnpt.vsp.module.coursealert.entity.AlertTargetType;
import vnpt.vsp.module.coursealert.entity.AlertType;
import vnpt.vsp.module.coursealert.entity.CourseAlert;
import vnpt.vsp.module.coursealert.entity.DeliveryStatus;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * REST controller for admin course alert management endpoints.
 * Per Story 8.6: AC-1 targeting, AC-2 visual distinction, AC-3 delivery/expiry/acknowledge/audit.
 *
 * Endpoints:
 * - POST   /admin/alerts                — create and send alert
 * - GET    /admin/alerts                — list alerts with filtering
 * - GET    /admin/alerts/{alertId}      — get alert detail
 * - PATCH  /admin/alerts/{alertId}      — update alert (before effective)
 * - DELETE /admin/alerts/{alertId}       — cancel alert
 * - POST   /admin/alerts/{alertId}/acknowledge — acknowledge alert
 */
@RestController
@RequestMapping("/admin/alerts")
public class CourseAlertController {

    private static final Logger log = LoggerFactory.getLogger(CourseAlertController.class);

    private final CourseAlertService alertService;
    private final RoleService roleService;
    private final PageTokenService pageTokenService;

    public CourseAlertController(
            CourseAlertService alertService,
            RoleService roleService,
            PageTokenService pageTokenService) {
        this.alertService = alertService;
        this.roleService = roleService;
        this.pageTokenService = pageTokenService;
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseAlertResponse> createAlert(
            Authentication authentication,
            @Valid @RequestBody CourseAlertCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/alerts - accountId={}, alertType={}, title={}",
                accountId, request.getAlertType(), request.getTitle());

        CourseAlert alert = alertService.sendAlert(request, String.valueOf(accountId));
        return ResponseEntity.status(HttpStatus.CREATED).body(CourseAlertResponse.fromEntity(alert));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseAlertListResponse> listAlerts(
            Authentication authentication,
            @RequestParam(required = false) AlertType alertType,
            @RequestParam(required = false) AlertTargetType targetType,
            @RequestParam(required = false) UUID targetId,
            @RequestParam(required = false) DeliveryStatus deliveryStatus,
            @RequestParam(required = false) OffsetDateTime from,
            @RequestParam(required = false) OffsetDateTime to,
            @RequestParam(required = false) String pageToken,
            @RequestParam(defaultValue = "20") int pageSize) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/alerts - accountId={}, alertType={}, targetType={}, deliveryStatus={}",
                accountId, alertType, targetType, deliveryStatus);

        List<CourseAlert> alerts = alertService.listAlerts(alertType, targetType, targetId, deliveryStatus, from, to);

        List<CourseAlertResponse> responses = alerts.stream()
                .map(CourseAlertResponse::fromEntity)
                .collect(Collectors.toList());

        // Build pagination response
        int total = responses.size();
        int totalPages = (int) Math.ceil((double) total / pageSize);
        int page = 0;

        CourseAlertListResponse.Pagination pagination = new CourseAlertListResponse.Pagination(
                page, pageSize, total, totalPages,
                true, page >= totalPages - 1,
                null // nextPageToken would be computed if there were real pagination
        );

        return ResponseEntity.ok(new CourseAlertListResponse(responses, pagination));
    }

    @GetMapping("/{alertId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseAlertResponse> getAlert(
            Authentication authentication,
            @PathVariable Long alertId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/alerts/{} - accountId={}", alertId, accountId);

        CourseAlert alert = alertService.getAlert(alertId);
        return ResponseEntity.ok(CourseAlertResponse.fromEntity(alert));
    }

    @PatchMapping("/{alertId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<CourseAlertResponse> updateAlert(
            Authentication authentication,
            @PathVariable Long alertId,
            @Valid @RequestBody CourseAlertUpdateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("PATCH /admin/alerts/{} - accountId={}", alertId, accountId);

        CourseAlert alert = alertService.updateAlert(alertId, request);
        return ResponseEntity.ok(CourseAlertResponse.fromEntity(alert));
    }

    @DeleteMapping("/{alertId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<Void> cancelAlert(
            Authentication authentication,
            @PathVariable Long alertId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("DELETE /admin/alerts/{} - accountId={}", alertId, accountId);

        alertService.cancelAlert(alertId, String.valueOf(accountId));
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{alertId}/acknowledge")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<Void> acknowledgeAlert(
            Authentication authentication,
            @PathVariable Long alertId) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/alerts/{}/acknowledge - accountId={}", alertId, accountId);

        alertService.acknowledgeAlert(alertId, String.valueOf(accountId));
        return ResponseEntity.ok().build();
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN or SUPER_ADMIN role required");
        }
    }
}
