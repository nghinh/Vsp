package vnpt.vsp.module.payment.domain.models;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Entity linking a Booking to a PaymentTransaction.
 *
 * Stores the foreign key relationship between a booking (managed by the
 * booking module) and a payment transaction (managed by this module).
 * This entity is owned by the payment module — booking module does not
 * hold a reference to it.
 *
 * Per Story 12.3 S4: Booking Integration.
 */
@Entity
@Table(name = "payment_booking_links", indexes = {
        @Index(name = "idx_payment_booking_link_booking_id", columnList = "booking_id"),
        @Index(name = "idx_payment_booking_link_payment_tx_id", columnList = "payment_transaction_id"),
        @Index(name = "idx_payment_booking_link_booking_id_tx_id", columnList = "booking_id, payment_transaction_id", unique = true)
})
public class PaymentBookingLinkEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * Booking module's booking identifier.
     * References BookingService.Booking.bookingId (a String UUID).
     */
    @Column(name = "booking_id", nullable = false)
    private String bookingId;

    /**
     * Payment transaction identifier linking to PaymentTransactionEntity.id.
     */
    @Column(name = "payment_transaction_id", nullable = false)
    private UUID paymentTransactionId;

    /**
     * Payment state at the time the link was confirmed.
     * Stored so the link record reflects what state triggered the confirmation.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "confirmed_state", length = 30)
    private PaymentState confirmedState;

    /**
     * Whether the payment has been confirmed and booking status updated.
     */
    @Column(name = "payment_confirmed", nullable = false)
    private boolean paymentConfirmed = false;

    /**
     * When the payment was confirmed (null until confirmed).
     */
    @Column(name = "confirmed_at")
    private OffsetDateTime confirmedAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Default constructor for JPA
    protected PaymentBookingLinkEntity() {
    }

    public PaymentBookingLinkEntity(String bookingId, UUID paymentTransactionId) {
        this.bookingId = bookingId;
        this.paymentTransactionId = paymentTransactionId;
        this.paymentConfirmed = false;
        this.createdAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    /**
     * Records that the linked payment was confirmed successfully.
     * Called by BookingPaymentLinker when PaymentService.confirmPayment() succeeds.
     */
    public void recordPaymentConfirmed(PaymentState confirmedState) {
        this.confirmedState = confirmedState;
        this.paymentConfirmed = true;
        this.confirmedAt = OffsetDateTime.now();
        this.updatedAt = OffsetDateTime.now();
    }

    // Getters
    public UUID getId() { return id; }
    public String getBookingId() { return bookingId; }
    public UUID getPaymentTransactionId() { return paymentTransactionId; }
    public PaymentState getConfirmedState() { return confirmedState; }
    public boolean isPaymentConfirmed() { return paymentConfirmed; }
    public OffsetDateTime getConfirmedAt() { return confirmedAt; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }

    // Setters for JPA
    public void setConfirmedState(PaymentState confirmedState) { this.confirmedState = confirmedState; }
    public void setPaymentConfirmed(boolean paymentConfirmed) { this.paymentConfirmed = paymentConfirmed; }
    public void setConfirmedAt(OffsetDateTime confirmedAt) { this.confirmedAt = confirmedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
