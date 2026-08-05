package vnpt.vsp.module.privacy;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.privacy.dto.CreatePrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.ProcessPrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.PrivacyRequestResponse;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.Status;

import java.net.URI;
import java.util.List;

/**
 * REST controller for privacy request endpoints.
 * Per Story 2.5 AC-3: Users can request data export, account deletion,
 * round deletion with auditable processing.
 * <p>
 * Golfer-facing: POST /privacy/requests, GET /privacy/requests, GET /privacy/requests/{id}
 * Admin-facing: GET /admin/privacy-requests, PUT /admin/privacy-requests/{id}
 */
@RestController
@vnpt.vsp.module.privacy.PrivacyModule
public class PrivacyController {

    private final PrivacyService privacyService;

    public PrivacyController(PrivacyService privacyService) {
        this.privacyService = privacyService;
    }

    // ─── Golfer-facing endpoints ────────────────────────────────────────────

    /**
     * Submit a new privacy request.
     * Per Story 2.5 AC-3: DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION.
     */
    @PostMapping("/privacy/requests")
    public ResponseEntity<PrivacyRequestResponse> createRequest(
            Authentication authentication,
            @Valid @RequestBody CreatePrivacyRequestRequest request) {
        Long accountId = (Long) authentication.getPrincipal();
        PrivacyRequestResponse response = privacyService.createRequest(accountId, request);
        return ResponseEntity
                .created(URI.create("/privacy/requests/" + response.getId()))
                .body(response);
    }

    /**
     * List all privacy requests for the authenticated golfer.
     */
    @GetMapping("/privacy/requests")
    public ResponseEntity<List<PrivacyRequestResponse>> listMyRequests(Authentication authentication) {
        Long accountId = (Long) authentication.getPrincipal();
        List<PrivacyRequestResponse> requests = privacyService.getMyRequests(accountId);
        return ResponseEntity.ok(requests);
    }

    /**
     * Get a specific privacy request for the authenticated golfer.
     */
    @GetMapping("/privacy/requests/{id}")
    public ResponseEntity<PrivacyRequestResponse> getMyRequest(
            Authentication authentication,
            @PathVariable Long id) {
        Long accountId = (Long) authentication.getPrincipal();
        PrivacyRequestResponse response = privacyService.getRequestById(accountId, id);
        return ResponseEntity.ok(response);
    }

    /**
     * Get data export for the authenticated golfer.
     * Per Story 2.5 AC-3: generates JSON export of profile, bags, rounds, scores.
     */
    @GetMapping("/privacy/requests/{id}/export")
    public ResponseEntity<String> getDataExport(
            Authentication authentication,
            @PathVariable Long id) {
        Long accountId = (Long) authentication.getPrincipal();
        // Verify ownership
        privacyService.getRequestById(accountId, id);
        String export = privacyService.getDataExport(accountId);
        return ResponseEntity.ok()
                .header("Content-Type", "application/json")
                .body(export);
    }

    // ─── Admin-facing endpoints ────────────────────────────────────────────

    /**
     * List all privacy requests filtered by status (admin only).
     * <p>
     * "Admin only" was a comment, not a check, until the {@code /admin/**} chain
     * was repaired. The listing names every golfer who has asked to be deleted
     * or exported, so it is restricted to the two roles that handle data-subject
     * requests.
     */
    @GetMapping("/admin/privacy-requests")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'AUDITOR')")
    public ResponseEntity<List<PrivacyRequestResponse>> listRequestsByStatus(
            @RequestParam(required = false) String status) {
        Status filterStatus = null;
        if (status != null && !status.isEmpty()) {
            try {
                filterStatus = Status.valueOf(status.toUpperCase());
            } catch (IllegalArgumentException e) {
                // Invalid status - return empty list
                return ResponseEntity.ok(List.of());
            }
        }
        List<PrivacyRequestResponse> requests;
        if (filterStatus != null) {
            requests = privacyService.getRequestsByStatus(filterStatus);
        } else {
            // Return all
            requests = privacyService.getRequestsByStatus(Status.PENDING);
            requests.addAll(privacyService.getRequestsByStatus(Status.PROCESSING));
        }
        return ResponseEntity.ok(requests);
    }

    /**
     * Process (complete or reject) a privacy request (admin only).
     * Per Story 2.5 AC-3: auditable processing.
     */
    @PutMapping("/admin/privacy-requests/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'AUDITOR')")
    public ResponseEntity<PrivacyRequestResponse> processRequest(
            Authentication authentication,
            @PathVariable Long id,
            @Valid @RequestBody ProcessPrivacyRequestRequest request) {
        Long adminId = (Long) authentication.getPrincipal();
        PrivacyRequestResponse response = privacyService.processRequest(adminId, id, request);
        return ResponseEntity.ok(response);
    }
}
