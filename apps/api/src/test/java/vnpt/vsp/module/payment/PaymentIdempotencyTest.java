package vnpt.vsp.module.payment;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;
import vnpt.vsp.module.payment.domain.repositories.RefundRepository;
import vnpt.vsp.module.payment.domain.services.PaymentAuditService;
import vnpt.vsp.module.payment.domain.services.PaymentService;
import vnpt.vsp.module.payment.infrastructure.idempotency.PaymentIdempotencyStore;
import vnpt.vsp.module.payment.infrastructure.provider.PaymentProviderAdapter;
import vnpt.vsp.module.payment.infrastructure.provider.PaymentProviderAdapter.CreateIntentResult;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for payment idempotency.
 *
 * Tests:
 * - Duplicate createPaymentIntent with same idempotency key returns same response
 * - Provider is NOT called for duplicate requests
 * - Payment is not stored twice for duplicate requests
 * - Different idempotency keys create separate transactions
 *
 * Per Story 12.3 S6: Automated Tests — PaymentIdempotencyTest.
 */
@ExtendWith(MockitoExtension.class)
class PaymentIdempotencyTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private RefundRepository refundRepository;

    @Mock
    private PaymentAuditService auditService;

    @Mock
    private PaymentProviderAdapter provider;

    @Mock
    private PaymentIdempotencyStore idempotencyStore;

    private PaymentService paymentService;

    // Shared test fixtures
    private static final String IDEMPOTENCY_KEY = "idem_12345";
    private static final Long AMOUNT = 50000L;
    private static final String CURRENCY = "VND";
    private static final String ACTOR = "test-user";

    @BeforeEach
    void setUp() {
        paymentService = new PaymentService(
                paymentRepository,
                refundRepository,
                auditService,
                provider,
                idempotencyStore
        );
    }

    // ─── Duplicate intent returns same response ─────────────────────────────────

    @Test
    void createPaymentIntent_sameIdempotencyKey_returnsSameTransaction() {
        // Given: an existing transaction with the same idempotency key
        var existingTx = new PaymentTransactionEntity(IDEMPOTENCY_KEY, AMOUNT, CURRENCY);
        // Use reflection to set the ID since it's normally generated on save
        setTxId(existingTx, UUID.randomUUID());
        existingTx.setState(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING);

        when(paymentRepository.findByIdempotencyKey(IDEMPOTENCY_KEY))
                .thenReturn(Optional.of(existingTx));

        // When: createPaymentIntent is called again with the same idempotency key
        var result = paymentService.createPaymentIntent(
                AMOUNT, CURRENCY, IDEMPOTENCY_KEY,
                null, null, ACTOR
        );

        // Then: returns the existing transaction
        assertEquals(existingTx.getId().toString(), result.transactionId());
        assertEquals(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING, result.state());
        assertEquals(AMOUNT, result.amount());
        assertEquals(CURRENCY, result.currency());
    }

    @Test
    void createPaymentIntent_sameIdempotencyKey_doesNotCallProvider() {
        // Given
        var existingTx = new PaymentTransactionEntity(IDEMPOTENCY_KEY, AMOUNT, CURRENCY);
        setTxId(existingTx, UUID.randomUUID());
        existingTx.setState(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING);

        when(paymentRepository.findByIdempotencyKey(IDEMPOTENCY_KEY))
                .thenReturn(Optional.of(existingTx));

        // When
        paymentService.createPaymentIntent(
                AMOUNT, CURRENCY, IDEMPOTENCY_KEY,
                null, null, ACTOR
        );

        // Then: provider was NOT called for duplicate
        verify(provider, never()).createIntent(anyLong(), anyString(), any());
    }

    @Test
    void createPaymentIntent_sameIdempotencyKey_doesNotSaveNewTransaction() {
        // Given
        var existingTx = new PaymentTransactionEntity(IDEMPOTENCY_KEY, AMOUNT, CURRENCY);
        setTxId(existingTx, UUID.randomUUID());
        existingTx.setState(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING);

        when(paymentRepository.findByIdempotencyKey(IDEMPOTENCY_KEY))
                .thenReturn(Optional.of(existingTx));

        // When
        paymentService.createPaymentIntent(
                AMOUNT, CURRENCY, IDEMPOTENCY_KEY,
                null, null, ACTOR
        );

        // Then: paymentRepository.save was NOT called (no new transaction)
        verify(paymentRepository, never()).save(any(PaymentTransactionEntity.class));
    }

    @Test
    void createPaymentIntent_sameIdempotencyKey_doesNotAuditAgain() {
        // Given
        var existingTx = new PaymentTransactionEntity(IDEMPOTENCY_KEY, AMOUNT, CURRENCY);
        setTxId(existingTx, UUID.randomUUID());
        existingTx.setState(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING);

        when(paymentRepository.findByIdempotencyKey(IDEMPOTENCY_KEY))
                .thenReturn(Optional.of(existingTx));

        // When
        paymentService.createPaymentIntent(
                AMOUNT, CURRENCY, IDEMPOTENCY_KEY,
                null, null, ACTOR
        );

        // Then: no audit log entry created for duplicate
        verify(auditService, never()).logIntentCreated(any(), anyString(), anyString());
    }

    // ─── New intent creates transaction and calls provider ───────────────────────

    @Test
    void createPaymentIntent_newIdempotencyKey_createsTransactionAndCallsProvider() {
        // Given: no existing transaction
        when(paymentRepository.findByIdempotencyKey(IDEMPOTENCY_KEY))
                .thenReturn(Optional.empty());
        when(paymentRepository.save(any(PaymentTransactionEntity.class)))
                .thenAnswer(inv -> {
                    PaymentTransactionEntity tx = inv.getArgument(0);
                    if (tx.getId() == null) {
                        setTxId(tx, UUID.randomUUID());
                    }
                    return tx;
                });
        when(provider.createIntent(AMOUNT, CURRENCY, null))
                .thenReturn(new CreateIntentResult("pi_stub_123", "cs_stub_456", null));

        // When
        var result = paymentService.createPaymentIntent(
                AMOUNT, CURRENCY, IDEMPOTENCY_KEY,
                null, null, ACTOR
        );

        // Then: transaction created with PENDING state
        assertNotNull(result.transactionId());
        assertEquals(AMOUNT, result.amount());
        assertEquals(CURRENCY, result.currency());
        assertEquals(vnpt.vsp.module.payment.domain.models.PaymentState.PENDING, result.state());
        assertEquals("pi_stub_123", result.providerReference());
        assertEquals("cs_stub_456", result.clientSecret());

        // And: provider was called
        verify(provider).createIntent(AMOUNT, CURRENCY, null);

        // And: transaction was saved twice (create + update with provider ref)
        verify(paymentRepository, times(2)).save(any(PaymentTransactionEntity.class));

        // And: audit logged
        verify(auditService).logIntentCreated(any(), eq(IDEMPOTENCY_KEY), eq(ACTOR));
    }

    // ─── Different idempotency keys create separate transactions ─────────────────

    @Test
    void createPaymentIntent_differentIdempotencyKeys_createsSeparateTransactions() {
        // Given
        String key1 = "idem_key_1";
        String key2 = "idem_key_2";

        when(paymentRepository.findByIdempotencyKey(key1)).thenReturn(Optional.empty());
        when(paymentRepository.findByIdempotencyKey(key2)).thenReturn(Optional.empty());

        when(paymentRepository.save(any(PaymentTransactionEntity.class)))
                .thenAnswer(inv -> {
                    PaymentTransactionEntity tx = inv.getArgument(0);
                    if (tx.getId() == null) {
                        setTxId(tx, UUID.randomUUID());
                    }
                    return tx;
                });

        when(provider.createIntent(eq(AMOUNT), eq(CURRENCY), any()))
                .thenReturn(new CreateIntentResult("pi_1", "cs_1", null))
                .thenReturn(new CreateIntentResult("pi_2", "cs_2", null));

        // When: two different idempotency keys
        var result1 = paymentService.createPaymentIntent(AMOUNT, CURRENCY, key1, null, null, ACTOR);
        var result2 = paymentService.createPaymentIntent(AMOUNT, CURRENCY, key2, null, null, ACTOR);

        // Then: two different transactions created
        assertNotEquals(result1.transactionId(), result2.transactionId());
        verify(paymentRepository, times(4)).save(any(PaymentTransactionEntity.class)); // 2 saves each × 2 calls
    }

    // ─── Helper ────────────────────────────────────────────────────────────────

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
