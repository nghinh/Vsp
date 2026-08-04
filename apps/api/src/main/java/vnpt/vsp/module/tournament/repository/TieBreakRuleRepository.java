package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TieBreakRule;

import java.util.List;
import java.util.UUID;

@Repository
public interface TieBreakRuleRepository extends JpaRepository<TieBreakRule, UUID> {

    List<TieBreakRule> findByTournamentIdOrderByOrder(UUID tournamentId);
}
