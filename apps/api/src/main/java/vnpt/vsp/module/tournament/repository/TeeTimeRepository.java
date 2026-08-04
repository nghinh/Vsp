package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.TeeTime;

import java.util.List;
import java.util.UUID;

@Repository
public interface TeeTimeRepository extends JpaRepository<TeeTime, UUID> {

    List<TeeTime> findByTournamentIdOrderByTeeTime(UUID tournamentId);

    List<TeeTime> findByTournamentIdAndFlightIsNotNull(UUID tournamentId);

    List<TeeTime> findByTournamentIdAndFlightIsNull(UUID tournamentId);
}
