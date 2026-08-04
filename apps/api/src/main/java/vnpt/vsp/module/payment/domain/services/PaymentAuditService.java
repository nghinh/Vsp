package vnpt.vsp.module.payment.domain.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.payment.domain.models.*;
import vnpt.vsp.module.payment.domain.repositories.PaymentAuditRepository;

import java.util.List;
import java.util.UUID;

/**
 * Service for writing and reading payment audit logs.
 *
 * All state transitions on PaymentTransaction are logged here.
 * Audit entries are append-only — no updates or deletes.
 */
@Service
public class PaymentAuditService {

    private static final Logger log = LoggerFactory.getLogger(PaymentAuditService.class);

    private final PaymentAuditRepository auditRepository;

    public PaymentAuditService(PaymentAuditRepository auditRepository) {
        this.auditRepository = auditRepository;
    }

    /**
     * Logs an INTENT_CREATED event.
     */
    @Async
    public void logIntentCreated(PaymentTransactionEntity transaction, String idempotencyKey, String actor) {
        logEvent(transaction, PaymentAuditAction.INTENT_CREATED, actor, null, transaction.getState(),
                """
                {"idempotencyKey": "%s", "amount": %d, "currency": "%s"}
                """.formatted(idempotencyKey, transaction.getAmount(), transaction.getCurrency()));
    }

    /**
     * Logs a CONFIRMATION_SUCCEEDED event.
     */
    @Async
    public void logConfirmationSucceeded(PaymentTransactionEntity transaction, String actor) {
        logEvent(transaction, PaymentAuditAction.CONFIRMATION_SUCCEEDED, actor,
                PaymentState.PENDING, PaymentState.SUCCEEDED,
                """
                {"providerReference": "%s"}
                """.formatted(
                        transaction.getProviderReference() != null ? transaction.getProviderReference() : ""));
    }

    /**
     * Logs a CONFIRMATION_FAILED event.
     */
    @Async
    public void logConfirmationFailed(PaymentTransactionEntity transaction, PaymentFailureReason reason,
                                       String message, String actor) {
        logEvent(transaction, PaymentAuditAction.CONFIRMATION_FAILED, actor,
                PaymentState.PENDING, PaymentState.FAILED,
                """
                {"failureReason": "%s", "failureMessage": "%s"}
                """.formatted(reason != null ? reason.name() : "null",
                        message != null ? message.replace("\"", "\\\"") : ""));
    }

    /**
     * Logs a REFUND_REQUESTED event.
     */
    @Async
    public void logRefundRequested(PaymentTransactionEntity transaction, RefundRequestEntity refund,
                                    String actor) {
        logEvent(transaction, PaymentAuditAction.REFUND_REQUESTED, actor,
                transaction.getState(), transaction.getState(),
                """
                {"refundId": "%s", "refundAmount": %d, "reason": "%s"}
                """.formatted(refund.getId(), refund.getAmount(),
                        refund.getReason() != null ? refund.getReason().name() : ""));
    }

    /**
     * Logs a REFUND_SUCCEEDED event.
     */
    @Async
    public void logRefundSucceeded(PaymentTransactionEntity transaction, RefundRequestEntity refund,
                                   PaymentState newState, String actor) {
        logEvent(transaction, PaymentAuditAction.REFUND_SUCCEEDED, actor,
                transaction.getState(), newState,
                """
                {"refundId": "%s", "refundAmount": %d, "providerRefundRef": "%s"}
                """.formatted(refund.getId(), refund.getAmount(),
                        refund.getProviderRefundRef() != null ? refund.getProviderRefundRef() : ""));
    }

    /**
     * Logs a RECONCILIATION_DISCREPANCY event.
     */
    @Async
    public void logReconciliationDiscrepancy(PaymentTransactionEntity transaction,
                                               String platformState, String providerState, String actor) {
        logEvent(transaction, PaymentAuditAction.RECONCILIATION_DISCREPANCY, actor,
                transaction.getState(), transaction.getState(),
                """
                {"platformState": "%s", "providerState": "%s"}
                """.formatted(platformState, providerState));
    }

    /**
     * Logs a REFUND_FAILED event.
     */
    @Async
    public void logRefundFailed(PaymentTransactionEntity transaction, RefundRequestEntity refund,
                               String actor, String failureMessage) {
        logEvent(transaction, PaymentAuditAction.REFUND_FAILED, actor,
                transaction.getState(), transaction.getState(),
                """
                {"refundId": "%s", "failureMessage": "%s"}
                """.formatted(refund.getId(),
                        failureMessage != null ? failureMessage.replace("\"", "\\\"") : ""));
    }

    /**
     * Gets all audit entries for a transaction.
     */
    public List<PaymentAuditLogEntity> getAuditTrail(UUID transactionId) {
        return auditRepository.findByTransactionId(transactionId);
    }

    private void logEvent(PaymentTransactionEntity transaction, PaymentAuditAction action,
                           String actor, PaymentState previousState, PaymentState newState,
                           String metadataJson) {
        try {
            var entry = new PaymentAuditLogEntity(
                    transaction, action, actor, previousState, newState, metadataJson,
                    org.slf4j.MDC.get("correlationId")
            );
            auditRepository.save(entry);
            log.debug("Audit logged: action={}, transactionId={}, actor={}",
                    action, transaction.getId(), actor);
        } catch (Exception e) {
            log.error("Failed to write payment audit log: action={}, transactionId={}",
                    action, transaction.getId(), e);
        }
    }
}
