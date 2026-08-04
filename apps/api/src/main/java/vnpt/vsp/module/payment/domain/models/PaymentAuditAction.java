package vnpt.vsp.module.payment.domain.models;

/**
 * Types of auditable payment actions.
 */
public enum PaymentAuditAction {
    INTENT_CREATED,
    CONFIRMATION_SUCCEEDED,
    CONFIRMATION_FAILED,
    REFUND_REQUESTED,
    REFUND_SUCCEEDED,
    REFUND_FAILED,
    RECONCILIATION_DISCREPANCY
}
