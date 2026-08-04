package vnpt.vsp.module.payment.infrastructure.provider;

import java.util.Map;

/**
 * Interface for payment provider operations.
 *
 * Implementations adapt to specific providers (Stripe, payOS, VNPay, etc.).
 * The platform never handles raw card data — only opaque tokens from the provider.
 */
public interface PaymentProviderAdapter {

    /**
     * Creates a payment intent with the provider.
     *
     * @param amount      amount in smallest currency unit
     * @param currency    ISO 4217 currency code
     * @param metadata    arbitrary key-value metadata
     * @return provider response containing reference and client secret
     */
    CreateIntentResult createIntent(Long amount, String currency, Map<String, String> metadata);

    /**
     * Confirms a payment with the provider.
     *
     * @param providerReference the provider's transaction reference
     * @return confirmation result with state
     */
    ConfirmResult confirm(String providerReference);

    /**
     * Issues a refund through the provider.
     *
     * @param providerReference the original provider transaction reference
     * @param amount           amount to refund (null for full refund)
     * @param reason           provider-specific refund reason
     * @return refund result with provider refund reference
     */
    RefundResult refund(String providerReference, Long amount, String reason);

    /**
     * Queries the provider for the current state of a transaction.
     *
     * @param providerReference the provider's transaction reference
     * @return the current state as reported by the provider
     */
    String getTransactionState(String providerReference);

    // ─── Result types ─────────────────────────────────────────────────────────

    record CreateIntentResult(
            String providerReference,
            String clientSecret,
            String returnUrl
    ) {}

    record ConfirmResult(
            boolean success,
            String state,
            String failureReason,
            String failureMessage
    ) {}

    record RefundResult(
            boolean success,
            String providerRefundRef,
            String status,
            String failureMessage
    ) {}
}
