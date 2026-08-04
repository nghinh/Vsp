package vnpt.vsp.module.payment.domain.repositories;

import vnpt.vsp.module.payment.domain.models.PaymentState;
import vnpt.vsp.module.payment.domain.models.PaymentTransactionEntity;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository interface for PaymentTransactionEntity.
 * No module may directly @Autowired a Impl from another module — only this interface.
 */
public interface PaymentRepository {

    PaymentTransactionEntity save(PaymentTransactionEntity transaction);

    Optional<PaymentTransactionEntity> findById(UUID id);

    Optional<PaymentTransactionEntity> findByIdempotencyKey(String idempotencyKey);

    Optional<PaymentTransactionEntity> findByProviderReference(String providerReference);

    List<PaymentTransactionEntity> findByState(PaymentState state, OffsetDateTime since);

    List<PaymentTransactionEntity> findAllUpdatedSince(OffsetDateTime since);

    long countByState(String state);
}
