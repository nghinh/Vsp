package vnpt.vsp.module.payment.infrastructure.provider;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;

/**
 * Stub implementation of PaymentProviderAdapter for development and testing.
 *
 * In production, replace this with a real provider adapter (Stripe, payOS, VNPay)
 * by creating a @Primary bean that implements PaymentProviderAdapter.
 *
 * This stub simulates provider behavior without making any external calls.
 */
@Component
public class StubPaymentProviderAdapter implements PaymentProviderAdapter {

    private static final Logger log = LoggerFactory.getLogger(StubPaymentProviderAdapter.class);

    @Override
    public CreateIntentResult createIntent(Long amount, String currency, Map<String, String> metadata) {
        String ref = "stub_pi_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        String secret = "stub_secret_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        log.info("[STUB] Created payment intent: ref={}, amount={} {}, metadata={}", ref, amount, currency, metadata);
        return new CreateIntentResult(ref, secret, null);
    }

    @Override
    public ConfirmResult confirm(String providerReference) {
        log.info("[STUB] Confirming payment: ref={}", providerReference);
        // Stub always succeeds
        return new ConfirmResult(true, "succeeded", null, null);
    }

    @Override
    public RefundResult refund(String providerReference, Long amount, String reason) {
        String refundRef = "stub_re_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        log.info("[STUB] Issuing refund: originalRef={}, amount={}, reason={}", providerReference, amount, reason);
        return new RefundResult(true, refundRef, "succeeded", null);
    }

    @Override
    public String getTransactionState(String providerReference) {
        log.info("[STUB] Querying transaction state: ref={}", providerReference);
        // Stub always reports succeeded
        return "succeeded";
    }
}
