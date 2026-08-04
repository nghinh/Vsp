package vnpt.vsp.module.payment.domain.repositories;

import vnpt.vsp.module.payment.domain.models.PaymentAuditLogEntity;

import java.util.List;
import java.util.UUID;

/**
 * Repository interface for PaymentAuditLogEntity.
 */
public interface PaymentAuditRepository {

    PaymentAuditLogEntity save(PaymentAuditLogEntity auditLog);

    List<PaymentAuditLogEntity> findByTransactionId(UUID transactionId);
}
