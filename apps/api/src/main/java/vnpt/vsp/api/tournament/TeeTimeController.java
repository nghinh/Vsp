package vnpt.vsp.api.tournament;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.TournamentService;
import vnpt.vsp.module.tournament.dto.TeeTimeCreateRequest;
import vnpt.vsp.module.tournament.dto.TeeTimeResponse;
import vnpt.vsp.module.tournament.dto.TeeTimeUpdateRequest;

import java.util.List;
import java.util.UUID;

/**
 * REST controller for tee time management endpoints.
 * Per Story 12.1 Slice C.
 *
 * Endpoints:
 * - POST   /tournaments/{id}/tee-times        — create tee time slot
 * - PATCH  /tournaments/{id}/tee-times/{id}   — assign flight to tee time
 * - GET    /tournaments/{id}/tee-times         — list tee times
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/tee-times")
public class TeeTimeController {

    private static final Logger log = LoggerFactory.getLogger(TeeTimeController.class);

    private final TournamentService tournamentService;

    public TeeTimeController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    /**
     * Create a tee time slot for a tournament.
     */
    @PostMapping
    public ResponseEntity<TeeTimeResponse> createTeeTime(
            @PathVariable UUID tournamentId,
            @Valid @RequestBody TeeTimeCreateRequest request) {

        log.info("POST /tournaments/{}/tee-times", tournamentId);

        TeeTimeResponse response = tournamentService.createTeeTime(tournamentId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Update a tee time (assign flight).
     */
    @PatchMapping("/{teeTimeId}")
    public ResponseEntity<TeeTimeResponse> updateTeeTime(
            @PathVariable UUID tournamentId,
            @PathVariable UUID teeTimeId,
            @RequestBody TeeTimeUpdateRequest request) {

        log.info("PATCH /tournaments/{}/tee-times/{}", tournamentId, teeTimeId);

        TeeTimeResponse response = tournamentService.updateTeeTime(tournamentId, teeTimeId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * List tee times for a tournament.
     */
    @GetMapping
    public ResponseEntity<List<TeeTimeResponse>> listTeeTimes(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/tee-times", tournamentId);
        List<TeeTimeResponse> responses = tournamentService.listTeeTimes(tournamentId);
        return ResponseEntity.ok(responses);
    }
}
