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
import vnpt.vsp.module.correction.CorrectionService;
import vnpt.vsp.module.correction.dto.CorrectionDetailResponse;
import vnpt.vsp.module.correction.dto.CorrectionQueueRequest;
import vnpt.vsp.module.correction.dto.CorrectionQueueResponse;
import vnpt.vsp.module.correction.dto.CorrectionResolutionRequest;
import vnpt.vsp.module.correction.dto.CorrectionResolutionResponse;
import vnpt.vsp.module.correction.dto.CorrectionReviewRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;

/**
 * REST controller for admin correction queue management endpoints.
 *
 * <p>Endpoints:
 * <ul>
 *   <li>GET    /admin/corrections              — paginated queue with filters</li>
 *   <li>GET    /admin/corrections/{id}         — correction detail</li>
 *   <li>POST   /admin/corrections/{id}/review  — apply review action</li>
 *   <li>GET    /admin/corrections/{id}/map-context — official course/hole geometry</li>
 * </ul>
 *
 * <p>All endpoints require COURSE_ADMIN, GREENKEEPER, or SUPER_ADMIN RBAC role.
 *
 * Per Story 9.2 AC-1 (queue filters), AC-2 (detail), AC-3 (review actions).
 */
@RestController
@RequestMapping("/admin/corrections")
public class CorrectionController {

    private static final Logger log = LoggerFactory.getLogger(CorrectionController.class);

    private final CorrectionService correctionService;
    private final RoleService roleService;

    public CorrectionController(CorrectionService correctionService, RoleService roleService) {
        this.correctionService = correctionService;
        this.roleService = roleService;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /admin/corrections — paginated queue with filters
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Returns a paginated list of corrections matching the given filters.
     *
     * @param courseId   filter by course ID
     * @param hole       filter by hole number
     * @param type       filter by correction type
     * @param status     filter by status
     * @param confidenceMin minimum confidence
     * @param confidenceMax maximum confidence
     * @param from       submitted on or after this instant
     * @param to         submitted on or before this instant
     * @param page       page number (0-indexed)
     * @param pageSize   page size (default 20)
     */
    @GetMapping
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CorrectionQueueResponse> getQueue(
            Authentication authentication,
            @RequestParam(required = false) Long courseId,
            @RequestParam(required = false) Integer hole,
            @RequestParam(required = false) CorrectionType type,
            @RequestParam(required = false) CorrectionStatus status,
            @RequestParam(required = false) vnpt.vsp.module.course.entity.VerificationStatus verificationStatus,
            @RequestParam(required = false) vnpt.vsp.module.correction.entity.GeometryLayer layer,
            @RequestParam(required = false) Integer minCorroborationCount,
            @RequestParam(required = false) BigDecimal confidenceMin,
            @RequestParam(required = false) BigDecimal confidenceMax,
            @RequestParam(required = false) Instant from,
            @RequestParam(required = false) Instant to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/corrections - accountId={}, courseId={}, hole={}, type={}, status={}, page={}",
                accountId, courseId, hole, type, status, page);

        CorrectionQueueRequest request = new CorrectionQueueRequest();
        request.setCourseId(courseId);
        request.setHoleNumber(hole);
        request.setType(type);
        request.setStatus(status);
        request.setVerificationStatus(verificationStatus);
        request.setGeometryLayer(layer);
        request.setMinCorroborationCount(minCorroborationCount);
        request.setConfidenceMin(confidenceMin);
        request.setConfidenceMax(confidenceMax);
        request.setFromDate(from);
        request.setToDate(to);
        request.setPage(page);
        request.setPageSize(pageSize);

        CorrectionQueueResponse response = correctionService.getQueue(request);
        return ResponseEntity.ok(response);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /admin/corrections/{id} — correction detail
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Returns full detail for a single correction including reporter evidence,
     * location, and review history.
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CorrectionDetailResponse> getDetail(
            Authentication authentication,
            @PathVariable Long id) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/corrections/{} - accountId={}", id, accountId);

        CorrectionDetailResponse response = correctionService.getDetail(id);
        return ResponseEntity.ok(response);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST /admin/corrections/{id}/review — apply review action
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Applies a review action (APPROVE, REJECT, REQUEST_INFO, CONVERT_TO_DRAFT)
     * to a correction and creates an audit entry.
     *
     * @param request the review action and optional reason/note
     */
    @PostMapping("/{id}/review")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<Map<String, Object>> review(
            Authentication authentication,
            @PathVariable Long id,
            @Valid @RequestBody CorrectionReviewRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/corrections/{}/review - accountId={}, action={}",
                id, accountId, request.getAction());

        CourseCorrection updated = correctionService.review(id, request, accountId);

        return ResponseEntity.ok(Map.of(
                "id", updated.getId(),
                "status", updated.getStatus().name(),
                "reviewedAt", updated.getReviewedAt() != null ? updated.getReviewedAt().toString() : ""
        ));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST /admin/corrections/{id}/resolve — resolve correction (Story 9.3 Wave 3)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Resolves a correction (APPROVE or REJECT) and optionally creates draft entity changes.
     * <p>
     * Unlike {@code /review} which requires IN_REVIEW first, this endpoint accepts both
     * PENDING and IN_REVIEW corrections. On APPROVE with produceDraftChange=true, draft
     * entity changes are created and linked to the correction. Reporter is notified
     * asynchronously (non-fatal). Audit entry is written for CORRECTION_RESOLVED.
     *
     * @param request the resolution request (decision, reason, produceDraftChange)
     */
    @PostMapping("/{id}/resolve")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<CorrectionResolutionResponse> resolve(
            Authentication authentication,
            @PathVariable Long id,
            @Valid @RequestBody CorrectionResolutionRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("POST /admin/corrections/{}/resolve - accountId={}, decision={}, produceDraftChange={}",
                id, accountId, request.decision(), request.produceDraftChange());

        CorrectionResolutionResponse response = correctionService.resolveCorrection(id, request, accountId);
        return ResponseEntity.ok(response);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /admin/corrections/{id}/map-context — official geometry for map overlay
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Returns official course and hole geometry so the portal can render
     * a comparison overlay with the reporter's GPS location.
     *
     * <p>Stub implementation — full geometry fetch is deferred to Story 9.3
     * when the geometry editor integration is complete.</p>
     */
    @GetMapping("/{id}/map-context")
    @PreAuthorize("hasRole(#authentication, 'COURSE_ADMIN') or hasRole(#authentication, 'GREENKEEPER') or hasRole(#authentication, 'SUPER_ADMIN')")
    public ResponseEntity<Map<String, Object>> getMapContext(
            Authentication authentication,
            @PathVariable Long id) {

        Long accountId = (Long) authentication.getPrincipal();
        requireAdminRole(accountId);

        log.info("GET /admin/corrections/{}/map-context - accountId={}", id, accountId);

        // Deferred: fetch official geometry from CourseService
        // For now, return a placeholder structure
        return ResponseEntity.ok(Map.of(
                "correctionId", id,
                "message", "Map context geometry fetch is deferred to Story 9.3"
        ));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private void requireAdminRole(Long accountId) {
        if (!roleService.hasRole(accountId, RoleName.COURSE_ADMIN) &&
                !roleService.hasRole(accountId, RoleName.GREENKEEPER) &&
                !roleService.hasRole(accountId, RoleName.SUPER_ADMIN)) {
            throw new VspApiException(VspErrorCode.AUTH_005, "COURSE_ADMIN, GREENKEEPER, or SUPER_ADMIN role required");
        }
    }
}
