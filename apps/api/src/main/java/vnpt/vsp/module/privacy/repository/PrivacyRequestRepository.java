package vnpt.vsp.module.privacy.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.privacy.entity.PrivacyRequest;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.Status;

import java.util.List;
import java.util.Optional;

@Repository
public interface PrivacyRequestRepository extends JpaRepository<PrivacyRequest, Long> {

    List<PrivacyRequest> findByRequesterGolferAccountId(Long requesterGolferAccountId);

    Optional<PrivacyRequest> findByIdAndRequesterGolferAccountId(Long id, Long requesterGolferAccountId);

    List<PrivacyRequest> findByStatus(Status status);

    Optional<PrivacyRequest> findByIdAndStatus(Long id, Status status);

    long countByRequesterGolferAccountIdAndStatus(Long requesterGolferAccountId, Status status);
}
