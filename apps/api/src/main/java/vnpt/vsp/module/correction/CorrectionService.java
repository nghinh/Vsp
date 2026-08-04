package vnpt.vsp.module.correction;

import vnpt.vsp.module.correction.dto.CorrectionDetailResponse;
import vnpt.vsp.module.correction.dto.CorrectionQueueRequest;
import vnpt.vsp.module.correction.dto.CorrectionQueueResponse;
import vnpt.vsp.module.correction.dto.CorrectionResolutionRequest;
import vnpt.vsp.module.correction.dto.CorrectionResolutionResponse;
import vnpt.vsp.module.correction.dto.CorrectionReviewRequest;
import vnpt.vsp.module.correction.entity.CourseCorrection;

/**
 * Correction module public service interface.
 * Exposes course data correction workflow operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * <p>Per Story 9.2 AC-1, AC-2, AC-3.</p>
 */
public interface CorrectionService {

    /**
     * Returns a paginated, filtered list of corrections for the admin queue.
     *
     * @param request the filter and pagination parameters
     * @return paginated correction summaries ordered by submittedAt descending
     */
    CorrectionQueueResponse getQueue(CorrectionQueueRequest request);

    /**
     * Returns full detail for a single correction.
     *
     * @param correctionId the correction ID
     * @return full correction detail including reporter evidence and review fields
     */
    CorrectionDetailResponse getDetail(Long correctionId);

    /**
     * Applies a review action to a correction.
     * <ul>
     *   <li>APPROVE → status APPROVED</li>
     *   <li>REJECT → status REJECTED</li>
     *   <li>REQUEST_INFO → status INFO_REQUESTED</li>
     *   <li>CONVERT_TO_DRAFT → status CONVERTED_TO_DRAFT</li>
     * </ul>
     * Also creates an audit entry via {@link vnpt.vsp.module.audit.AuditService}.
     *
     * @param correctionId the correction ID
     * @param request the review action payload
     * @param reviewedBy the admin account ID performing the review
     * @return the updated correction
     */
    CourseCorrection review(Long correctionId, CorrectionReviewRequest request, Long reviewedBy);

    /**
     * Resolves a correction (approve or reject) and optionally creates draft entity changes.
     * <p>
     * This is the canonical resolution entry point for Story 9.3 Wave 2.
     * Unlike {@link #review(Long, CorrectionReviewRequest, Long)} which requires IN_REVIEW first,
     * this method accepts both PENDING and IN_REVIEW as valid starting states.
     * <p>
     * Side effects:
     * <ul>
     *   <li>Transitions correction status to APPROVED or REJECTED</li>
     *   <li>Writes CORRECTION_RESOLVED audit entry</li>
     *   <li>Dispatches push notification to the reporter (non-fatal)</li>
     *   <li>If APPROVED + produceDraftChange=true, creates draft entity changes linked to the correction</li>
     * </ul>
     *
     * @param correctionId the correction ID
     * @param request      the resolution request (decision, reason, produceDraftChange)
     * @param reviewedBy   admin user ID performing the resolution
     * @return CorrectionResolutionResponse with updated status, auditId, and notifiedAt
     */
    CorrectionResolutionResponse resolveCorrection(Long correctionId, CorrectionResolutionRequest request, Long reviewedBy);
}
