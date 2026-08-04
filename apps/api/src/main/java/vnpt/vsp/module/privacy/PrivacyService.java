package vnpt.vsp.module.privacy;

import vnpt.vsp.module.privacy.dto.CreatePrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.ProcessPrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.PrivacyRequestResponse;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.Status;

import java.util.List;
import java.util.UUID;

/**
 * Service interface for privacy request management.
 * Per Story 2.5 AC-3: Users can request data export, account deletion,
 * and round deletion with auditable processing.
 */
public interface PrivacyService {

    /**
     * Create a new privacy request (PENDING).
     * Per Story 2.5 AC-3: DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION.
     */
    PrivacyRequestResponse createRequest(Long requesterGolferAccountId, CreatePrivacyRequestRequest request);

    /**
     * List all privacy requests for the requesting golfer.
     */
    List<PrivacyRequestResponse> getMyRequests(Long requesterGolferAccountId);

    /**
     * Get a specific privacy request for the requesting golfer.
     * Throws PRIVACY_001 if not found or not owned by requester.
     */
    PrivacyRequestResponse getRequestById(Long requesterGolferAccountId, Long requestId);

    /**
     * Admin: List all privacy requests filtered by status.
     */
    List<PrivacyRequestResponse> getRequestsByStatus(Status status);

    /**
     * Admin: Process (complete or reject) a privacy request.
     * Triggers the actual action (data export, account deletion, round deletion).
     * Per Story 2.5 AC-3: auditable processing.
     */
    PrivacyRequestResponse processRequest(Long adminId, Long requestId, ProcessPrivacyRequestRequest request);

    /**
     * Generate a full JSON data export for a golfer account.
     * Per Story 2.5 AC-3: data export includes profile, bags, rounds, scores.
     */
    String getDataExport(Long golferAccountId);

    /**
     * Anonymize a golfer account (for ACCOUNT_DELETION).
     * Per Story 2.5 AC-3: anonymizes PII, retains ID for audit.
     */
    void deleteAccount(Long golferAccountId);

    /**
     * Soft-delete a round and its associated scores (for ROUND_DELETION).
     * Per Story 2.5 AC-3: soft-delete preserves audit trail.
     */
    void deleteRound(Long golferAccountId, UUID roundId);
}
