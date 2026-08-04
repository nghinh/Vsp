package vnpt.vsp.module.performance;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
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
import vnpt.vsp.module.performance.dto.BagPerformanceResponse;
import vnpt.vsp.module.performance.dto.ClubPerformanceResponse;
import vnpt.vsp.module.performance.entity.ClubPerformance;
import vnpt.vsp.module.performance.entity.ClubPerformanceStats;
import vnpt.vsp.module.performance.repository.ClubPerformanceRepository;
import vnpt.vsp.module.performance.repository.ShotStatsRepository;
import vnpt.vsp.module.shot.entity.Shot;
import vnpt.vsp.module.shot.repository.ShotRepository;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Implementation of {@link PerformanceService}.
 * Per Story 11.1 Slice 1: computes and caches club performance statistics.
 */
@Service
@vnpt.vsp.module.performance.PerformanceModule
public class PerformanceServiceImpl implements PerformanceService {

    private static final Logger log = LoggerFactory.getLogger(PerformanceServiceImpl.class);
    private static final int DISTANCE_SCALE = 2;
    private static final MathContext MATH_CONTEXT = new MathContext(10, RoundingMode.HALF_UP);

    private final ClubPerformanceRepository performanceRepository;
    private final ShotStatsRepository shotStatsRepository;
    private final ClubRepository clubRepository;
    private final GolfBagRepository bagRepository;
    private final ObjectMapper objectMapper;

    public PerformanceServiceImpl(
            ClubPerformanceRepository performanceRepository,
            ShotStatsRepository shotStatsRepository,
            ClubRepository clubRepository,
            GolfBagRepository bagRepository,
            ObjectMapper objectMapper) {
        this.performanceRepository = performanceRepository;
        this.shotStatsRepository = shotStatsRepository;
        this.clubRepository = clubRepository;
        this.bagRepository = bagRepository;
        this.objectMapper = objectMapper;
    }

    // ─── Per-Club Performance ────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public ClubPerformanceResponse getClubPerformance(Long golferAccountId, Long bagId, Long clubId) {
        log.debug("getClubPerformance golferAccountId={} bagId={} clubId={}", golferAccountId, bagId, clubId);

