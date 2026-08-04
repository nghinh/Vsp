package vnpt.vsp.module.payment.domain.services;

import vnpt.vsp.module.payment.domain.models.*;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;
import vnpt.vsp.module.payment.infrastructure.provider.PaymentProviderAdapter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Daily reconciliation service.
 *
 * Compares platform payment state with provider state and flags discrepancies.
 * Runs as a scheduled job daily, or can be triggered manually via the admin API.
 */
@Service
public class ReconciliationService {

    private static final Logger log = LoggerFactory.getLogger(ReconciliationService.class);
    private static final Duration LOOKBACK_WINDOW = Duration.ofDays(7);

    private final PaymentRepository paymentRepository;
    private final PaymentProviderAdapter provider;
    private final PaymentAuditService auditService;

    public ReconciliationService(PaymentRepository paymentRepository,
                                  PaymentProviderAdapter provider,
                                  PaymentAuditService auditService) {
        this.paymentRepository = paymentRepository;
        this.provider = provider;
        this.auditService = auditService;
    }

    /**
     * Runs reconciliation for all transactions updated in the lookback window.
     *
     * @return reconciliation report
     */
    public ReconciliationReport runReconciliation() {
        OffsetDateTime since = OffsetDateTime.now().minus(LOOKBACK_WINDOW);
        var transactions = paymentRepository.findAllUpdatedSince(since);

        List<Discrepancy> discrepancies = new ArrayList<>();
        int checked = 0;

        for (var tx : transactions) {
            checked++;
            try {
                var discrepancy = checkTransaction(tx);
                if (discrepancy != null) {
                    discrepancies.add(discrepancy);
                }
            } catch (Exception e) {
                log.error("Error checking transaction {}: {}", tx.getId(), e.getMessage(), e);
            }
        }

        String status = discrepancies.isEmpty() ? "clean" : "discrepancies_found";
        log.info("Reconciliation complete: checked={}, discrepancies={}, status={}",
                checked, discrepancies.size(), status);

        return new ReconciliationReport(
                OffsetDateTime.now().toString(),
                checked,
                discrepancies,
                status
        );
    }

    /**
     * Checks a single transaction against provider state.
     *
     * @return a discrepancy if found, null otherwise
     */
    private Discrepancy checkTransaction(PaymentTransactionEntity tx) {
        if (tx.getProviderReference() == null) {
            return null; // No provider ref yet — skip
        }

        if (tx.getState() == PaymentState.PENDING) {
            // Check if provider has moved on
            String providerState = provider.getTransactionState(tx.getProviderReference());
            if (!"pending".equalsIgnoreCase(providerState) && !"succeeded".equalsIgnoreCase(providerState)) {
                // Provider shows failure — platform is still pending
                logDiscrepancy(tx, "PENDING", providerState);
                return new Discrepancy(
                        tx.getId().toString(),
                        "PENDING",
                        providerState,
                        tx.getAmount(),
                        tx.getCurrency(),
                        "pending_review",
                        null
                );
            }
        } else if (tx.getState() == PaymentState.SUCCEEDED || tx.getState() == PaymentState.REFUNDED) {
            // Provider might show different state
            String providerState = provider.getTransactionState(tx.getProviderReference());
            if ("failed".equalsIgnoreCase(providerState)) {
                logDiscrepancy(tx, tx.getState().name(), providerState);
                return new Discrepancy(
                        tx.getId().toString(),
                        tx.getState().name(),
                        providerState,
                        tx.getAmount(),
                        tx.getCurrency(),
                        "pending_review",
                        null
                );
            }
        }

        return null;
    }

    private void logDiscrepancy(PaymentTransactionEntity tx, String platformState, String providerState) {
        try {
            auditService.logReconciliationDiscrepancy(tx, platformState, providerState, "SYSTEM");
        } catch (Exception e) {
            log.error("Failed to log reconciliation discrepancy for tx {}", tx.getId(), e);
        }
        log.warn("Reconciliation discrepancy: txId={}, platformState={}, providerState={}",
                tx.getId(), platformState, providerState);
    }

    // ─── Report types ────────────────────────────────────────────────────────

    public record ReconciliationReport(
            String runAt,
            int checkedTransactions,
            List<Discrepancy> discrepancies,
            String status
    ) {}

    public record Discrepancy(
            String transactionId,
            String platformState,
            String providerState,
            Long amount,
            String currency,
            String resolution,
            String notes
    ) {}
}
