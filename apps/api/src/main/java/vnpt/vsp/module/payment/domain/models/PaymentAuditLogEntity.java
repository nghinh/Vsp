package vnpt.vsp.module.payment.domain.models;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * JPA entity representing a payment audit log entry.
 */
@Entity
@Table(name = "payment_audit_log", indexes = {
        @Index(name = "idx_payment_audit_tx", columnList = "transaction_id, timestamp"),
        @Index(name = "idx_payment_audit_actor", columnList = "actor, timestamp"),
        @Index(name = "idx_payment_audit_action", columnList = "action, timestamp")
})
public class PaymentAuditLogEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "transaction_id", nullable = false)
    private PaymentTransactionEntity transaction;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private PaymentAuditAction action;

    @Column(nullable = false)
    private String actor;

    @Enumerated(EnumType.STRING)
    @Column(name = "previous_state", length = 30)
    private PaymentState previousState;

    @Enumerated(EnumType.STRING)
    @Column(name = "new_state", length = 30)
    private PaymentState newState;

    @Column(name = "metadata_json", columnDefinition = "TEXT")
    private String metadataJson;

    @Column(name = "correlation_id", length = 100)
    private String correlationId;

    @Column(nullable = false)
    private OffsetDateTime timestamp;

    // Default constructor for JPA
    protected PaymentAuditLogEntity() {
    }

    public PaymentAuditLogEntity(PaymentTransactionEntity transaction, PaymentAuditAction action,
                                  String actor, PaymentState previousState, PaymentState newState,
                                  String metadataJson, String correlationId) {
        this.transaction = transaction;
        this.action = action;
        this.actor = actor;
        this.previousState = previousState;
        this.newState = newState;
        this.metadataJson = metadataJson;
        this.correlationId = correlationId;
        this.timestamp = OffsetDateTime.now();
    }

    // Getters
    public UUID getId() { return id; }
    public PaymentTransactionEntity getTransaction() { return transaction; }
    public PaymentAuditAction getAction() { return action; }
    public String getActor() { return actor; }
    public PaymentState getPreviousState() { return previousState; }
    public PaymentState getNewState() { return newState; }
    public String getMetadataJson() { return metadataJson; }
    public String getCorrelationId() { return correlationId; }
    public OffsetDateTime getTimestamp() { return timestamp; }
}
