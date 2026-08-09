package vnpt.vsp.api.tournament;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.OutingService;
import vnpt.vsp.module.tournament.dto.OutingResultsResponse;
import vnpt.vsp.module.tournament.dto.OutingRosterEntryRequest;
import vnpt.vsp.module.tournament.dto.ScoreEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryRequest;
import vnpt.vsp.module.tournament.dto.TechnicalEntryResponse;
import vnpt.vsp.module.tournament.dto.TournamentPlayerResponse;
import vnpt.vsp.module.tournament.scoring.OutingRules;

import java.util.List;
import java.util.UUID;

/**
 * Running a club outing, over HTTP.
 *
 * Split from {@link TournamentController} because the audiences differ: that
 * one is registration and scheduling, spread over weeks. These endpoints are
 * what an organiser hits on the day, and two of them —
 * {@code POST /scores} and {@code GET /results} — are the entire critical
 * path between the last flight coming in and the prizes being read out.
 *
 * Scores are saved in batches rather than one player at a time so that a
 * flight's four cards go up in one request, and so two people typing two
 * different flights never contend.
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/outing")
public class OutingController {

    private static final Logger log = LoggerFactory.getLogger(OutingController.class);

    private final OutingService outingService;

    public OutingController(OutingService outingService) {
        this.outingService = outingService;
    }

    // ─── Rules ──────────────────────────────────────────────────────────────

    @GetMapping("/rules")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<OutingRules> getRules(@PathVariable UUID tournamentId) {
        return ResponseEntity.ok(outingService.getRules(tournamentId));
    }

    @PutMapping("/rules")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<OutingRules> saveRules(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @Valid @RequestBody OutingRules rules) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("PUT /tournaments/{}/outing/rules - accountId={}", tournamentId, accountId);
        return ResponseEntity.ok(outingService.saveRules(tournamentId, rules, accountId));
    }

    // ─── Roster ─────────────────────────────────────────────────────────────

    @GetMapping("/roster")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<TournamentPlayerResponse>> roster(@PathVariable UUID tournamentId) {
        return ResponseEntity.ok(outingService.roster(tournamentId));
    }

    @PutMapping("/roster")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<TournamentPlayerResponse>> importRoster(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody List<OutingRosterEntryRequest> entries) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("PUT /tournaments/{}/outing/roster - accountId={}, lines={}",
                tournamentId, accountId, entries.size());
        return ResponseEntity.ok(outingService.importRoster(tournamentId, entries, accountId));
    }

    // ─── The day ────────────────────────────────────────────────────────────

    @PostMapping("/scores")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<TournamentPlayerResponse>> saveScores(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody List<ScoreEntryRequest> entries) {

        Long accountId = (Long) authentication.getPrincipal();
        return ResponseEntity.ok(outingService.saveScores(tournamentId, entries, accountId));
    }

    @GetMapping("/technical")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<List<TechnicalEntryResponse>> technicalEntries(@PathVariable UUID tournamentId) {
        return ResponseEntity.ok(outingService.technicalEntries(tournamentId));
    }

    @PostMapping("/technical")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<Void> saveTechnicalEntries(
            Authentication authentication,
            @PathVariable UUID tournamentId,
            @RequestBody List<TechnicalEntryRequest> entries) {

        Long accountId = (Long) authentication.getPrincipal();
        outingService.saveTechnicalEntries(tournamentId, entries, accountId);
        return ResponseEntity.noContent().build();
    }

    /**
     * The prize table as it stands. Safe to poll — this is what the club house
     * screen refreshes while the last flights are still being keyed in.
     */
    @GetMapping("/results")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<OutingResultsResponse> results(@PathVariable UUID tournamentId) {
        return ResponseEntity.ok(outingService.results(tournamentId));
    }

    /** Freeze the table and publish it. This is the quotable one. */
    @PostMapping("/results/publish")
    @PreAuthorize("hasAnyRole('TOURNAMENT_DIRECTOR', 'COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<OutingResultsResponse> publish(
            Authentication authentication,
            @PathVariable UUID tournamentId) {

        Long accountId = (Long) authentication.getPrincipal();
        log.info("POST /tournaments/{}/outing/results/publish - accountId={}", tournamentId, accountId);
        return ResponseEntity.ok(outingService.publish(tournamentId, accountId));
    }
}
