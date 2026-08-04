package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TournamentResult;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TournamentResultRepository extends JpaRepository<TournamentResult, UUID> {

    List<TournamentResult> findByTournamentIdOrderByRank(UUID tournamentId);

    Optional<TournamentResult> findByTournamentIdAndPlayerId(UUID tournamentId, Long playerId);

    boolean existsByTournamentId(UUID tournamentId);
}
