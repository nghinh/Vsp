package vnpt.vsp.module.payment.domain.models;

/**
 * Reason for a refund request.
 */
public enum RefundReason {
    DUPLICATE,
    FRAUDULENT,
    REQUESTED_BY_CUSTOMER,
    COURSE_CANCELLATION,
    OTHER
}
