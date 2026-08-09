package vnpt.vsp.module.tournament.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vnpt.vsp.module.tournament.entity.Flight;

import java.util.List;
import java.util.UUID;

@Repository
public interface FlightRepository extends JpaRepository<Flight, UUID> {

    List<Flight> findByTournamentIdOrderByFlightNumber(UUID tournamentId);

    List<Flight> findByTournamentId(UUID tournamentId);

    List<Flight> findByTournamentIdAndTeeTimeIsNotNull(UUID tournamentId);

    List<Flight> findByTournamentIdAndTeeTimeIsNull(UUID tournamentId);
}
