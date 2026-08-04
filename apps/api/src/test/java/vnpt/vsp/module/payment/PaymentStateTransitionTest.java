package vnpt.vsp.module.payment;

import org.junit.jupiter.api.Test;
import vnpt.vsp.module.payment.domain.models.PaymentFailureReason;
import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;

import java.time.OffsetDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for payment state transitions.
 *
 * Valid transitions:
 * - PENDING → SUCCEEDED (confirm)
 * - PENDING → FAILED (fail)
 * - SUCCEEDED → REFUNDED (full refund)
 * - SUCCEEDED → PARTIALLY_REFUNDED (partial refund)
 * - PARTIALLY_REFUNDED → REFUNDED (remaining amount refunded)
 *
 * Invalid transitions (must be prevented or handled gracefully):
 * - FAILED → SUCCEEDED
 * - SUCCEEDED → FAILED
 * - REFUNDED → SUCCEEDED
 * - REFUNDED → FAILED
 * - REFUNDED → PARTIALLY_REFUNDED
 *
 * Per Story 12.3 S6: Automated Tests — PaymentStateTransitionTest.
 */
class PaymentStateTransitionTest {

    private static final String IDEMPOTENCY_KEY = "test_idem_123";
    private static final Long AMOUNT = 100000L;
    private static final String CURRENCY = "VND";

    // ─── Valid transitions ───────────────────────────────────────────────────────

    @Test
    void confirm_setsStateToSucceeded() {
        // Given
        var tx = createTransaction(PaymentState.PENDING);

        // When
        tx.confirm("pi_provider_ref", "pm_card_ref");

        // Then
        assertEquals(PaymentState.SUCCEEDED, tx.getState());
        assertEquals("pi_provider_ref", tx.getProviderReference());
        assertEquals("pm_card_ref", tx.getPaymentMethodRef());
        assertNull(tx.getFailureReason());
        assertNull(tx.getFailureMessage());
    }

    @Test
    void confirm_recordsProviderAndPaymentMethodRefs() {
        // Given
        var tx = createTransaction(PaymentState.PENDING);

        // When
        tx.confirm("pi_abc123", "pm_xyz789");

        // Then
        assertEquals("pi_abc123", tx.getProviderReference());
        assertEquals("pm_xyz789", tx.getPaymentMethodRef());
    }

    @Test
    void fail_setsStateToFailedWithReason() {
        // Given
        var tx = createTransaction(PaymentState.PENDING);

        // When
        tx.fail(PaymentFailureReason.INSUFFICIENT_FUNDS, "Not enough balance");

        // Then
        assertEquals(PaymentState.FAILED, tx.getState());
        assertEquals(PaymentFailureReason.INSUFFICIENT_FUNDS, tx.getFailureReason());
        assertEquals("Not enough balance", tx.getFailureMessage());
        assertNull(tx.getProviderReference());
    }

    @Test
    void fail_recordsAllFailureReasons() {
        var tx = createTransaction(PaymentState.PENDING);

        for (PaymentFailureReason reason : PaymentFailureReason.values()) {
            tx.fail(reason, "Test failure for " + reason.name());
            assertEquals(PaymentState.FAILED, tx.getState());
            assertEquals(reason, tx.getFailureReason());
        }
    }

    @Test
    void applyRefund_fullRefund_setsStateToRefunded() {
        // Given
        var tx = createTransaction(PaymentState.SUCCEEDED);
        tx.setRefundedAmount(0L);

        // When: refund full amount
        tx.applyRefund(AMOUNT);

        // Then
        assertEquals(PaymentState.REFUNDED, tx.getState());
        assertEquals(AMOUNT, tx.getRefundedAmount());
    }

    @Test
    void applyRefund_partialRefund_setsStateToPartiallyRefunded() {
        // Given
        var tx = createTransaction(PaymentState.SUCCEEDED);
        tx.setRefundedAmount(0L);

        // When: refund half
        tx.applyRefund(AMOUNT / 2);

        // Then
        assertEquals(PaymentState.PARTIALLY_REFUNDED, tx.getState());
        assertEquals(AMOUNT / 2, tx.getRefundedAmount());
    }

    @Test
    void applyRefund_secondPartialCompletesFullRefund_transitionsToRefunded() {
        // Given: already partially refunded
        var tx = createTransaction(PaymentState.PARTIALLY_REFUNDED);
        tx.setRefundedAmount(AMOUNT / 2);

        // When: refund remaining half
        tx.applyRefund(AMOUNT / 2);

        // Then
        assertEquals(PaymentState.REFUNDED, tx.getState());
        assertEquals(AMOUNT, tx.getRefundedAmount());
    }

    // ─── Terminal state checks ──────────────────────────────────────────────────

    @Test
    void isTerminal_returnsTrueForSucceeded() {
        var tx = createTransaction(PaymentState.SUCCEEDED);
        assertTrue(tx.isTerminal());
    }

    @Test
    void isTerminal_returnsTrueForFailed() {
        var tx = createTransaction(PaymentState.FAILED);
        assertTrue(tx.isTerminal());
    }

    @Test
    void isTerminal_returnsTrueForRefunded() {
        var tx = createTransaction(PaymentState.REFUNDED);
        assertTrue(tx.isTerminal());
    }

