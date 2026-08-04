package vnpt.vsp.module.performance.dispersion;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.performance.dispersion.DispersionOverlayResponse;

/**
 * REST controller for dispersion overlay GeoJSON endpoints.
 * Per Story 11.1 Slice 2 AC-3: dispersion overlays can be compared against course hazards.
 */
@RestController
@RequestMapping("/bags/{bagId}/clubs/{clubId}")
@vnpt.vsp.module.performance.PerformanceModule
public class DispersionController {

    private final DispersionOverlayService dispersionOverlayService;

    public DispersionController(DispersionOverlayService dispersionOverlayService) {
        this.dispersionOverlayService = dispersionOverlayService;
    }

    /**
     * GET /bags/{bagId}/clubs/{clubId}/dispersion?holeId={holeId}&layoutId={layoutId}
     *
     * <p>Returns dispersion scatter overlay with GeoJSON FeatureCollections.
     * Per Story 11.1 Slice 2 AC-3: scatter points + hazard polygons projected to hole local coords.
     *
     * @param bagId   golf bag ID
     * @param clubId club ID
     * @param holeId hole ID (required)
     * @param layoutId layout ID (required — for tee box reference)
     * @return dispersion overlay with scatter GeoJSON, hazard GeoJSON, and distance metrics
     */
    @GetMapping("/dispersion")
    public ResponseEntity<DispersionOverlayResponse> getDispersionOverlay(
            Authentication authentication,
            @PathVariable Long bagId,
            @PathVariable Long clubId,
            @RequestParam Long holeId,
            @RequestParam Long layoutId) {
        Long accountId = (Long) authentication.getPrincipal();
        DispersionOverlayResponse response = dispersionOverlayService.getDispersionOverlay(
                accountId, bagId, clubId, holeId, layoutId);
        return ResponseEntity.ok(response);
    }
}
