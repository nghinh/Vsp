package vnpt.vsp.module.payment.domain.services;

import vnpt.vsp.module.booking.BookingService;
import vnpt.vsp.module.payment.domain.models.PaymentBookingLinkEntity;
import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentBookingLinkRepository;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

/**
 * Links a Booking (from the booking module) to a PaymentTransaction and
 * records payment confirmation on the booking after a successful payment.
 *
 * <p>Integration flow:
 * <ol>
 *   <li>{@link #createLink(String, UUID)} — called when a booking requires payment;
 *       stores the booking-to-payment mapping.</li>
 *   <li>After payment succeeds, {@link #recordPaymentConfirmation(UUID)} is called;
 *       records the confirmed state on the link and updates the booking status.</li>
 * </ol>
 *
 * <p>Per Story 12.3 S4: Booking Integration.
 * Boundary rule: This service uses BookingService interface (not its implementation)
 * to update booking status — no module may directly @Autowired an Impl from another module.
 */
@Service
public class BookingPaymentLinker {

    private static final Logger log = LoggerFactory.getLogger(BookingPaymentLinker.class);

    private final PaymentBookingLinkRepository linkRepository;
    private final PaymentRepository paymentRepository;
    private final BookingService bookingService;

    public BookingPaymentLinker(PaymentBookingLinkRepository linkRepository,
                                PaymentRepository paymentRepository,
                                BookingService bookingService) {
        this.linkRepository = linkRepository;
        this.paymentRepository = paymentRepository;
        this.bookingService = bookingService;
    }

    /**
     * Creates a link between a booking and a payment transaction.
     *
     * <p>Called when a booking that requires payment is created, after the
     * payment intent is created but before the customer completes payment.
     * The link is stored even if the payment ultimately fails — the
     * {@code paymentConfirmed} flag is set to {@code false} until the
     * payment is successfully confirmed.
     *
     * @param bookingId          the booking module's booking ID
     * @param paymentTransactionId the payment module's transaction UUID
     * @return the created link entity
     * @throws IllegalStateException if a link already exists for this booking+transaction pair
     */
    @Transactional
    public PaymentBookingLinkEntity createLink(String bookingId, UUID paymentTransactionId) {
        // Check for duplicate link (idempotent)
        Optional<PaymentBookingLinkEntity> existing = linkRepository
                .findByBookingIdAndPaymentTransactionId(bookingId, paymentTransactionId);
        if (existing.isPresent()) {
            log.info("BookingPaymentLink already exists: bookingId={}, txId={}",
                    bookingId, paymentTransactionId);
            return existing.get();
        }

        var link = new PaymentBookingLinkEntity(bookingId, paymentTransactionId);
        link = linkRepository.save(link);
        log.info("Created BookingPaymentLink: bookingId={}, txId={}",
                bookingId, paymentTransactionId);
        return link;
    }

    /**
     * Records that the payment for a booking has been confirmed.
     *
     * <p>Called by the payment confirmation flow after {@link PaymentService#confirmPayment}
     * succeeds. This method:
     * <ol>
     *   <li>Looks up the link by payment transaction ID</li>
     *   <li>Records the confirmed state on the link entity</li>
     *   <li>Updates the booking status via BookingService to reflect confirmed payment</li>
     * </ol>
     *
     * <p>If the booking is not found or the link does not exist, this method
     * logs a warning and returns without throwing — payment confirmation should
     * not be rolled back due to a missing booking link.
     *
     * @param paymentTransactionId the confirmed payment transaction ID
     * @param confirmedState       the payment state at confirmation (usually SUCCEEDED)
     * @return the updated link, or empty if no link exists for this transaction
     */
    @Transactional
    public Optional<PaymentBookingLinkEntity> recordPaymentConfirmation(UUID paymentTransactionId,
                                                                        PaymentState confirmedState) {
        Optional<PaymentBookingLinkEntity> linkOpt = linkRepository
                .findByPaymentTransactionId(paymentTransactionId);

        if (linkOpt.isEmpty()) {
            log.warn("No BookingPaymentLink found for paymentTransactionId={} — skipping booking status update",
                    paymentTransactionId);
            return Optional.empty();
        }

        PaymentBookingLinkEntity link = linkOpt.get();

        // Record confirmation on the link
        link.recordPaymentConfirmed(confirmedState);
        link = linkRepository.save(link);
        log.info("Recorded payment confirmation on BookingPaymentLink: bookingId={}, txId={}, state={}",
                link.getBookingId(), paymentTransactionId, confirmedState);

        // Update booking status to CONFIRMED
        try {
            String bookingId = link.getBookingId();
            bookingService.updateBookingStatus(bookingId, "CONFIRMED");
            log.info("Updated booking status to CONFIRMED: bookingId={}", bookingId);
        } catch (Exception e) {
            // Booking update failure should not roll back the payment link confirmation
            log.error("Failed to update booking status for bookingId={}: {}",
                    link.getBookingId(), e.getMessage(), e);
        }

        return Optional.of(link);
    }

    /**
     * Gets the payment link for a booking.
     *
     * @param bookingId the booking module's booking ID
     * @return the link if it exists
     */
    public Optional<PaymentBookingLinkEntity> getLinkByBookingId(String bookingId) {
        return linkRepository.findByBookingId(bookingId);
    }

    /**
     * Gets the payment link for a payment transaction.
     *
     * @param paymentTransactionId the payment transaction ID
     * @return the link if it exists
     */
    public Optional<PaymentBookingLinkEntity> getLinkByPaymentTransactionId(UUID paymentTransactionId) {
        return linkRepository.findByPaymentTransactionId(paymentTransactionId);
    }

    /**
     * Returns true if the payment for the given booking has been confirmed.
     *
     * @param bookingId the booking module's booking ID
     * @return true if payment confirmed, false otherwise
     */
    public boolean isPaymentConfirmed(String bookingId) {
        return linkRepository.findByBookingId(bookingId)
                .map(PaymentBookingLinkEntity::isPaymentConfirmed)
                .orElse(false);
    }
}
