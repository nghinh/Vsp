package vnpt.vsp.api.tournament;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.service.ScoreConfirmationService;
import vnpt.vsp.module.tournament.dto.FlightCreateRequest;
import vnpt.vsp.module.tournament.dto.FlightResponse;
import vnpt.vsp.module.tournament.dto.FlightUpdateRequest;

import java.util.List;
import java.util.UUID;

/**
 * REST controller for flight management endpoints.
 * Per Story 12.1 Slice C.
 *
 * Endpoints:
 * - POST   /tournaments/{id}/flights           — create flight
 * - PATCH  /tournaments/{id}/flights/{flightId} — assign players to flight
 * - GET    /tournaments/{id}/flights            — list flights
 *
 * <p>Creating and re-drawing flights, and confirming a flight's scorecard, are
 * a tournament official's work. This class had no authorization annotation, so
 * any signed-in golfer could redraw the draw or confirm somebody else's card —
 * and a confirmed card is what {@code POST /tournaments/{id}/complete} requires
 * before it settles the tournament. Listing flights stays open, as the mobile
 * app reads it.
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/flights")
public class FlightController {

    private static final Logger log = LoggerFactory.getLogger(FlightController.class);

    private final TournamentService tournamentService;
    private final ScoreConfirmationService scoreConfirmationService;

    public FlightController(TournamentService tournamentService,
                            ScoreConfirmationService scoreConfirmationService) {
        this.tournamentService = tournamentService;
        this.scoreConfirmationService = scoreConfirmationService;
    }

    /**
     * Create a flight for a tournament.
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<FlightResponse> createFlight(
            @PathVariable UUID tournamentId,
            @Valid @RequestBody FlightCreateRequest request) {

        log.info("POST /tournaments/{}/flights - flightNumber={}", tournamentId, request.getFlightNumber());

        FlightResponse response = tournamentService.createFlight(tournamentId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Update a flight (assign players, assign tee time).
     */
    @PatchMapping("/{flightId}")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<FlightResponse> updateFlight(
            @PathVariable UUID tournamentId,
            @PathVariable UUID flightId,
            @RequestBody FlightUpdateRequest request) {

        log.info("PATCH /tournaments/{}/flights/{}", tournamentId, flightId);

        FlightResponse response = tournamentService.updateFlight(tournamentId, flightId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * List flights for a tournament.
     */
    @GetMapping
    public ResponseEntity<List<FlightResponse>> listFlights(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/flights", tournamentId);
        List<FlightResponse> responses = tournamentService.listFlights(tournamentId);
        return ResponseEntity.ok(responses);
    }

    /**
     * Confirm a flight's scorecard (marks the flight's scores as confirmed by the
     * authenticated official). Story 12.1 — score confirmation gate.
     */
    @PostMapping("/{flightId}/confirm")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<Void> confirmFlight(
            @PathVariable UUID tournamentId,
            @PathVariable UUID flightId,
            Authentication authentication) {

        Long confirmerId = (Long) authentication.getPrincipal();
        log.info("POST /tournaments/{}/flights/{}/confirm - confirmer={}",
                tournamentId, flightId, confirmerId);

        scoreConfirmationService.confirmFlight(flightId, confirmerId);
        return ResponseEntity.noContent().build();
    }
}
