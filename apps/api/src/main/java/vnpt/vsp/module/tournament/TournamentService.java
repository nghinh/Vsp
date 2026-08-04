package vnpt.vsp.module.tournament;

import vnpt.vsp.module.tournament.dto.*;
import vnpt.vsp.module.tournament.entity.Tournament;
import vnpt.vsp.module.tournament.entity.TournamentStatus;

import java.util.List;
import java.util.UUID;

/**
 * Public service interface for Tournament operations.
 * Per Story 12.1 AC: supports formats, registration/import, flights, tee times,
 * starting tees, score confirmation, tie-break, and result publication.
 */
public interface TournamentService {

    // ─── Tournament CRUD ───────────────────────────────────────────────────

    /**
     * Creates a new tournament.
     *
     * @param request the creation request
     * @param createdBy the account ID of the actor creating the tournament
     * @return the created tournament response
     */
    TournamentResponse createTournament(TournamentCreateRequest request, Long createdBy);

    /**
     * Returns a tournament by ID.
     *
     * @param tournamentId the tournament UUID
     * @return the tournament response
     */
    TournamentResponse getTournament(UUID tournamentId);

    /**
     * Updates a tournament (only allowed before IN_PROGRESS status).
     *
     * @param tournamentId the tournament UUID
     * @param request the update request
     * @return the updated tournament response
     */
    TournamentResponse updateTournament(UUID tournamentId, TournamentCreateRequest request);

    /**
     * Lists tournaments with optional status filter.
     *
     * @param status optional status filter
     * @param courseId optional course ID filter
     * @return list of tournament responses
     */
    List<TournamentResponse> listTournaments(TournamentStatus status, Long courseId);

    // ─── Tournament lifecycle ─────────────────────────────────────────────

    /**
     * Opens registration for a tournament (DRAFT -> REGISTRATION_OPEN).
     *
     * @param tournamentId the tournament UUID
     */
    void openRegistration(UUID tournamentId);

    /**
     * Starts a tournament (REGISTRATION_OPEN -> IN_PROGRESS).
     *
     * @param tournamentId the tournament UUID
     */
    void startTournament(UUID tournamentId);

    /**
     * Completes a tournament (IN_PROGRESS -> COMPLETED).
     * Requires all flights to have confirmed scores.
     *
     * @param tournamentId the tournament UUID
     */
    void completeTournament(UUID tournamentId);

    // ─── Player registration ───────────────────────────────────────────────

    /**
     * Registers a player to a tournament.
     *
     * @param tournamentId the tournament UUID
     * @param playerId the player account ID
     * @param handicap optional handicap
     * @return the player response
     */
    TournamentPlayerResponse registerPlayer(UUID tournamentId, Long playerId, Double handicap);

    /**
     * Bulk imports players from a list.
     *
     * @param tournamentId the tournament UUID
     * @param players list of player data (playerId, handicap)
     * @return list of created player responses
     */
    List<TournamentPlayerResponse> bulkImportPlayers(UUID tournamentId, List<TournamentPlayerResponse> players);

    /**
     * Withdraws a player from a tournament.
     *
     * @param tournamentId the tournament UUID
     * @param playerId the player account ID
     */
    void withdrawPlayer(UUID tournamentId, Long playerId);

    /**
     * Lists registered players for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return list of player responses
     */
    List<TournamentPlayerResponse> listPlayers(UUID tournamentId);

    // ─── Flight management ─────────────────────────────────────────────────

    /**
     * Creates a flight for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @param request the flight creation request
     * @return the flight response
     */
    FlightResponse createFlight(UUID tournamentId, FlightCreateRequest request);

    /**
     * Updates a flight (assign players, assign tee time).
     *
     * @param tournamentId the tournament UUID
     * @param flightId the flight UUID
     * @param request the update request
     * @return the updated flight response
     */
    FlightResponse updateFlight(UUID tournamentId, UUID flightId, FlightUpdateRequest request);

    /**
     * Lists flights for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return list of flight responses
     */
    List<FlightResponse> listFlights(UUID tournamentId);

    // ─── Tee time management ──────────────────────────────────────────────

    /**
     * Creates a tee time slot for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @param request the tee time creation request
     * @return the tee time response
     */
    TeeTimeResponse createTeeTime(UUID tournamentId, TeeTimeCreateRequest request);

    /**
     * Updates a tee time (assigns flight).
     *
     * @param tournamentId the tournament UUID
     * @param teeTimeId the tee time UUID
     * @param request the update request
     * @return the updated tee time response
     */
    TeeTimeResponse updateTeeTime(UUID tournamentId, UUID teeTimeId, TeeTimeUpdateRequest request);

    /**
     * Lists tee times for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return list of tee time responses
     */
    List<TeeTimeResponse> listTeeTimes(UUID tournamentId);

    // ─── Results ───────────────────────────────────────────────────────────

    /**
     * Publishes final results for a tournament.
     *
     * @param tournamentId the tournament UUID
     */
    void publishResults(UUID tournamentId);

    /**
     * Gets published results for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return list of result responses
     */
    List<TournamentResultResponse> getResults(UUID tournamentId);

    // ─── Leaderboard ──────────────────────────────────────────────────────

    /**
     * Gets the current leaderboard for a tournament.
     *
     * @param tournamentId the tournament UUID
     * @return the leaderboard response
     */
    LeaderboardResponse getLeaderboard(UUID tournamentId);

    /**
     * Returns the raw Tournament entity by ID.
     * Used internally by RoundServiceImpl to auto-populate tournamentPolicyId
     * when a round is created with a tournamentId.
     * Per Story 12.1 Slice F.
     *
     * @param tournamentId the tournament UUID
     * @return the Tournament entity, or null if not found
     */
    Tournament getTournamentEntity(UUID tournamentId);
}
