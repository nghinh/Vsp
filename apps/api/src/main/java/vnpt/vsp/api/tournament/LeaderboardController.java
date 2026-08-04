package vnpt.vsp.api.tournament;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.tournament.dto.LeaderboardResponse;
import vnpt.vsp.module.tournament.service.LeaderboardService;

import java.util.UUID;

/**
 * REST controller for leaderboard endpoints.
 * Per Story 12.1 Slice E.
 *
 * Endpoints:
 * - GET /tournaments/{id}/leaderboard     — current standings (polling)
 * - GET /tournaments/{id}/leaderboard/stream — SSE stream for live updates
 */
@RestController
@RequestMapping("/tournaments/{tournamentId}/leaderboard")
public class LeaderboardController {

    private static final Logger log = LoggerFactory.getLogger(LeaderboardController.class);

    private final LeaderboardService leaderboardService;

    public LeaderboardController(LeaderboardService leaderboardService) {
        this.leaderboardService = leaderboardService;
    }

    /**
     * Get current leaderboard (polling fallback for degraded connectivity).
     */
    @GetMapping
    public ResponseEntity<LeaderboardResponse> getLeaderboard(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/leaderboard", tournamentId);
        LeaderboardResponse response = leaderboardService.getLeaderboard(tournamentId);
        return ResponseEntity.ok(response);
    }

    /**
     * SSE stream for live leaderboard updates.
     * Per Story 12.1 AC: Live leaderboard handles expected concurrency and degraded connectivity.
     */
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public ResponseEntity<Void> streamLeaderboard(@PathVariable UUID tournamentId) {
        log.info("GET /tournaments/{}/leaderboard/stream - SSE connection opened", tournamentId);
        leaderboardService.subscribe(tournamentId);
        return ResponseEntity.ok().build();
    }
}
