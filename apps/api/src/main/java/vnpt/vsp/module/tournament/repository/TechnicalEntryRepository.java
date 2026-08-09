package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import vnpt.vsp.module.tournament.entity.TechnicalEntry;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TechnicalEntryRepository extends JpaRepository<TechnicalEntry, UUID> {

    List<TechnicalEntry> findByTournamentId(UUID tournamentId);

    /** The one entry a player may hold for a prize on a hole — a re-measure replaces it. */
    Optional<TechnicalEntry> findByTournamentIdAndPrizeCodeAndHoleNumberAndPlayerId(
            UUID tournamentId, String prizeCode, Integer holeNumber, UUID playerId);
}
