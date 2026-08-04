package vnpt.vsp.module.performance;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.performance.dto.BagPerformanceResponse;
import vnpt.vsp.module.performance.dto.ClubPerformanceResponse;

/**
 * REST controller for club performance statistics endpoints.
 * Per Story 11.1 Slice 1 AC-1, AC-2.
 */
@RestController
@RequestMapping("/bags/{bagId}")
@vnpt.vsp.module.performance.PerformanceModule
public class PerformanceController {

    private final PerformanceService performanceService;

    public PerformanceController(PerformanceService performanceService) {
        this.performanceService = performanceService;
    }

    // ─── Per-Club Performance ────────────────────────────────────────────────

    /**
     * GET /bags/{bagId}/clubs/{clubId}/performance
     *
     * <p>Returns performance statistics for a specific club.
     * Per Story 11.1 AC-1: avg/median carry, total, variability, left/right, short/long, confidence.
     * Per Story 11.1 AC-2: low sample sizes are labeled and do not unlock recommendations.
     *
     * @param bagId  golf bag ID
     * @param clubId club ID
     * @return club performance stats (always returns 200, stats may be empty/insufficient)
     */
    @GetMapping("/clubs/{clubId}/performance")
    public ResponseEntity<ClubPerformanceResponse> getClubPerformance(
            Authentication authentication,
            @PathVariable Long bagId,
            @PathVariable Long clubId) {
        Long accountId = (Long) authentication.getPrincipal();
        ClubPerformanceResponse response = performanceService.getClubPerformance(accountId, bagId, clubId);
        return ResponseEntity.ok(response);
    }

    // ─── Bag-Level Batch ─────────────────────────────────────────────────────

    /**
     * GET /bags/{bagId}/performance
     *
     * <p>Returns performance statistics for all clubs in a bag.
     * Per Story 11.1 Slice 1: batch endpoint.
     *
     * @param bagId golf bag ID
     * @return bag performance with all club stats
     */
    @GetMapping("/performance")
    public ResponseEntity<BagPerformanceResponse> getBagPerformance(
            Authentication authentication,
            @PathVariable Long bagId) {
        Long accountId = (Long) authentication.getPrincipal();
        BagPerformanceResponse response = performanceService.getBagPerformance(accountId, bagId);
        return ResponseEntity.ok(response);
    }
}
