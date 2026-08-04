package vnpt.vsp.api.tournament;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.TournamentResultResponse;

import java.util.List;
import java.util.UUID;

/**
 * REST controller for tournament results endpoints.
 * Per Story 12.1 Slice C.
 *
 * Endpoints:
 * - POST /tournaments/{id}/results/publish — publish final results
 * - GET  /tournaments/{id}/results         — get published results
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/results")
public class TournamentResultController {

    private static final Logger log = LoggerFactory.getLogger(TournamentResultController.class);

    private final TournamentService tournamentService;

    public TournamentResultController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    /**
     * Publish final results for a tournament.
     */
    @PostMapping("/publish")
    public ResponseEntity<Void> publishResults(@PathVariable UUID tournamentId) {
        log.info("POST /tournaments/{}/results/publish", tournamentId);
        tournamentService.publishResults(tournamentId);
        return ResponseEntity.ok().build();
    }

    /**
     * Get published results for a tournament.
     */
    @GetMapping
    public ResponseEntity<List<TournamentResultResponse>> getResults(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/results", tournamentId);
        List<TournamentResultResponse> responses = tournamentService.getResults(tournamentId);
        return ResponseEntity.ok(responses);
    }
}
