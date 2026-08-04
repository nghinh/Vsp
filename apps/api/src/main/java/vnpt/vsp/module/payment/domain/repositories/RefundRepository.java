package vnpt.vsp.module.payment.domain.repositories;

import vnpt.vsp.module.payment.domain.models.RefundRequestEntity;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository interface for RefundRequestEntity.
 */
public interface RefundRepository {

    RefundRequestEntity save(RefundRequestEntity refundRequest);

    Optional<RefundRequestEntity> findById(UUID id);

    Optional<RefundRequestEntity> findByIdempotencyKey(String idempotencyKey);

    List<RefundRequestEntity> findByTransactionId(UUID transactionId);
}