        // Validate bag belongs to golfer
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        // Validate club belongs to bag
        Club club = clubRepository.findByIdAndGolfBagId(clubId, bagId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CLUB_001));

        // Check cache
        return performanceRepository.findByClubIdAndGolferAccountId(clubId, golferAccountId)
                .map(entity -> {
                    // Check staleness — recompute if based on older shot
                    Instant mostRecentShot = shotStatsRepository.getMostRecentShotAt(clubId, golferAccountId);
                    if (mostRecentShot != null && entity.getBasedOnShotAt() != null
                            && mostRecentShot.isAfter(entity.getBasedOnShotAt())) {
                        log.debug("Cache stale for clubId={}, recomputing", clubId);
                        return computeAndCache(clubId, bagId, golferAccountId);
                    }
                    return ClubPerformanceResponse.fromEntity(entity);
                })
                .orElseGet(() -> computeAndCache(clubId, bagId, golferAccountId));
    }

    // ─── Bag-Level Batch ─────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public BagPerformanceResponse getBagPerformance(Long golferAccountId, Long bagId) {
        log.debug("getBagPerformance golferAccountId={} bagId={}", golferAccountId, bagId);

        // Validate bag belongs to golfer
        GolfBag bag = bagRepository.findByIdAndGolferAccountId(bagId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.BAG_001));

        List<Club> clubs = clubRepository.findByGolfBagId(bagId);
        List<ClubPerformance> performances = clubs.stream()
                .map(club -> getOrComputeForClub(club.getId(), bagId, golferAccountId))
                .toList();

        return BagPerformanceResponse.fromEntities(bagId, performances);
    }

    private ClubPerformance getOrComputeForClub(Long clubId, Long bagId, Long golferAccountId) {
        ClubPerformance cached = performanceRepository.findByClubIdAndGolferAccountId(clubId, golferAccountId)
                .orElse(null);

        if (cached != null) {
            Instant mostRecentShot = shotStatsRepository.getMostRecentShotAt(clubId, golferAccountId);
            if (mostRecentShot == null || cached.getBasedOnShotAt() == null
                    || mostRecentShot.isAfter(cached.getBasedOnShotAt())) {
                // Cache stale or missing — recompute
                return computeAndCacheEntity(clubId, bagId, golferAccountId);
            }
            return cached;
        }
        return computeAndCacheEntity(clubId, bagId, golferAccountId);
    }

    // ─── Cache Invalidation ─────────────────────────────────────────────────

    @Override
    @Transactional
    public void invalidateIfStale(Long clubId, UUID shotId, Instant mostRecentShotAt) {
        log.debug("invalidateIfStale clubId={} shotId={}", clubId, shotId);
        performanceRepository.invalidateIfStale(clubId, mostRecentShotAt);
    }

    // ─── Core Computation ────────────────────────────────────────────────────

    /**
     * Compute stats and cache, returning the entity.
     */
    private ClubPerformance computeAndCacheEntity(Long clubId, Long bagId, Long golferAccountId) {
        ClubPerformanceStats stats = computeStats(clubId, golferAccountId);
        Instant now = Instant.now();
        Instant mostRecentShot = shotStatsRepository.getMostRecentShotAt(clubId, golferAccountId);

        ClubPerformance entity = performanceRepository.findByClubId(clubId)
                .orElseGet(() -> {
                    ClubPerformance newEntity = new ClubPerformance();
                    newEntity.setClubId(clubId);
                    newEntity.setGolfBagId(bagId);
                    newEntity.setGolferAccountId(golferAccountId);
                    return newEntity;
                });

        entity.setComputedAt(now);
        entity.setBasedOnShotAt(mostRecentShot);
        entity.fromDomain(stats);
        entity = performanceRepository.save(entity);
        return entity;
    }

    /**
     * Compute stats and cache, returning the API response.
     */
    private ClubPerformanceResponse computeAndCache(Long clubId, Long bagId, Long golferAccountId) {
        ClubPerformance entity = computeAndCacheEntity(clubId, bagId, golferAccountId);
        return ClubPerformanceResponse.fromEntity(entity);
    }

    /**
     * Compute full ClubPerformanceStats from raw shot data.
     */
    ClubPerformanceStats computeStats(Long clubId, Long golferAccountId) {
        int sampleSize = (int) shotStatsRepository.countShotsByClubAndGolfer(clubId, golferAccountId);

        if (sampleSize == 0) {
            return ClubPerformanceStats.empty();
        }

        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(sampleSize);
        stats.deriveSampleQuality();

        // Carry aggregates
        Object[] carryAgg = shotStatsRepository.computeCarryAggregates(clubId, golferAccountId);
        if (carryAgg != null && carryAgg.length == 4) {
            stats.setCarryAvg(toBD(carryAgg[0]));
            stats.setCarryMin(toBD(carryAgg[1]));
            stats.setCarryMax(toBD(carryAgg[2]));
            stats.setCarryStdDev(toBD(carryAgg[3]));
        }

        // Total aggregates
        Object[] totalAgg = shotStatsRepository.computeTotalAggregates(clubId, golferAccountId);
        if (totalAgg != null && totalAgg.length == 4) {
            stats.setTotalAvg(toBD(totalAgg[0]));
            stats.setTotalMin(toBD(totalAgg[1]));
            stats.setTotalMax(toBD(totalAgg[2]));
            stats.setTotalStdDev(toBD(totalAgg[3]));
        }

        // Median carry
        List<BigDecimal> sortedCarry = shotStatsRepository.getSortedCarryDistances(clubId, golferAccountId);
        if (!sortedCarry.isEmpty()) {
            stats.setCarryMedian(computeMedian(sortedCarry));
        }

        // Median total
        List<BigDecimal> sortedTotal = shotStatsRepository.getSortedTotalDistances(clubId, golferAccountId);
        if (!sortedTotal.isEmpty()) {
            stats.setTotalMedian(computeMedian(sortedTotal));
        }

        // Directional deviation
        computeDirectionalDeviation(clubId, golferAccountId, stats);

        return stats;
    }

    /**
     * Compute left/right and short/long deviation from shot start/end locations.
     * Left/right: lateral deviation from intended shot line (requires start→end bearing)
     * Short/long: longitudinal deviation from expected distance
     */
    private void computeDirectionalDeviation(Long clubId, Long golferAccountId, ClubPerformanceStats stats) {
        List<Object[]> shotData = shotStatsRepository.getShotsForDeviation(clubId, golferAccountId);
        if (shotData == null || shotData.isEmpty()) {
            stats.setLeftRightAvg(BigDecimal.ZERO);
            stats.setLeftRightStdDev(BigDecimal.ZERO);
            stats.setShortLongAvg(BigDecimal.ZERO);
            stats.setShortLongStdDev(BigDecimal.ZERO);
            return;
        }

        // For each shot, the intended line is from start_location toward the average end location
        // or toward a target direction. Here we approximate:
        // - Lateral deviation = perpendicular distance from start→end line to average end point
        // - Longitudinal deviation = difference between actual distance and average distance

        // Simple approximation: use the bearing from start to end as the "intended" direction
        // Then project each end point onto cross-track and along-track components

        double sumLateral = 0;
        double sumLongitudinal = 0;
        double avgDistance = stats.getCarryAvg() != null ? stats.getCarryAvg().doubleValue() : 0;

        for (Object[] row : shotData) {
            String startLocJson = (String) row[1];
            String endLocJson = (String) row[2];

            if (startLocJson == null || endLocJson == null) continue;

            try {
                double[] startCoords = parseGeoJSONPoint(startLocJson);
                double[] endCoords = parseGeoJSONPoint(endLocJson);

                if (startCoords == null || endCoords == null) continue;

                // Bearing from start to end (radians)
                double bearing = Math.atan2(endCoords[0] - startCoords[0], endCoords[1] - startCoords[1]);

                // Perpendicular (lateral) = cross-track error approximated by lateral offset
                // For short/long, we use actual distance vs average
                BigDecimal distance = row[0] != null ? toBD(row[0]) : BigDecimal.ZERO;
                double actualDistance = distance.doubleValue();

                // Simple model: lateral deviation approximated as perpendicular offset
                // Using a simplified spherical approximation (SRID 4326 degrees to meters)
                double lateralMeters = (endCoords[0] - startCoords[0]) * Math.cos(Math.toRadians(startCoords[1])) * 111320;
                double longitudinalMeters = actualDistance - avgDistance;

                sumLateral += lateralMeters;
                sumLongitudinal += longitudinalMeters;

            } catch (Exception e) {
                log.warn("Failed to parse shot location for clubId={}: {}", clubId, e.getMessage());
            }
        }

        double avgLateral = sumLateral / shotData.size();
        double avgLongitudinal = sumLongitudinal / shotData.size();

        // Std dev of lateral deviations
        double sumLatSq = 0;
        double sumLongSq = 0;
        int count = 0;

        for (Object[] row : shotData) {
            String startLocJson = (String) row[1];
            String endLocJson = (String) row[2];
            if (startLocJson == null || endLocJson == null) continue;

            try {
                double[] startCoords = parseGeoJSONPoint(startLocJson);
                double[] endCoords = parseGeoJSONPoint(endLocJson);
                if (startCoords == null || endCoords == null) continue;

                BigDecimal distance = row[0] != null ? toBD(row[0]) : BigDecimal.ZERO;
                double actualDistance = distance.doubleValue();

                double lateralMeters = (endCoords[0] - startCoords[0]) * Math.cos(Math.toRadians(startCoords[1])) * 111320;
                double longitudinalMeters = actualDistance - avgDistance;

                sumLatSq += Math.pow(lateralMeters - avgLateral, 2);
                sumLongSq += Math.pow(longitudinalMeters - avgLongitudinal, 2);
                count++;
            } catch (Exception e) {
                // skip
            }
        }

        double stdDevLateral = count > 1 ? Math.sqrt(sumLatSq / count) : 0;
        double stdDevLongitudinal = count > 1 ? Math.sqrt(sumLongSq / count) : 0;

        stats.setLeftRightAvg(BigDecimal.valueOf(avgLateral).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
        stats.setLeftRightStdDev(BigDecimal.valueOf(stdDevLateral).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
        stats.setShortLongAvg(BigDecimal.valueOf(avgLongitudinal).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
        stats.setShortLongStdDev(BigDecimal.valueOf(stdDevLongitudinal).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP));
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private BigDecimal toBD(Object value) {
        if (value == null) return BigDecimal.ZERO;
        if (value instanceof BigDecimal) return ((BigDecimal) value).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
        if (value instanceof Number) return BigDecimal.valueOf(((Number) value).doubleValue()).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
        return new BigDecimal(value.toString()).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
    }

    private BigDecimal computeMedian(List<BigDecimal> sortedValues) {
        int size = sortedValues.size();
        if (size == 0) return BigDecimal.ZERO;
        if (size % 2 == 0) {
            BigDecimal a = sortedValues.get(size / 2 - 1);
            BigDecimal b = sortedValues.get(size / 2);
            return a.add(b).divide(BigDecimal.valueOf(2), MATH_CONTEXT).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
        } else {
            return sortedValues.get(size / 2).setScale(DISTANCE_SCALE, RoundingMode.HALF_UP);
        }
    }

    /**
     * Parse a GeoJSON Point string: {"type":"Point","coordinates":[lon,lat,elev?]}
     * Returns [lon, lat] array or null on parse failure.
     */
    private double[] parseGeoJSONPoint(String geoJson) {
        try {
            JsonNode node = objectMapper.readTree(geoJson);
            JsonNode coords = node.get("coordinates");
            if (coords == null || !coords.isArray() || coords.size() < 2) return null;
            return new double[] { coords.get(0).asDouble(), coords.get(1).asDouble() };
        } catch (JsonProcessingException e) {
            return null;
        }
    }
}
