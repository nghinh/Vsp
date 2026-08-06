package vnpt.vsp.api.tournament;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.TournamentPlayerResponse;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * REST controller for tournament player registration endpoints.
 * Per Story 12.1 Slice C.
 *
 * Endpoints:
 * - POST   /tournaments/{id}/players              — register player
 * - POST   /tournaments/{id}/players/import       — bulk import from CSV/list
 * - DELETE /tournaments/{id}/players/{playerId}   — withdraw player
 * - GET    /tournaments/{id}/players              — list registered players
 *
 * <p>Ungated until now, in both directions: any signed-in golfer could enter
 * arbitrary player ids into a tournament with a handicap of their choosing,
 * bulk-import a field, or withdraw somebody else. Note that these endpoints
 * take the player id from the request rather than from the authenticated
 * principal — they are the director's roster tools, not self-registration, so
 * they take the director's role.
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/players")
public class TournamentRegistrationController {

    private static final Logger log = LoggerFactory.getLogger(TournamentRegistrationController.class);

    private final TournamentService tournamentService;

    public TournamentRegistrationController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    /**
     * Register a player to a tournament.
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<TournamentPlayerResponse> registerPlayer(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody Map<String, Object> request) {

        Long playerId = ((Number) request.get("playerId")).longValue();
        Double handicap = request.containsKey("handicap") ? ((Number) request.get("handicap")).doubleValue() : null;

        log.info("POST /tournaments/{}/players - playerId={}", tournamentId, playerId);

        TournamentPlayerResponse response = tournamentService.registerPlayer(tournamentId, playerId, handicap);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Bulk import players from a list.
     */
    @PostMapping("/import")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<List<TournamentPlayerResponse>> bulkImportPlayers(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody Map<String, Object> request) {

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> players = (List<Map<String, Object>>) request.get("players");

        log.info("POST /tournaments/{}/players/import - count={}", tournamentId, players.size());

        var playerResponses = players.stream()
                .map(p -> {
                    TournamentPlayerResponse r = new TournamentPlayerResponse();
                    r.setPlayerId(((Number) p.get("playerId")).longValue());
                    if (p.containsKey("handicap")) {
                        r.setHandicap(((Number) p.get("handicap")).doubleValue());
                    }
                    return r;
                })
                .toList();

        List<TournamentPlayerResponse> responses = tournamentService.bulkImportPlayers(tournamentId, playerResponses);
        return ResponseEntity.status(HttpStatus.CREATED).body(responses);
    }

    /**
     * Withdraw a player from a tournament.
     */
    @DeleteMapping("/{playerId}")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'SUPER_ADMIN')")
    public ResponseEntity<Void> withdrawPlayer(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @PathVariable Long playerId) {

        log.info("DELETE /tournaments/{}/players/{}", tournamentId, playerId);
        tournamentService.withdrawPlayer(tournamentId, playerId);
        return ResponseEntity.noContent().build();
    }

    /**
     * List registered players for a tournament.
     */
    @GetMapping
    public ResponseEntity<List<TournamentPlayerResponse>> listPlayers(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/players", tournamentId);
        List<TournamentPlayerResponse> responses = tournamentService.listPlayers(tournamentId);
        return ResponseEntity.ok(responses);
    }
}
