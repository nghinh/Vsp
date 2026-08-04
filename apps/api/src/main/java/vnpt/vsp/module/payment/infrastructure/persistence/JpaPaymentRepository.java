package vnpt.vsp.module.payment.infrastructure.persistence;

import org.springframework.stereotype.Repository;
import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * JPA implementation of PaymentRepository.
 */
@Repository
public class JpaPaymentRepository implements PaymentRepository {

    @PersistenceContext
    private EntityManager em;

    @Override
    public PaymentTransactionEntity save(PaymentTransactionEntity transaction) {
        return em.merge(transaction);
    }

    @Override
    public Optional<PaymentTransactionEntity> findById(UUID id) {
        return Optional.ofNullable(em.find(PaymentTransactionEntity.class, id));
    }

    @Override
    public Optional<PaymentTransactionEntity> findByIdempotencyKey(String idempotencyKey) {
        var query = em.createQuery(
                "SELECT p FROM PaymentTransactionEntity p WHERE p.idempotencyKey = :key",
                PaymentTransactionEntity.class);
        query.setParameter("key", idempotencyKey);
        return query.getResultStream().findFirst();
    }

    @Override
    public Optional<PaymentTransactionEntity> findByProviderReference(String providerReference) {
        var query = em.createQuery(
                "SELECT p FROM PaymentTransactionEntity p WHERE p.providerReference = :ref",
                PaymentTransactionEntity.class);
        query.setParameter("ref", providerReference);
        return query.getResultStream().findFirst();
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<PaymentTransactionEntity> findByState(PaymentState state, OffsetDateTime since) {
        var query = em.createQuery(
                "SELECT p FROM PaymentTransactionEntity p WHERE p.state = :state AND p.updatedAt >= :since",
                PaymentTransactionEntity.class);
        query.setParameter("state", state);
        query.setParameter("since", since);
        return query.getResultList();
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<PaymentTransactionEntity> findAllUpdatedSince(OffsetDateTime since) {
        var query = em.createQuery(
                "SELECT p FROM PaymentTransactionEntity p WHERE p.updatedAt >= :since",
                PaymentTransactionEntity.class);
        query.setParameter("since", since);
        return query.getResultList();
    }

    @Override
    public long countByState(String state) {
        var query = em.createQuery(
                "SELECT COUNT(p) FROM PaymentTransactionEntity p WHERE p.state = :state",
                Long.class);
        query.setParameter("state", state);
        return (Long) query.getSingleResult();
    }
}
