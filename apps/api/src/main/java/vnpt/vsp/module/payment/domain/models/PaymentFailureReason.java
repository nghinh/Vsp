package vnpt.vsp.module.payment.domain.models;

/**
 * Machine-readable failure reason when payment fails.
 */
public enum PaymentFailureReason {
    PROVIDER_DECLINED,
    INSUFFICIENT_FUNDS,
    NETWORK_ERROR,
    CANCELLED,
    EXPIRED,
    UNKNOWN
}
