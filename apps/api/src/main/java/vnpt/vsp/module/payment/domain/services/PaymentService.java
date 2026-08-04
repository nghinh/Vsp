package vnpt.vsp.module.payment.domain.services;

import vnpt.vsp.module.payment.domain.models.*;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;
import vnpt.vsp.module.payment.domain.repositories.RefundRepository;
import vnpt.vsp.module.payment.infrastructure.idempotency.PaymentIdempotencyStore;
import vnpt.vsp.module.payment.infrastructure.provider.PaymentProviderAdapter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Payment module public service interface.
 *
 * Exposes payment intent creation, confirmation, refund, and status operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);
    private static final Duration IDEMPOTENCY_TTL = Duration.ofHours(24);

    private final PaymentRepository paymentRepository;
    private final RefundRepository refundRepository;
    private final PaymentAuditService auditService;
    private final PaymentProviderAdapter provider;
    private final PaymentIdempotencyStore idempotencyStore;

    public PaymentService(PaymentRepository paymentRepository,
                          RefundRepository refundRepository,
                          PaymentAuditService auditService,
                          PaymentProviderAdapter provider,
                          PaymentIdempotencyStore idempotencyStore) {
        this.paymentRepository = paymentRepository;
        this.refundRepository = refundRepository;
        this.auditService = auditService;
        this.provider = provider;
        this.idempotencyStore = idempotencyStore;
    }

    /**
     * Creates a new payment intent.
     *
     * @param amount          amount in smallest currency unit
     * @param currency        ISO 4217 currency code
     * @param idempotencyKey  client-supplied idempotency key
     * @param metadata        arbitrary key-value pairs
     * @param returnUrl       redirect URL for provider-hosted flow
     * @param actor           who initiated this intent
     * @return payment intent result
     */
    @Transactional
    public CreateIntentResult createPaymentIntent(Long amount, String currency,
                                                  String idempotencyKey,
                                                  Map<String, String> metadata,
                                                  String returnUrl,
                                                  String actor) {
        // Check for duplicate idempotency key
        Optional<PaymentTransactionEntity> existing = paymentRepository.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            var tx = existing.get();
            return new CreateIntentResult(
                    tx.getId().toString(),
                    tx.getProviderReference(),
                    tx.getState(),
                    tx.getAmount(),
                    tx.getCurrency(),
                    null, // clientSecret not stored
                    null, // returnUrl not stored
                    tx.getCreatedAt().toString()
            );
        }

        // Create transaction record
        var transaction = new PaymentTransactionEntity(idempotencyKey, amount, currency);
        if (metadata != null) {
            transaction.setMetadataJson(mapToJson(metadata));
        }
        transaction = paymentRepository.save(transaction);

        // Call provider
        var providerResult = provider.createIntent(amount, currency, metadata);

        // Update with provider reference
        transaction.setProviderReference(providerResult.providerReference());
        transaction = paymentRepository.save(transaction);

        // Audit
        auditService.logIntentCreated(transaction, idempotencyKey, actor);

        log.info("Payment intent created: id={}, providerRef={}, amount={} {}",
                transaction.getId(), providerResult.providerReference(), amount, currency);

        return new CreateIntentResult(
                transaction.getId().toString(),
                providerResult.providerReference(),
                PaymentState.PENDING,
                amount,
                currency,
                providerResult.clientSecret(),
                returnUrl != null ? returnUrl : providerResult.returnUrl(),
                transaction.getCreatedAt().toString()
        );
    }

    /**
     * Confirms a payment (called by provider webhook or callback).
     *
     * @param transactionId    platform transaction ID
     * @param providerReference provider's transaction reference
     * @param success         whether confirmation succeeded
     * @param failureReason   failure reason if not success
     * @param failureMessage   failure message if not success
     * @param actor           who initiated (usually PROVIDER_WEBHOOK)
     * @return updated transaction
     */
    @Transactional
    public PaymentTransactionEntity confirmPayment(UUID transactionId,
                                                   String providerReference,
                                                   boolean success,
                                                   PaymentFailureReason failureReason,
                                                   String failureMessage,
                                                   String actor) {
        var transaction = paymentRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + transactionId));

        if (success) {
            transaction.confirm(providerReference, null);
            auditService.logConfirmationSucceeded(transaction, actor);
            log.info("Payment confirmed: id={}, providerRef={}", transaction.getId(), providerReference);
        } else {
            PaymentState previousState = transaction.getState();
            transaction.fail(failureReason, failureMessage);
            auditService.logConfirmationFailed(transaction, failureReason, failureMessage, actor);
            log.warn("Payment failed: id={}, reason={}, message={}",
                    transaction.getId(), failureReason, failureMessage);
        }

        return paymentRepository.save(transaction);
    }

    /**
     * Gets a payment by ID.
     */
    public Optional<PaymentTransactionEntity> getPayment(UUID transactionId) {
        return paymentRepository.findById(transactionId);
    }

    /**
     * Gets a payment by idempotency key.
     */
    public Optional<PaymentTransactionEntity> getPaymentByIdempotencyKey(String idempotencyKey) {
        return paymentRepository.findByIdempotencyKey(idempotencyKey);
    }

    /**
     * Issues a refund.
     *
     * @param transactionId  the payment transaction to refund
     * @param amount         refund amount (null for full refund)
     * @param reason         refund reason
     * @param reasonDetail   free-text detail when reason is OTHER
     * @param idempotencyKey idempotency key
     * @param actor          who requested the refund
     * @return refund result
     */
    @Transactional
    public RefundResult refundPayment(UUID transactionId,
                                      Long amount,
                                      RefundReason reason,
                                      String reasonDetail,
                                      String idempotencyKey,
                                      String actor) {
        var transaction = paymentRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + transactionId));

        if (!transaction.getState().canRefund()) {
            throw new IllegalStateException("Transaction cannot be refunded in state: " + transaction.getState());
        }

        // Check for duplicate idempotency key
        Optional<RefundRequestEntity> existingRefund = refundRepository.findByIdempotencyKey(idempotencyKey);
        if (existingRefund.isPresent()) {
            var refund = existingRefund.get();
            return new RefundResult(
                    refund.getId().toString(),
                    transaction.getId().toString(),
                    refund.getStatus(),
                    refund.getAmount(),
                    refund.getReason(),
                    refund.getProviderRefundRef(),
                    refund.getRequestedAt().toString(),
                    refund.getProcessedAt() != null ? refund.getProcessedAt().toString() : null
            );
        }

        Long refundAmount = amount != null ? amount : transaction.getAmount() - transaction.getRefundedAmount();

        var refund = new RefundRequestEntity(
                transaction, refundAmount, reason, reasonDetail, idempotencyKey
        );
        refund = refundRepository.save(refund);

        auditService.logRefundRequested(transaction, refund, actor);

        // Call provider
        var providerResult = provider.refund(
                transaction.getProviderReference(),
                refundAmount,
                reason != null ? reason.name() : null
        );

        if (providerResult.success()) {
            refund.succeed(providerResult.providerRefundRef());
            transaction.applyRefund(refundAmount);
            auditService.logRefundSucceeded(transaction, refund, transaction.getState(), actor);
            log.info("Refund succeeded: refundId={}, amount={}", refund.getId(), refundAmount);
        } else {
            refund.fail();
            auditService.logRefundFailed(transaction, refund, actor,
                    providerResult.failureMessage());
            log.warn("Refund failed: refundId={}, reason={}", refund.getId(), providerResult.failureMessage());
        }

        refundRepository.save(refund);
        paymentRepository.save(transaction);

        return new RefundResult(
                refund.getId().toString(),
                transaction.getId().toString(),
                refund.getStatus(),
                refund.getAmount(),
                refund.getReason(),
                refund.getProviderRefundRef(),
                refund.getRequestedAt().toString(),
                refund.getProcessedAt() != null ? refund.getProcessedAt().toString() : null
        );
    }

    // ─── Result DTOs ──────────────────────────────────────────────────────────

    public record CreateIntentResult(
            String transactionId,
            String providerReference,
            PaymentState state,
            Long amount,
            String currency,
            String clientSecret,
            String returnUrl,
            String createdAt
    ) {}

    public record RefundResult(
            String refundRequestId,
            String transactionId,
            RefundStatus status,
            Long amount,
            RefundReason reason,
            String providerRefundRef,
            String requestedAt,
            String processedAt
    ) {}

    private static String mapToJson(Map<String, String> map) {
        if (map == null || map.isEmpty()) {
            return "{}";
        }
        var sb = new StringBuilder("{");
        var entries = map.entrySet().iterator();
        while (entries.hasNext()) {
            var e = entries.next();
            sb.append("\"")
              .append(e.getKey().replace("\"", "\\\""))
              .append("\":\"")
              .append((e.getValue() != null ? e.getValue() : "").replace("\"", "\\\""))
              .append("\"");
            if (entries.hasNext()) sb.append(",");
        }
        sb.append("}");
        return sb.toString();
    }
}
