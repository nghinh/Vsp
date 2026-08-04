package vnpt.vsp.module.course.entity;

/**
 * Verification status enum representing the data verification workflow state.
 * Per PRD Section 9.3: UNVERIFIED > PENDING_REVIEW > VERIFIED | REJECTED.
 */
public enum VerificationStatus {
    UNVERIFIED,
    PENDING_REVIEW,
    VERIFIED,
    REJECTED
}
