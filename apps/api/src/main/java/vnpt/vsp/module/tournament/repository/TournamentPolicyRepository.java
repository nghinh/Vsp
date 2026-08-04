package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TournamentPolicy;

import java.util.UUID;

@Repository
public interface TournamentPolicyRepository extends JpaRepository<TournamentPolicy, UUID> {
}
