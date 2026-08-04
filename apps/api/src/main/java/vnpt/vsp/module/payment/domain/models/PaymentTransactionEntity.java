package vnpt.vsp.module.payment.domain.models;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * JPA entity representing a payment transaction.
 *
 * CRITICAL SECURITY INVARIANT: This entity MUST NEVER contain
 * PAN, CVV, expiry month/year, or any other prohibited card data.
 * Only opaque paymentMethodRef tokens issued by the provider are stored.
 */
@Entity
@Table(name = "payment_transactions", indexes = {
        @Index(name = "idx_payment_tx_state", columnList = "state, updated_at"),
        @Index(name = "idx_payment_tx_provider_ref", columnList = "provider_reference")
})
public class PaymentTransactionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "idempotency_key", nullable = false)
    private String idempotencyKey;

    @Column(name = "provider_reference")
    private String providerReference;

    /**
     * Opaque token referencing the payment method at the provider.
     * This is NOT card data — it is a provider-generated token.
     */
    @Column(name = "payment_method_ref")
    private String paymentMethodRef;

    @Column(nullable = false)
    private Long amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private PaymentState state = PaymentState.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(name = "failure_reason", length = 30)
    private PaymentFailureReason failureReason;

    @Column(name = "failure_message", columnDefinition = "TEXT")
    private String failureMessage;

    @Column(name = "metadata_json", columnDefinition = "TEXT")
    private String metadataJson;

    @Column(name = "refunded_amount", nullable = false)
    private Long refundedAmount = 0L;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Default constructor for JPA
    protected PaymentTransactionEntity() {
    }

    public PaymentTransactionEntity(String idempotencyKey, Long amount, String currency) {
        this.idempotencyKey = idempotencyKey;
        this.amount = amount;
        this.currency = currency;
        this.state = PaymentState.PENDING;
        this.createdAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    // Domain logic
    public void confirm(String providerReference, String paymentMethodRef) {
        this.providerReference = providerReference;
        this.paymentMethodRef = paymentMethodRef;
        this.state = PaymentState.SUCCEEDED;
        this.updatedAt = OffsetDateTime.now();
    }

    public void fail(PaymentFailureReason reason, String message) {
        this.state = PaymentState.FAILED;
        this.failureReason = reason;
        this.failureMessage = message;
        this.updatedAt = OffsetDateTime.now();
    }

    public void applyRefund(Long refundAmount) {
        if (refundAmount == null || refundAmount <= 0) {
            // Zero or negative refund amount — no-op, state unchanged
            return;
        }
        this.refundedAmount = (this.refundedAmount == null ? 0L : this.refundedAmount) + refundAmount;
        if (this.refundedAmount >= this.amount) {
            this.state = PaymentState.REFUNDED;
        } else {
            this.state = PaymentState.PARTIALLY_REFUNDED;
        }
        this.updatedAt = OffsetDateTime.now();
    }

    /** True if this transaction is in a terminal state (succeeded, failed, or refunded). */
    public boolean isTerminal() {
        return state == PaymentState.SUCCEEDED
            || state == PaymentState.FAILED
            || state == PaymentState.REFUNDED;
    }

    /** True if this transaction can be refunded (succeeded or partially refunded). */
    public boolean isRefundable() {
        return state.canRefund();
    }

    // Getters
    public UUID getId() { return id; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public String getProviderReference() { return providerReference; }
    public String getPaymentMethodRef() { return paymentMethodRef; }
    public Long getAmount() { return amount; }
    public String getCurrency() { return currency; }
    public PaymentState getState() { return state; }
    public PaymentFailureReason getFailureReason() { return failureReason; }
    public String getFailureMessage() { return failureMessage; }
    public String getMetadataJson() { return metadataJson; }
    public Long getRefundedAmount() { return refundedAmount; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }

    // Setters for JPA / builder patterns
    public void setProviderReference(String providerReference) { this.providerReference = providerReference; }
    public void setPaymentMethodRef(String paymentMethodRef) { this.paymentMethodRef = paymentMethodRef; }
    public void setState(PaymentState state) { this.state = state; }
    public void setFailureReason(PaymentFailureReason failureReason) { this.failureReason = failureReason; }
    public void setFailureMessage(String failureMessage) { this.failureMessage = failureMessage; }
    public void setMetadataJson(String metadataJson) { this.metadataJson = metadataJson; }
    public void setRefundedAmount(Long refundedAmount) { this.refundedAmount = refundedAmount; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
