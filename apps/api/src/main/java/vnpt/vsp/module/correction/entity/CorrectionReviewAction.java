package vnpt.vsp.module.correction.entity;

/**
 * Actions a reviewer (COURSE_ADMIN, GREENKEEPER, or SUPER_ADMIN) can take
 * when reviewing a correction.
 *
 * <p>Each action triggers a corresponding state transition in
 * {@link CorrectionStatus} and an audit entry via {@code AuditService}.</p>
 *
 * Per Story 9.2 AC-3.
 */
public enum CorrectionReviewAction {
    APPROVE,
    REJECT,
    REQUEST_INFO,
    CONVERT_TO_DRAFT
}
