package vnpt.vsp.module.tournament.service;

import java.util.UUID;

/**
 * Service interface for score confirmation.
 * Per Story 12.1 Slice D: locks flight scores after confirmation by tournament director.
 */
public interface ScoreConfirmationService {

    /**
     * Confirms all scores for a flight.
     * Called by the tournament director after verifying flight scores.
     *
     * @param flightId the flight UUID
     * @param confirmerId the account ID of the tournament director confirming
     */
    void confirmFlight(UUID flightId, Long confirmerId);

    /**
     * Checks if all flights in a tournament have confirmed scores.
     *
     * @param tournamentId the tournament UUID
     * @return true if all flights are confirmed
     */
    boolean areAllFlightsConfirmed(UUID tournamentId);
}
