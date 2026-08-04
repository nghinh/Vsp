package vnpt.vsp.module.payment.infrastructure.persistence;

import org.springframework.stereotype.Repository;
import vnpt.vsp.module.payment.domain.models.PaymentBookingLinkEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentBookingLinkRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.util.Optional;
import java.util.UUID;

/**
 * JPA implementation of PaymentBookingLinkRepository.
 */
@Repository
public class JpaPaymentBookingLinkRepository implements PaymentBookingLinkRepository {

    @PersistenceContext
    private EntityManager em;

    @Override
    public PaymentBookingLinkEntity save(PaymentBookingLinkEntity link) {
        return em.merge(link);
    }

    @Override
    public Optional<PaymentBookingLinkEntity> findById(UUID id) {
        return Optional.ofNullable(em.find(PaymentBookingLinkEntity.class, id));
    }

    @Override
    public Optional<PaymentBookingLinkEntity> findByBookingId(String bookingId) {
        var query = em.createQuery(
                "SELECT l FROM PaymentBookingLinkEntity l WHERE l.bookingId = :bookingId",
                PaymentBookingLinkEntity.class);
        query.setParameter("bookingId", bookingId);
        return query.getResultStream().findFirst();
    }

    @Override
    public Optional<PaymentBookingLinkEntity> findByPaymentTransactionId(UUID paymentTransactionId) {
        var query = em.createQuery(
                "SELECT l FROM PaymentBookingLinkEntity l WHERE l.paymentTransactionId = :paymentTransactionId",
                PaymentBookingLinkEntity.class);
        query.setParameter("paymentTransactionId", paymentTransactionId);
        return query.getResultStream().findFirst();
    }

    @Override
    public Optional<PaymentBookingLinkEntity> findByBookingIdAndPaymentTransactionId(String bookingId, UUID paymentTransactionId) {
        var query = em.createQuery(
                "SELECT l FROM PaymentBookingLinkEntity l WHERE l.bookingId = :bookingId AND l.paymentTransactionId = :paymentTransactionId",
                PaymentBookingLinkEntity.class);
        query.setParameter("bookingId", bookingId);
        query.setParameter("paymentTransactionId", paymentTransactionId);
        return query.getResultStream().findFirst();
    }
}
