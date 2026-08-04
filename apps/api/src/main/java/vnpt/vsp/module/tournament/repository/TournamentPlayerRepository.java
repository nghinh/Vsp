package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TournamentPlayer;
import vnpt.vsp.module.tournament.entity.TournamentPlayerStatus;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TournamentPlayerRepository extends JpaRepository<TournamentPlayer, UUID> {

    List<TournamentPlayer> findByTournamentId(UUID tournamentId);

    List<TournamentPlayer> findByTournamentIdAndStatus(UUID tournamentId, TournamentPlayerStatus status);

    Optional<TournamentPlayer> findByTournamentIdAndPlayerId(UUID tournamentId, Long playerId);

    boolean existsByTournamentIdAndPlayerId(UUID tournamentId, Long playerId);

    int countByTournamentId(UUID tournamentId);

    List<TournamentPlayer> findByFlightId(UUID flightId);
}
