package vnpt.vsp.module.payment;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.booking.BookingService;
import vnpt.vsp.module.payment.domain.models.PaymentBookingLinkEntity;
import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentBookingLinkRepository;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;
import vnpt.vsp.module.payment.domain.services.BookingPaymentLinker;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for BookingPaymentLinker.
 *
 * Tests:
 * - createLink creates a PaymentBookingLinkEntity linking booking to payment
 * - createLink is idempotent — duplicate calls return existing link
 * - recordPaymentConfirmation updates link and booking status
 * - recordPaymentConfirmation skips gracefully when link not found
 * - recordPaymentConfirmation continues even if booking update fails
 * - getLinkByBookingId returns correct link
 * - getLinkByPaymentTransactionId returns correct link
 * - isPaymentConfirmed returns true when confirmed, false otherwise
 *
 * Per Story 12.3 S4: Booking Integration.
 * Per Story 12.3 S6: Automated Tests — BookingPaymentLinkerTest.
 */
@ExtendWith(MockitoExtension.class)
class BookingPaymentLinkerTest {

    @Mock
    private PaymentBookingLinkRepository linkRepository;

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private BookingService bookingService;

    private BookingPaymentLinker linker;

    private static final String BOOKING_ID = "booking-uuid-123";
    private static final UUID TX_ID = UUID.fromString("11111111-1111-1111-1111-111111111111");

    @BeforeEach
    void setUp() {
        linker = new BookingPaymentLinker(linkRepository, paymentRepository, bookingService);
    }

    // ─── createLink ────────────────────────────────────────────────────────────

    @Test
    void createLink_createsNewLinkBetweenBookingAndTransaction() {
        // Given: no existing link
        when(linkRepository.findByBookingIdAndPaymentTransactionId(BOOKING_ID, TX_ID))
                .thenReturn(Optional.empty());
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> {
                    var link = inv.getArgument(0);
                    // Simulate JPA setting the ID
                    return link;
                });

        // When
        PaymentBookingLinkEntity result = linker.createLink(BOOKING_ID, TX_ID);

        // Then
        assertNotNull(result);
        assertEquals(BOOKING_ID, result.getBookingId());
        assertEquals(TX_ID, result.getPaymentTransactionId());
        assertFalse(result.isPaymentConfirmed());
        assertNull(result.getConfirmedState());

