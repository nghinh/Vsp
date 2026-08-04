package vnpt.vsp.module.tournament.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.tournament.entity.Flight;
import vnpt.vsp.module.tournament.repository.FlightRepository;

import java.time.Instant;
import java.util.UUID;

/**
 * ScoreConfirmationService implementation.
 * Per Story 12.1 Slice D: locks flight scores after confirmation by tournament director.
 */
@Service
public class ScoreConfirmationServiceImpl implements ScoreConfirmationService {

    private static final Logger log = LoggerFactory.getLogger(ScoreConfirmationServiceImpl.class);

    private final FlightRepository flightRepository;

    public ScoreConfirmationServiceImpl(FlightRepository flightRepository) {
        this.flightRepository = flightRepository;
    }

    @Override
    public void confirmFlight(UUID flightId, Long confirmerId) {
        log.info("Confirming flight: flightId={}, confirmerId={}", flightId, confirmerId);

        Flight flight = flightRepository.findById(flightId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.TOURNAMENT_008, "Flight not found"));

        if (flight.isConfirmed()) {
            log.info("Flight already confirmed: flightId={}", flightId);
            return; // Idempotent
        }

        flight.setConfirmedAt(Instant.now());
        flight.setConfirmedBy(confirmerId);
        flightRepository.save(flight);

        log.info("Flight confirmed: flightId={}", flightId);
    }

    @Override
    public boolean areAllFlightsConfirmed(UUID tournamentId) {
        var flights = flightRepository.findByTournamentIdOrderByFlightNumber(tournamentId);
        if (flights.isEmpty()) {
            return false;
        }
        return flights.stream().allMatch(Flight::isConfirmed);
    }
}