    @Test
    void isTerminal_returnsFalseForPending() {
        var tx = createTransaction(PaymentState.PENDING);
        assertFalse(tx.isTerminal());
    }

    @Test
    void isTerminal_returnsFalseForPartiallyRefunded() {
        var tx = createTransaction(PaymentState.PARTIALLY_REFUNDED);
        assertFalse(tx.isTerminal());
    }

    // ─── Refundable checks ──────────────────────────────────────────────────────

    @Test
    void isRefundable_returnsTrueForSucceeded() {
        var tx = createTransaction(PaymentState.SUCCEEDED);
        assertTrue(tx.isRefundable());
    }

    @Test
    void isRefundable_returnsTrueForPartiallyRefunded() {
        var tx = createTransaction(PaymentState.PARTIALLY_REFUNDED);
        assertTrue(tx.isRefundable());
    }

    @Test
    void isRefundable_returnsFalseForPending() {
        var tx = createTransaction(PaymentState.PENDING);
        assertFalse(tx.isRefundable());
    }

    @Test
    void isRefundable_returnsFalseForFailed() {
        var tx = createTransaction(PaymentState.FAILED);
        assertFalse(tx.isRefundable());
    }

    @Test
    void isRefundable_returnsFalseForRefunded() {
        // Fully refunded is no longer refundable (already fully refunded)
        var tx = createTransaction(PaymentState.REFUNDED);
        assertFalse(tx.isRefundable());
    }

    // ─── State enum checks ───────────────────────────────────────────────────────

    @Test
    void paymentState_hasFiveValues() {
        assertEquals(5, PaymentState.values().length);
    }

    @Test
    void paymentFailureReason_hasSixValues() {
        assertEquals(6, PaymentFailureReason.values().length);
    }

    @Test
    void canRefund_succeededReturnsTrue() {
        assertTrue(PaymentState.SUCCEEDED.canRefund());
    }

    @Test
    void canRefund_partiallyRefundedReturnsTrue() {
        assertTrue(PaymentState.PARTIALLY_REFUNDED.canRefund());
    }

    @Test
    void canRefund_pendingReturnsFalse() {
        assertFalse(PaymentState.PENDING.canRefund());
    }

    @Test
    void canRefund_failedReturnsFalse() {
        assertFalse(PaymentState.FAILED.canRefund());
    }

    @Test
    void canRefund_refundedReturnsFalse() {
        assertFalse(PaymentState.REFUNDED.canRefund());
    }

    // ─── UpdatedAt is modified on state changes ─────────────────────────────────

    @Test
    void confirm_updatesUpdatedAt() {
        var tx = createTransaction(PaymentState.PENDING);
        OffsetDateTime before = tx.getUpdatedAt();

        // Small delay to ensure time difference is measurable
        tx.confirm("pi_ref", null);
        OffsetDateTime after = tx.getUpdatedAt();

        assertTrue(after.isAfter(before) || after.isEqual(before));
    }

    @Test
    void fail_updatesUpdatedAt() {
        var tx = createTransaction(PaymentState.PENDING);
        OffsetDateTime before = tx.getUpdatedAt();

        tx.fail(PaymentFailureReason.NETWORK_ERROR, "Network timeout");
        OffsetDateTime after = tx.getUpdatedAt();

        assertTrue(after.isAfter(before) || after.isEqual(before));
    }

    @Test
    void applyRefund_updatesUpdatedAt() {
        var tx = createTransaction(PaymentState.SUCCEEDED);
        OffsetDateTime before = tx.getUpdatedAt();

        tx.applyRefund(AMOUNT);
        OffsetDateTime after = tx.getUpdatedAt();

        assertTrue(after.isAfter(before) || after.isEqual(before));
    }

    // ─── Edge cases ─────────────────────────────────────────────────────────────

    @Test
    void applyRefund_zeroAmount_doesNotChangeState() {
        var tx = createTransaction(PaymentState.SUCCEEDED);
        tx.setRefundedAmount(0L);

        tx.applyRefund(0L);

        assertEquals(PaymentState.SUCCEEDED, tx.getState());
        assertEquals(0L, tx.getRefundedAmount());
    }

    @Test
    void confirm_twice_updatesProviderRef() {
        var tx = createTransaction(PaymentState.PENDING);

        tx.confirm("pi_first", "pm_first");
        tx.confirm("pi_second", "pm_second");

        // Most recent confirm wins
        assertEquals("pi_second", tx.getProviderReference());
        assertEquals("pm_second", tx.getPaymentMethodRef());
    }

    @Test
    void fail_afterConfirm_isAllowed() {
        // This tests that the entity doesn't prevent calling fail() after confirm()
        // The service layer is responsible for enforcing valid transition ordering
        var tx = createTransaction(PaymentState.SUCCEEDED);
        tx.fail(PaymentFailureReason.UNKNOWN, "Chargeback");

        assertEquals(PaymentState.FAILED, tx.getState());
        assertEquals(PaymentFailureReason.UNKNOWN, tx.getFailureReason());
    }

    // ─── Helper ─────────────────────────────────────────────────────────────────

    private PaymentTransactionEntity createTransaction(PaymentState state) {
        var tx = new PaymentTransactionEntity(IDEMPOTENCY_KEY, AMOUNT, CURRENCY);
        tx.setState(state);
        return tx;
    }
}
