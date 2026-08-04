package vnpt.vsp.module.payment.domain.models;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * JPA entity representing a refund request.
 */
@Entity
@Table(name = "refund_requests", indexes = {
        @Index(name = "idx_refund_tx", columnList = "transaction_id"),
        @Index(name = "idx_refund_status", columnList = "status, requested_at")
})
public class RefundRequestEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "transaction_id", nullable = false)
    private PaymentTransactionEntity transaction;

    @Column(nullable = false)
    private Long amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private RefundReason reason;

    @Column(name = "reason_detail", columnDefinition = "TEXT")
    private String reasonDetail;

    @Column(name = "provider_refund_ref")
    private String providerRefundRef;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private RefundStatus status = RefundStatus.PENDING;

    @Column(name = "idempotency_key", nullable = false)
    private String idempotencyKey;

    @Column(name = "requested_at", nullable = false)
    private OffsetDateTime requestedAt;

    @Column(name = "processed_at")
    private OffsetDateTime processedAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Default constructor for JPA
    protected RefundRequestEntity() {
    }

    public RefundRequestEntity(PaymentTransactionEntity transaction, Long amount,
                                RefundReason reason, String reasonDetail, String idempotencyKey) {
        this.transaction = transaction;
        this.amount = amount;
        this.reason = reason;
        this.reasonDetail = reasonDetail;
        this.idempotencyKey = idempotencyKey;
        this.status = RefundStatus.PENDING;
        this.requestedAt = OffsetDateTime.now();
        this.createdAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    public void succeed(String providerRefundRef) {
        this.status = RefundStatus.SUCCEEDED;
        this.providerRefundRef = providerRefundRef;
        this.processedAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    public void fail() {
        this.status = RefundStatus.FAILED;
        this.processedAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    // Getters
    public UUID getId() { return id; }
    public PaymentTransactionEntity getTransaction() { return transaction; }
    public Long getAmount() { return amount; }
    public RefundReason getReason() { return reason; }
    public String getReasonDetail() { return reasonDetail; }
    public String getProviderRefundRef() { return providerRefundRef; }
    public RefundStatus getStatus() { return status; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public OffsetDateTime getRequestedAt() { return requestedAt; }
    public OffsetDateTime getProcessedAt() { return processedAt; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}
