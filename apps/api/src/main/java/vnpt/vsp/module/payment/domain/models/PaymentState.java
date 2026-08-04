package vnpt.vsp.module.payment.domain.models;

/**
 * Payment lifecycle state.
 */
public enum PaymentState {
    PENDING,
    SUCCEEDED,
    FAILED,
    REFUNDED,
    PARTIALLY_REFUNDED;

    /** True if this transaction can be refunded. */
    public boolean canRefund() {
        return this == SUCCEEDED || this == PARTIALLY_REFUNDED;
    }
}
