package vnpt.vsp.module.payment.infrastructure.persistence;

import org.springframework.stereotype.Repository;
import vnpt.vsp.module.payment.domain.models.RefundRequestEntity;
import vnpt.vsp.module.payment.domain.repositories.RefundRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * JPA implementation of RefundRepository.
 */
@Repository
public class JpaRefundRepository implements RefundRepository {

    @PersistenceContext
    private EntityManager em;

    @Override
    public RefundRequestEntity save(RefundRequestEntity refundRequest) {
        return em.merge(refundRequest);
    }

    @Override
    public Optional<RefundRequestEntity> findById(UUID id) {
        return Optional.ofNullable(em.find(RefundRequestEntity.class, id));
    }

    @Override
    public Optional<RefundRequestEntity> findByIdempotencyKey(String idempotencyKey) {
        var query = em.createQuery(
                "SELECT r FROM RefundRequestEntity r WHERE r.idempotencyKey = :key",
                RefundRequestEntity.class);
        query.setParameter("key", idempotencyKey);
        return query.getResultStream().findFirst();
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<RefundRequestEntity> findByTransactionId(UUID transactionId) {
        var query = em.createQuery(
                "SELECT r FROM RefundRequestEntity r WHERE r.transaction.id = :txId ORDER BY r.requestedAt DESC",
                RefundRequestEntity.class);
        query.setParameter("txId", transactionId);
        return query.getResultList();
    }
}
