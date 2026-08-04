package vnpt.vsp.module.performance.dispersion;

import vnpt.vsp.module.performance.PerformanceModule;

/**
 * Service interface for dispersion scatter overlay.
 * Per Story 11.1 Slice 2: scatter points and hazard overlay via PostGIS.
 */
@PerformanceModule
public interface DispersionOverlayService {

    /**
     * Get dispersion scatter overlay for a club on a specific hole.
     * Per Story 11.1 Slice 2 AC-3: compare against course hazards.
     *
     * @param golferAccountId authenticated golfer account ID
     * @param bagId           golf bag ID
     * @param clubId          club ID
     * @param holeId          hole ID
     * @param layoutId        layout ID (for tee box reference)
     * @return dispersion overlay with scatter GeoJSON, hazard GeoJSON, and distance metrics
     */
    DispersionOverlayResponse getDispersionOverlay(
            Long golferAccountId,
            Long bagId,
            Long clubId,
            Long holeId,
            Long layoutId);
}
