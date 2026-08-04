package vnpt.vsp.module.payment.infrastructure.persistence;

import org.springframework.stereotype.Repository;
import vnpt.vsp.module.payment.domain.models.PaymentAuditLogEntity;
import vnpt.vsp.module.payment.domain.repositories.PaymentAuditRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.util.List;
import java.util.UUID;

/**
 * JPA implementation of PaymentAuditRepository.
 */
@Repository
public class JpaPaymentAuditRepository implements PaymentAuditRepository {

    @PersistenceContext
    private EntityManager em;

    @Override
    public PaymentAuditLogEntity save(PaymentAuditLogEntity auditLog) {
        return em.merge(auditLog);
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<PaymentAuditLogEntity> findByTransactionId(UUID transactionId) {
        var query = em.createQuery(
                "SELECT a FROM PaymentAuditLogEntity a WHERE a.transaction.id = :txId ORDER BY a.timestamp ASC",
                PaymentAuditLogEntity.class);
        query.setParameter("txId", transactionId);
        return query.getResultList();
    }
}
