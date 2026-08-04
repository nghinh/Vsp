package vnpt.vsp.module.performance.dispersion;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.bag.entity.Club;
import vnpt.vsp.module.bag.entity.GolfBag;
import vnpt.vsp.module.bag.repository.ClubRepository;
import vnpt.vsp.module.bag.repository.GolfBagRepository;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.performance.dispersion.DispersionPoint.DispersionResult;
import vnpt.vsp.module.shot.entity.Shot;
import vnpt.vsp.module.shot.repository.ShotRepository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Implementation of {@link DispersionOverlayService}.
 * Per Story 11.1 Slice 2: scatter points and hazard overlay via PostGIS.
 */
@Service
@Transactional(readOnly = true)
@vnpt.vsp.module.performance.PerformanceModule
public class DispersionOverlayServiceImpl implements DispersionOverlayService {

    private static final Logger log = LoggerFactory.getLogger(DispersionOverlayServiceImpl.class);
    private static final int DISTANCE_SCALE = 2;
    private static final double METERS_PER_DEGREE_LAT = 111320.0;

    private final ShotRepository shotRepository;
    private final HoleRepository holeRepository;
    private final ClubRepository clubRepository;
    private final GolfBagRepository bagRepository;
    private final ObjectMapper objectMapper;

    public DispersionOverlayServiceImpl(
            ShotRepository shotRepository,
            HoleRepository holeRepository,
            ClubRepository clubRepository,
            GolfBagRepository bagRepository,
            ObjectMapper objectMapper) {
        this.shotRepository = shotRepository;
        this.holeRepository = holeRepository;
        this.clubRepository = clubRepository;
        this.bagRepository = bagRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    public DispersionOverlayResponse getDispersionOverlay(
            Long golferAccountId,
            Long bagId,
            Long clubId,
            Long holeId,
            Long layoutId) {

        log.debug("getDispersionOverlay golferAccountId={} bagId={} clubId={} holeId={} layoutId={}",
                golferAccountId, bagId, clubId, holeId, layoutId);

        // Validate bag belongs to golfer
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        // Validate club belongs to bag
        Club club = clubRepository.findByIdAndGolfBagId(clubId, bagId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CLUB_001));

        // Validate hole exists
        Hole hole = holeRepository.findById(holeId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.HOLE_001));

        // Get all shots for this club on this hole
        List<Shot> shots = getShotsForHole(clubId, golferAccountId, holeId);
        if (shots.isEmpty()) {
            throw new VspApiException(VspErrorCode.PERF_004);
        }

        // Compute scatter points
        List<DispersionPoint> dispersionPoints = computeDispersionPoints(shots, hole);

        // Build scatter GeoJSON
        Map<String, Object> scatterGeoJSON = buildScatterGeoJSON(dispersionPoints);

        // Get hazard geometries from hole
        Map<String, Object> hazardGeoJSON = buildHazardGeoJSON(hole);

        // Compute center of scatter
        double centerX = dispersionPoints.stream().mapToDouble(DispersionPoint::getRelativeX).average().orElse(0);
        double centerY = dispersionPoints.stream().mapToDouble(DispersionPoint::getRelativeY).average().orElse(0);

        // Compute outcome counts
        Map<String, Integer> outcomeCounts = dispersionPoints.stream()
                .collect(Collectors.groupingBy(
                        p -> p.getResult().name(),
                        Collectors.collectingAndThen(Collectors.counting(), Long::intValue)));

        // Find nearest hazard
        BigDecimal centerToHazard = null;
        String nearestHazardType = null;
        if (!dispersionPoints.isEmpty()) {
            double[] nearest = findNearestHazard(hole, centerX, centerY);
            if (nearest != null) {
                centerToHazard = BigDecimal.valueOf(nearest[0]).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
                nearestHazardType = (String) holeRepository.findById(holeId)
                        .map(h -> "HAZARD")
                        .orElse("UNKNOWN");
            }
        }

