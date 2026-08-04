package vnpt.vsp.api.tournament;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.*;

import java.util.UUID;

/**
 * REST controller for tournament CRUD and lifecycle endpoints.
 * Per Story 12.1 Slice C.
 *
 * Endpoints:
 * - POST   /tournaments                    — create tournament
 * - GET    /tournaments/{id}               — get tournament
 * - PATCH  /tournaments/{id}               — update tournament (before inProgress)
 * - GET    /tournaments                    — list tournaments
 * - POST   /tournaments/{id}/publish       — open registration
 * - POST   /tournaments/{id}/start         — start tournament
 * - POST   /tournaments/{id}/complete      — complete tournament
 */
@RestController
@RequestMapping("/tournaments")
public class TournamentController {

    private static final Logger log = LoggerFactory.getLogger(TournamentController.class);

    private final TournamentService tournamentService;

    public TournamentController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    /**
     * Create a new tournament.
     */
    @PostMapping
    public ResponseEntity<TournamentResponse> createTournament(
            Authentication authentication,
            @Valid @RequestBody TournamentCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /tournaments - accountId={}, name={}", accountId, request.getName());

        TournamentResponse response = tournamentService.createTournament(request, accountId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Get a tournament by ID.
     */
    @GetMapping("/{tournamentId}")
    public ResponseEntity<TournamentResponse> getTournament(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}", tournamentId);
        TournamentResponse response = tournamentService.getTournament(tournamentId);
        return ResponseEntity.ok(response);
    }

    /**
     * Update a tournament (only allowed before inProgress status).
     */
    @PatchMapping("/{tournamentId}")
    public ResponseEntity<TournamentResponse> updateTournament(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody TournamentCreateRequest request) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("PATCH /tournaments/{} - accountId={}", tournamentId, accountId);

        TournamentResponse response = tournamentService.updateTournament(tournamentId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * List tournaments with optional filters.
     */
    @GetMapping
    public ResponseEntity<?> listTournaments(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long courseId) {

        log.info("GET /tournaments - status={}, courseId={}", status, courseId);

        var statusEnum = status != null ? vnpt.vsp.module.tournament.entity.TournamentStatus.valueOf(status) : null;
        var tournaments = tournamentService.listTournaments(statusEnum, courseId);
        return ResponseEntity.ok(tournaments);
    }

    /**
     * Open registration for a tournament (DRAFT -> REGISTRATION_OPEN).
     */
    @PostMapping("/{tournamentId}/publish")
    public ResponseEntity<Void> openRegistration(@PathVariable UUID tournamentId) {
        log.info("POST /tournaments/{}/publish", tournamentId);
        tournamentService.openRegistration(tournamentId);
        return ResponseEntity.ok().build();
    }

    /**
     * Start a tournament (REGISTRATION_OPEN -> IN_PROGRESS).
     */
    @PostMapping("/{tournamentId}/start")
    public ResponseEntity<Void> startTournament(@PathVariable UUID tournamentId) {
        log.info("POST /tournaments/{}/start", tournamentId);
        tournamentService.startTournament(tournamentId);
        return ResponseEntity.ok().build();
    }

    /**
     * Complete a tournament (IN_PROGRESS -> COMPLETED).
     * All flights must have confirmed scores.
     */
    @PostMapping("/{tournamentId}/complete")
    public ResponseEntity<Void> completeTournament(@PathVariable UUID tournamentId) {
        log.info("POST /tournaments/{}/complete", tournamentId);
        tournamentService.completeTournament(tournamentId);
        return ResponseEntity.ok().build();
    }
}