        verify(linkRepository).save(any(PaymentBookingLinkEntity.class));
    }

    @Test
    void createLink_idempotent_returnsExistingLink() {
        // Given: existing link
        var existingLink = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByBookingIdAndPaymentTransactionId(BOOKING_ID, TX_ID))
                .thenReturn(Optional.of(existingLink));

        // When
        PaymentBookingLinkEntity result = linker.createLink(BOOKING_ID, TX_ID);

        // Then: returns existing link, no new save
        assertSame(existingLink, result);
        verify(linkRepository, never()).save(any());
    }

    @Test
    void createLink_storesPaymentConfirmedAsFalse() {
        // Given
        when(linkRepository.findByBookingIdAndPaymentTransactionId(BOOKING_ID, TX_ID))
                .thenReturn(Optional.empty());
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        // When
        PaymentBookingLinkEntity result = linker.createLink(BOOKING_ID, TX_ID);

        // Then: initial state is NOT confirmed
        assertFalse(result.isPaymentConfirmed());
    }

    // ─── recordPaymentConfirmation ─────────────────────────────────────────────

    @Test
    void recordPaymentConfirmation_updatesLinkAndBookingStatus() {
        // Given: existing unconfirmed link
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.of(link));
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        // When
        Optional<PaymentBookingLinkEntity> result = linker.recordPaymentConfirmation(
                TX_ID, PaymentState.SUCCEEDED
        );

        // Then
        assertTrue(result.isPresent());
        assertTrue(result.get().isPaymentConfirmed());
        assertEquals(PaymentState.SUCCEEDED, result.get().getConfirmedState());
        assertNotNull(result.get().getConfirmedAt());

        // And: booking status is updated to CONFIRMED
        verify(bookingService).updateBookingStatus(BOOKING_ID, "CONFIRMED");
    }

    @Test
    void recordPaymentConfirmation_returnsEmptyWhenNoLinkFound() {
        // Given: no link for this transaction
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.empty());

        // When
        Optional<PaymentBookingLinkEntity> result = linker.recordPaymentConfirmation(
                TX_ID, PaymentState.SUCCEEDED
        );

        // Then
        assertTrue(result.isEmpty());
        verify(linkRepository, never()).save(any());
        verify(bookingService, never()).updateBookingStatus(anyString(), anyString());
    }

    @Test
    void recordPaymentConfirmation_continuesWhenBookingUpdateFails() {
        // Given: existing link, but bookingService throws
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.of(link));
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        doThrow(new RuntimeException("Booking service unavailable"))
                .when(bookingService).updateBookingStatus(BOOKING_ID, "CONFIRMED");

        // When: should NOT throw — booking failure should not roll back link update
        Optional<PaymentBookingLinkEntity> result = linker.recordPaymentConfirmation(
                TX_ID, PaymentState.SUCCEEDED
        );

        // Then: link is still updated
        assertTrue(result.isPresent());
        assertTrue(result.get().isPaymentConfirmed());
        assertEquals(PaymentState.SUCCEEDED, result.get().getConfirmedState());

        // And: the exception was caught and logged (method didn't throw)
        verify(bookingService).updateBookingStatus(BOOKING_ID, "CONFIRMED");
    }

    @Test
    void recordPaymentConfirmation_updatesConfirmedState() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.of(link));
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        // When
        linker.recordPaymentConfirmation(TX_ID, PaymentState.SUCCEEDED);

        // Then
        assertEquals(PaymentState.SUCCEEDED, link.getConfirmedState());
    }

    @Test
    void recordPaymentConfirmation_recordsConfirmedAtTimestamp() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.of(link));
        when(linkRepository.save(any(PaymentBookingLinkEntity.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        // When
        Optional<PaymentBookingLinkEntity> result = linker.recordPaymentConfirmation(
                TX_ID, PaymentState.SUCCEEDED
        );

        // Then
        assertNotNull(result.get().getConfirmedAt());
    }

    // ─── getLinkByBookingId ───────────────────────────────────────────────────

    @Test
    void getLinkByBookingId_returnsLinkWhenExists() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByBookingId(BOOKING_ID))
                .thenReturn(Optional.of(link));

        // When
        Optional<PaymentBookingLinkEntity> result = linker.getLinkByBookingId(BOOKING_ID);

        // Then
        assertTrue(result.isPresent());
        assertEquals(BOOKING_ID, result.get().getBookingId());
    }

    @Test
    void getLinkByBookingId_returnsEmptyWhenNotFound() {
        // Given
        when(linkRepository.findByBookingId(BOOKING_ID))
                .thenReturn(Optional.empty());

        // When
        Optional<PaymentBookingLinkEntity> result = linker.getLinkByBookingId(BOOKING_ID);

        // Then
        assertTrue(result.isEmpty());
    }

    // ─── getLinkByPaymentTransactionId ──────────────────────────────────────────

    @Test
    void getLinkByPaymentTransactionId_returnsLinkWhenExists() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        when(linkRepository.findByPaymentTransactionId(TX_ID))
                .thenReturn(Optional.of(link));

        // When
        Optional<PaymentBookingLinkEntity> result = linker.getLinkByPaymentTransactionId(TX_ID);

        // Then
        assertTrue(result.isPresent());
        assertEquals(TX_ID, result.get().getPaymentTransactionId());
    }

    // ─── isPaymentConfirmed ─────────────────────────────────────────────────────

    @Test
    void isPaymentConfirmed_returnsTrueWhenLinkConfirmed() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        link.recordPaymentConfirmed(PaymentState.SUCCEEDED);
        when(linkRepository.findByBookingId(BOOKING_ID))
                .thenReturn(Optional.of(link));

        // When
        boolean result = linker.isPaymentConfirmed(BOOKING_ID);

        // Then
        assertTrue(result);
    }

    @Test
    void isPaymentConfirmed_returnsFalseWhenLinkNotConfirmed() {
        // Given
        var link = new PaymentBookingLinkEntity(BOOKING_ID, TX_ID);
        // not calling recordPaymentConfirmed — stays false
        when(linkRepository.findByBookingId(BOOKING_ID))
                .thenReturn(Optional.of(link));

        // When
        boolean result = linker.isPaymentConfirmed(BOOKING_ID);

        // Then
        assertFalse(result);
    }

    @Test
    void isPaymentConfirmed_returnsFalseWhenNoLink() {
        // Given
        when(linkRepository.findByBookingId(BOOKING_ID))
                .thenReturn(Optional.empty());

        // When
        boolean result = linker.isPaymentConfirmed(BOOKING_ID);

        // Then: no link means not confirmed
        assertFalse(result);
    }
}