        DispersionOverlayResponse response = new DispersionOverlayResponse();
        response.setClubId(clubId);
        response.setBagId(bagId);
        response.setHoleId(holeId);
        response.setLayoutId(layoutId);
        response.setShotCount(dispersionPoints.size());
        response.setComputedAt(Instant.now());
        response.setScatterGeoJSON(scatterGeoJSON);
        response.setHazardGeoJSON(hazardGeoJSON);
        response.setCenterX(BigDecimal.valueOf(centerX).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
        response.setCenterY(BigDecimal.valueOf(centerY).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
        response.setCenterToHazardMeters(centerToHazard);
        response.setNearestHazardType(nearestHazardType);
        response.setOutcomeCounts(outcomeCounts);

        return response;
    }

    // ─── Shot Query ─────────────────────────────────────────────────────────

    private List<Shot> getShotsForHole(Long clubId, Long golferAccountId, Long holeId) {
        // Query shots for this club and hole
        // In a full implementation, this would use a native query with PostGIS
        // For now, use a simple in-memory filter based on shot data
        return shotRepository.findAll().stream()
                .filter(s -> s.getClubId() != null && s.getClubId().equals(clubId))
                .filter(s -> s.getPlayerId() != null && s.getPlayerId().equals(golferAccountId))
                .filter(s -> s.getDeletedAt() == null)
                .filter(s -> s.getHoleNumber() != null && s.getHoleNumber().equals(holeId.intValue()))
                .toList();
    }

    // ─── Dispersion Point Computation ───────────────────────────────────────

    /**
     * Compute normalized dispersion points for a list of shots.
     * Uses hole's tee box as origin and hole direction for normalization.
     */
    private List<DispersionPoint> computeDispersionPoints(List<Shot> shots, Hole hole) {
        List<DispersionPoint> points = new ArrayList<>();

        // Get hole geometry for coordinate transformation
        double[] teeCoords = getTeeCoordinates(hole);
        double[] greenCoords = getGreenCoordinates(hole);

        if (teeCoords == null || greenCoords == null) {
            log.warn("Cannot compute dispersion: missing hole geometry for holeId={}", hole.getId());
            return points;
        }

        // Direction vector from tee to green
        double dirX = greenCoords[0] - teeCoords[0];
        double dirY = greenCoords[1] - teeCoords[1];
        double holeLength = Math.sqrt(dirX * dirX + dirY * dirY);
        if (holeLength < 1) holeLength = 1;

        // Unit vectors: along hole direction and perpendicular
        double alongX = dirX / holeLength;
        double alongY = dirY / holeLength;
        double perpX = -alongY;
        double perpY = alongX;

        for (Shot shot : shots) {
            try {
                double[] startCoords = parseGeoJSONPoint(shot.getStartLocation());
                double[] endCoords = parseGeoJSONPoint(shot.getEndLocation());

                if (startCoords == null || endCoords == null) continue;

                // Project end location onto hole-local coordinates
                double dx = endCoords[0] - teeCoords[0];
                double dy = endCoords[1] - teeCoords[1];

                double relativeX = dx * perpX + dy * perpY; // lateral deviation
                double relativeY = dx * alongX + dy * alongY; // distance along hole

                DispersionResult result = classifyResult(shot, hole);

                DispersionPoint point = DispersionPoint.create(relativeX, relativeY, result);
                point.setShotAt(shot.getEndedAt());
                points.add(point);

            } catch (Exception e) {
                log.warn("Failed to compute dispersion point for shotId={}: {}", shot.getId(), e.getMessage());
            }
        }

        return points;
    }

    private DispersionResult classifyResult(Shot shot, Hole hole) {
        if (shot.getResult() == null) return DispersionResult.UNKNOWN;

        Shot.Result result = shot.getResult();
        if (result == Shot.Result.fairway_hit) return DispersionResult.FAIRWAY;
        if (result == Shot.Result.in_bunker) return DispersionResult.BUNKER;
        if (result == Shot.Result.in_water) return DispersionResult.WATER;
        if (result == Shot.Result.out_of_bounds) return DispersionResult.OUT_OF_BOUNDS;
        if (result == Shot.Result.green_hit || result == Shot.Result.hole_out
                || result == Shot.Result.chip_in || result == Shot.Result.in_the_hole) {
            return DispersionResult.GREEN;
        }

        // Check if in rough using lie
        if (shot.getLie() != null) {
            Shot.Lie lie = shot.getLie();
            if (lie == Shot.Lie.rough || lie == Shot.Lie.native_rough
                    || lie == Shot.Lie.primary_rough || lie == Shot.Lie.secondary_rough) {
                return DispersionResult.ROUGH;
            }
        }

        return DispersionResult.UNKNOWN;
    }

    // ─── GeoJSON Generation ────────────────────────────────────────────────

    private Map<String, Object> buildScatterGeoJSON(List<DispersionPoint> points) {
        List<Map<String, Object>> features = new ArrayList<>();

        for (DispersionPoint point : points) {
            Map<String, Object> geometry = new LinkedHashMap<>();
            geometry.put("type", "Point");
            geometry.put("coordinates", List.of(point.getRelativeX(), point.getRelativeY()));

            Map<String, Object> properties = new LinkedHashMap<>();
            properties.put("result", point.getResult().name());
            if (point.getShotAt() != null) {
                properties.put("shotAt", point.getShotAt().toString());
            }

            Map<String, Object> feature = new LinkedHashMap<>();
            feature.put("type", "Feature");
            feature.put("geometry", geometry);
            feature.put("properties", properties);

            features.add(feature);
        }

        Map<String, Object> featureCollection = new LinkedHashMap<>();
        featureCollection.put("type", "FeatureCollection");
        featureCollection.put("features", features);

        return featureCollection;
    }

    private Map<String, Object> buildHazardGeoJSON(Hole hole) {
        List<Map<String, Object>> features = new ArrayList<>();

        // Bunkers
        if (hole.getDataQuality() != null) {
            // In a full implementation, we'd query the actual hazard tables
            // (bunkers, water_hazards, out_of_bounds) joined with hole
            // For now, return an empty feature collection
        }

        Map<String, Object> featureCollection = new LinkedHashMap<>();
        featureCollection.put("type", "FeatureCollection");
        featureCollection.put("features", features);

        return featureCollection;
    }

    // ─── Nearest Hazard ────────────────────────────────────────────────────

    private double[] findNearestHazard(Hole hole, double centerX, double centerY) {
        // In a full PostGIS implementation:
        // SELECT ST_Distance(
        //   ST_SetSRID(ST_MakePoint(:cx, :cy), 4326)::geography,
        //   ST_SetSRID(h.geom, 4326)::geography
        // ) as distance, h.hazard_type
        // FROM hazards h WHERE h.hole_id = :holeId
        // ORDER BY distance ASC LIMIT 1;

        // Simplified: return null (no PostGIS distance computation in this slice)
        return null;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private double[] getTeeCoordinates(Hole hole) {
        if (hole.getTeeingGroundLocation() == null) return null;
        return parseGeoJSONPoint(hole.getTeeingGroundLocation());
    }

    private double[] getGreenCoordinates(Hole hole) {
        if (hole.getGreenLocation() == null) return null;
        return parseGeoJSONPoint(hole.getGreenLocation());
    }

    private double[] parseGeoJSONPoint(String geoJson) {
        if (geoJson == null) return null;
        try {
            var node = objectMapper.readTree(geoJson);
            var coords = node.get("coordinates");
            if (coords == null || !coords.isArray() || coords.size() < 2) return null;
            return new double[] { coords.get(0).asDouble(), coords.get(1).asDouble() };
        } catch (JsonProcessingException e) {
            return null;
        }
    }
}
