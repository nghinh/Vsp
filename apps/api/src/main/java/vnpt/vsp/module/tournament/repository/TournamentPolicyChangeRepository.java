package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TournamentPolicyChange;

import java.util.List;
import java.util.UUID;

@Repository
public interface TournamentPolicyChangeRepository extends JpaRepository<TournamentPolicyChange, UUID> {

    /**
     * Returns all audit records for a given policy, ordered by change time descending.
     */
    List<TournamentPolicyChange> findByPolicyIdOrderByChangedAtDesc(UUID policyId);
}
