package vnpt.vsp.module.payment.domain.repositories;

import vnpt.vsp.module.payment.domain.models.PaymentBookingLinkEntity;

import java.util.Optional;
import java.util.UUID;

/**
 * Repository interface for PaymentBookingLinkEntity.
 * No module may directly @Autowired a JPA repository from another module.
 */
public interface PaymentBookingLinkRepository {

    PaymentBookingLinkEntity save(PaymentBookingLinkEntity link);

    Optional<PaymentBookingLinkEntity> findById(UUID id);

    /**
     * Find link by booking ID.
     */
    Optional<PaymentBookingLinkEntity> findByBookingId(String bookingId);

    /**
     * Find link by payment transaction ID.
     */
    Optional<PaymentBookingLinkEntity> findByPaymentTransactionId(UUID paymentTransactionId);

    /**
     * Find link by booking ID and payment transaction ID (unique constraint).
     */
    Optional<PaymentBookingLinkEntity> findByBookingIdAndPaymentTransactionId(String bookingId, UUID paymentTransactionId);
}
