package vnpt.vsp.module.payment;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;
import vnpt.vsp.module.payment.domain.services.PaymentAuditService;
import vnpt.vsp.module.payment.domain.services.ReconciliationService;
import vnpt.vsp.module.payment.domain.services.ReconciliationService.Discrepancy;
import vnpt.vsp.module.payment.domain.services.ReconciliationService.ReconciliationReport;
import vnpt.vsp.module.payment.infrastructure.provider.PaymentProviderAdapter;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for ReconciliationService.
 *
 * Tests:
 * - Clean reconciliation with no discrepancies
 * - Discrepancy detected when platform is PENDING but provider shows FAILED
 * - Discrepancy detected when platform is SUCCEEDED but provider shows FAILED
 * - No discrepancy when platform is SUCCEEDED and provider shows SUCCEEDED
 * - Skips transactions with no provider reference
 * - Skips PENDING transactions where provider still shows pending/succeeded
 *
 * Per Story 12.3 S6: Automated Tests — ReconciliationServiceTest.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ReconciliationServiceTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private PaymentProviderAdapter provider;

    @Mock
    private PaymentAuditService auditService;

    private ReconciliationService reconciliationService;

    private static final String PROVIDER_REF_PENDING_FAILED = "pi_pending_failed";
    private static final String PROVIDER_REF_SUCCEEDED_PROVIDER_FAILED = "pi_succeeded_prov_failed";
    private static final String PROVIDER_REF_PENDING_PROVIDER_SUCCEEDED = "pi_pending_prov_succeeded";
    private static final String PROVIDER_REF_NO_DISCREPANCY = "pi_no_discrepancy";

    @BeforeEach
    void setUp() {
        reconciliationService = new ReconciliationService(paymentRepository, provider, auditService);
    }

    // ─── Clean reconciliation ───────────────────────────────────────────────────

    @Test
    void runReconciliation_noTransactions_returnsCleanReport() {
        // Given: no transactions in lookback window
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of());

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then
        assertEquals("clean", report.status());
        assertEquals(0, report.checkedTransactions());
        assertTrue(report.discrepancies().isEmpty());
    }

    @Test
    void runReconciliation_allMatching_returnsCleanReport() {
        // Given: one SUCCEEDED transaction where provider also shows succeeded
        doReturn("succeeded").when(provider).getTransactionState(PROVIDER_REF_NO_DISCREPANCY);
        var tx = createTransaction(PaymentState.SUCCEEDED, PROVIDER_REF_NO_DISCREPANCY);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then
        assertEquals("clean", report.status());
        assertEquals(1, report.checkedTransactions());
        assertTrue(report.discrepancies().isEmpty());
    }

    // ─── Discrepancy: platform PENDING, provider FAILED ─────────────────────────

    @Test
    void runReconciliation_platformPendingProviderFailed_detectsDiscrepancy() {
        // Given: PENDING transaction but provider shows failed
        doReturn("failed").when(provider).getTransactionState(PROVIDER_REF_PENDING_FAILED);
        var tx = createTransaction(PaymentState.PENDING, PROVIDER_REF_PENDING_FAILED);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then
        assertEquals("discrepancies_found", report.status());
        assertEquals(1, report.checkedTransactions());
        assertEquals(1, report.discrepancies().size());

        Discrepancy d = report.discrepancies().get(0);
        assertEquals("PENDING", d.platformState());
        assertEquals("failed", d.providerState());
    }

    @Test
    void runReconciliation_platformPendingProviderFailed_logsDiscrepancy() {
        // Given
        doReturn("failed").when(provider).getTransactionState(PROVIDER_REF_PENDING_FAILED);
        var tx = createTransaction(PaymentState.PENDING, PROVIDER_REF_PENDING_FAILED);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        reconciliationService.runReconciliation();

        // Then: audit service logs the discrepancy
        verify(auditService).logReconciliationDiscrepancy(
                eq(tx), eq("PENDING"), eq("failed"), eq("SYSTEM")
        );
    }

    // ─── Discrepancy: platform SUCCEEDED, provider FAILED ───────────────────────

    @Test
    void runReconciliation_platformSucceededProviderFailed_detectsDiscrepancy() {
        // Given: SUCCEEDED transaction but provider shows failed
        doReturn("failed").when(provider).getTransactionState(PROVIDER_REF_SUCCEEDED_PROVIDER_FAILED);
        var tx = createTransaction(PaymentState.SUCCEEDED, PROVIDER_REF_SUCCEEDED_PROVIDER_FAILED);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then
        assertEquals("discrepancies_found", report.status());
        assertEquals(1, report.discrepancies().size());

        Discrepancy d = report.discrepancies().get(0);
        assertEquals("SUCCEEDED", d.platformState());
        assertEquals("failed", d.providerState());
    }

    // ─── Discrepancy: platform REFUNDED, provider FAILED ─────────────────────────

    @Test
    void runReconciliation_platformRefundedProviderFailed_detectsDiscrepancy() {
        // Given: REFUNDED transaction but provider shows failed
        String ref = "pi_refunded_prov_failed";
        doReturn("failed").when(provider).getTransactionState(ref);
        var tx = createTransaction(PaymentState.REFUNDED, ref);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then
        assertEquals("discrepancies_found", report.status());
        assertEquals(1, report.discrepancies().size());
    }

    // ─── No discrepancy paths ──────────────────────────────────────────────────

    @Test
    void runReconciliation_platformPendingProviderStillPending_noDiscrepancy() {
        // Given: PENDING transaction and provider still shows pending
        String ref = "pi_still_pending";
        doReturn("pending").when(provider).getTransactionState(ref);
        var tx = createTransaction(PaymentState.PENDING, ref);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then: no discrepancy (pending → pending is expected)
        assertEquals("clean", report.status());
        assertTrue(report.discrepancies().isEmpty());
    }

    @Test
    void runReconciliation_platformPendingProviderSucceeded_noDiscrepancy() {
        // Given: PENDING transaction but provider shows succeeded (webhook already processed)
        doReturn("succeeded").when(provider).getTransactionState(PROVIDER_REF_PENDING_PROVIDER_SUCCEEDED);
        var tx = createTransaction(PaymentState.PENDING, PROVIDER_REF_PENDING_PROVIDER_SUCCEEDED);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When: "succeeded" for PENDING is not flagged as discrepancy
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then: no discrepancy — PENDING with provider=succeeded means webhook may not have fired yet
        assertEquals("clean", report.status());
    }

    @Test
    void runReconciliation_noProviderReference_skipsTransaction() {
        // Given: transaction with no provider reference
        var tx = createTransaction(PaymentState.PENDING, null);
        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then: no discrepancy (skipped because no provider ref)
        assertEquals("clean", report.status());
        assertTrue(report.discrepancies().isEmpty());
        // Provider should NOT be called for null provider reference
        verify(provider, never()).getTransactionState(anyString());
    }

    // ─── Multiple transactions ─────────────────────────────────────────────────

    @Test
    void runReconciliation_multipleTransactionsWithMixedResults_reportsCorrectDiscrepancies() {
        // Given: 3 transactions:
        // 1. SUCCEEDED with provider=succeeded (no discrepancy)
        // 2. PENDING with provider=failed (discrepancy)
        // 3. SUCCEEDED with provider=failed (discrepancy)
        String ref1 = "pi_1_ok";
        String ref2 = "pi_2_disc";
        String ref3 = "pi_3_disc";

        doReturn("succeeded").when(provider).getTransactionState(ref1);
        doReturn("failed").when(provider).getTransactionState(ref2);
        doReturn("failed").when(provider).getTransactionState(ref3);

        var tx1 = createTransaction(PaymentState.SUCCEEDED, ref1);
        var tx2 = createTransaction(PaymentState.PENDING, ref2);
        var tx3 = createTransaction(PaymentState.SUCCEEDED, ref3);

        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx1, tx2, tx3));

        // When
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then: 2 discrepancies detected
        assertEquals("discrepancies_found", report.status());
        assertEquals(3, report.checkedTransactions());
        assertEquals(2, report.discrepancies().size());
    }

    @Test
    void runReconciliation_providerThrowsException_continuesWithoutThrowing() {
        // Given: one normal tx and one where provider throws
        String ref1 = "pi_1_ok";
        String ref2 = "pi_error";

        doReturn("succeeded").when(provider).getTransactionState(ref1);
        doThrow(new RuntimeException("Provider API error"))
                .when(provider).getTransactionState(ref2);

        var tx1 = createTransaction(PaymentState.SUCCEEDED, ref1);
        var tx2 = createTransaction(PaymentState.PENDING, ref2);

        when(paymentRepository.findAllUpdatedSince(any())).thenReturn(List.of(tx1, tx2));

        // When: should NOT throw — exception is caught internally
        ReconciliationReport report = reconciliationService.runReconciliation();

        // Then: first tx was checked (no discrepancy), second was skipped due to exception
        assertEquals(2, report.checkedTransactions());
        assertEquals("clean", report.status()); // no discrepancies recorded due to exception
    }

    // ─── Helper ─────────────────────────────────────────────────────────────────

    private PaymentTransactionEntity createTransaction(PaymentState state, String providerReference) {
        var tx = new PaymentTransactionEntity("recon_idem_" + System.nanoTime(), 50000L, "VND");
        tx.setState(state);
        tx.setProviderReference(providerReference);
        tx.setRefundedAmount(0L);
        // Simulate JPA @GeneratedValue setting the ID
        setTxId(tx, UUID.randomUUID());
        return tx;
    }

    private void setTxId(PaymentTransactionEntity tx, UUID id) {
        try {
            var field = PaymentTransactionEntity.class.getDeclaredField("id");
            field.setAccessible(true);
            field.set(tx, id);
        } catch (Exception e) {
            throw new RuntimeException("Failed to set transaction ID", e);
        }
    }
}
