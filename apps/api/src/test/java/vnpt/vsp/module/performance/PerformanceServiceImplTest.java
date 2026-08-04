package vnpt.vsp.module.performance;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.performance.dto.BagPerformanceResponse;
import vnpt.vsp.module.performance.dto.ClubPerformanceResponse;
import vnpt.vsp.module.performance.entity.ClubPerformance;
import vnpt.vsp.module.performance.entity.ClubPerformanceStats;
import vnpt.vsp.module.performance.repository.ClubPerformanceRepository;
import vnpt.vsp.module.performance.repository.ShotStatsRepository;
import vnpt.vsp.module.bag.repository.ClubRepository;
import vnpt.vsp.module.bag.repository.GolfBagRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link PerformanceServiceImpl} and {@link ClubPerformanceStats}.
 * Per Story 11.1 Slice 1: statistical computation, sample size gate, confidence levels.
 */
@ExtendWith(MockitoExtension.class)
class PerformanceServiceImplTest {

    @Mock
    private ClubPerformanceRepository performanceRepository;

    @Mock
    private ShotStatsRepository shotStatsRepository;

    @Mock
    private ClubRepository clubRepository;

    @Mock
    private GolfBagRepository bagRepository;

    private final ObjectMapper objectMapper = new ObjectMapper();

    // ─── ClubPerformanceStats Sample Quality Tests ──────────────────────────────────

    @Test
    void deriveSampleQuality_insufficient_whenLessThan5Shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(3);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.INSUFFICIENT, stats.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.INSUFFICIENT, stats.getConfidenceLevel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_limited_when5To9Shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(7);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.LIMITED, stats.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.LOW, stats.getConfidenceLevel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_moderate_when10To29Shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(20);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.MODERATE, stats.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.MEDIUM, stats.getConfidenceLevel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_robust_when30OrMoreShots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(30);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.ROBUST, stats.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.HIGH, stats.getConfidenceLevel());
        assertFalse(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_robust_boundary_at30shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(30);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.ROBUST, stats.getSampleSizeLabel());
        assertFalse(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_insufficient_boundary_at4shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(4);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.INSUFFICIENT, stats.getSampleSizeLabel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_limited_boundary_at5shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(5);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.LIMITED, stats.getSampleSizeLabel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_limited_boundary_at9shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(9);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.LIMITED, stats.getSampleSizeLabel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_moderate_boundary_at10shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(10);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.MODERATE, stats.getSampleSizeLabel());
        assertTrue(stats.isRecommendationsLocked());
    }

    @Test
    void deriveSampleQuality_moderate_boundary_at29shots() {
        ClubPerformanceStats stats = new ClubPerformanceStats();
        stats.setSampleSize(29);
        stats.deriveSampleQuality();

        assertEquals(ClubPerformanceStats.SampleSizeLabel.MODERATE, stats.getSampleSizeLabel());
        assertTrue(stats.isRecommendationsLocked());
    }

    // ─── ClubPerformanceStats Empty State Tests ──────────────────────────────────

    @Test
    void empty_returnsZeroStatsWithLockedRecommendations() {
        ClubPerformanceStats stats = ClubPerformanceStats.empty();

        assertEquals(0, stats.getSampleSize());
        assertEquals(ClubPerformanceStats.SampleSizeLabel.INSUFFICIENT, stats.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.INSUFFICIENT, stats.getConfidenceLevel());
        assertTrue(stats.isRecommendationsLocked());
        assertEquals(BigDecimal.ZERO, stats.getCarryAvg());
        assertEquals(BigDecimal.ZERO, stats.getCarryMedian());
        assertEquals(BigDecimal.ZERO, stats.getTotalAvg());
    }

    // ─── ClubPerformance Entity-Domain Conversion Tests ──────────────────────────

    @Test
    void clubPerformance_toDomain_and_fromDomain_roundTrips() {
        ClubPerformance entity = new ClubPerformance();
        entity.setClubId(1L);
        entity.setGolfBagId(2L);
        entity.setGolferAccountId(3L);
        entity.setSampleSize(25);
        entity.setSampleSizeLabel(ClubPerformanceStats.SampleSizeLabel.MODERATE);
        entity.setConfidenceLevel(ClubPerformanceStats.ConfidenceLevel.MEDIUM);
        entity.setRecommendationsLocked(true);
        entity.setCarryAvg(BigDecimal.valueOf(185.50));
        entity.setCarryMedian(BigDecimal.valueOf(183.00));
        entity.setCarryStdDev(BigDecimal.valueOf(8.25));
        entity.setCarryMin(BigDecimal.valueOf(165.00));
        entity.setCarryMax(BigDecimal.valueOf(210.00));
        entity.setTotalAvg(BigDecimal.valueOf(220.00));
        entity.setTotalMedian(BigDecimal.valueOf(218.00));
        entity.setTotalStdDev(BigDecimal.valueOf(10.50));
        entity.setTotalMin(BigDecimal.valueOf(195.00));
        entity.setTotalMax(BigDecimal.valueOf(250.00));
        entity.setLeftRightAvg(BigDecimal.valueOf(2.50));
        entity.setLeftRightStdDev(BigDecimal.valueOf(4.00));
        entity.setShortLongAvg(BigDecimal.valueOf(-1.20));
        entity.setShortLongStdDev(BigDecimal.valueOf(3.50));
        entity.setComputedAt(Instant.now());

        ClubPerformanceStats domain = entity.toDomain();

        assertEquals(25, domain.getSampleSize());
        assertEquals(ClubPerformanceStats.SampleSizeLabel.MODERATE, domain.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.MEDIUM, domain.getConfidenceLevel());
        assertTrue(domain.isRecommendationsLocked());
        assertEquals(BigDecimal.valueOf(185.50), domain.getCarryAvg());
        assertEquals(BigDecimal.valueOf(183.00), domain.getCarryMedian());
        assertEquals(BigDecimal.valueOf(8.25), domain.getCarryStdDev());
        assertEquals(BigDecimal.valueOf(220.00), domain.getTotalAvg());
        assertEquals(BigDecimal.valueOf(2.50), domain.getLeftRightAvg());
        assertEquals(BigDecimal.valueOf(-1.20), domain.getShortLongAvg());
    }

    @Test
    void clubPerformance_fromDomain_populatesAllFields() {
        ClubPerformanceStats domain = new ClubPerformanceStats();
        domain.setSampleSize(30);
        domain.deriveSampleQuality();
        domain.setCarryAvg(BigDecimal.valueOf(190.00));
        domain.setCarryMedian(BigDecimal.valueOf(188.00));
        domain.setCarryStdDev(BigDecimal.valueOf(7.50));
        domain.setCarryMin(BigDecimal.valueOf(170.00));
        domain.setCarryMax(BigDecimal.valueOf(215.00));
        domain.setTotalAvg(BigDecimal.valueOf(225.00));
        domain.setTotalMedian(BigDecimal.valueOf(222.00));
        domain.setTotalStdDev(BigDecimal.valueOf(9.00));
        domain.setTotalMin(BigDecimal.valueOf(200.00));
        domain.setTotalMax(BigDecimal.valueOf(255.00));
        domain.setLeftRightAvg(BigDecimal.valueOf(1.50));
        domain.setLeftRightStdDev(BigDecimal.valueOf(3.00));
        domain.setShortLongAvg(BigDecimal.valueOf(-0.50));
        domain.setShortLongStdDev(BigDecimal.valueOf(2.50));

        ClubPerformance entity = new ClubPerformance();
        entity.setClubId(5L);
        entity.setGolfBagId(10L);
        entity.setGolferAccountId(100L);
        entity.fromDomain(domain);

        assertEquals(5L, entity.getClubId());
        assertEquals(10L, entity.getGolfBagId());
        assertEquals(100L, entity.getGolferAccountId());
        assertEquals(30, entity.getSampleSize());
        assertEquals(ClubPerformanceStats.SampleSizeLabel.ROBUST, entity.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.HIGH, entity.getConfidenceLevel());
        assertFalse(entity.isRecommendationsLocked());
        assertEquals(BigDecimal.valueOf(190.00), entity.getCarryAvg());
        assertEquals(BigDecimal.valueOf(225.00), entity.getTotalAvg());
        assertEquals(BigDecimal.valueOf(1.50), entity.getLeftRightAvg());
        assertEquals(BigDecimal.valueOf(-0.50), entity.getShortLongAvg());
    }

    // ─── ClubPerformanceResponse Factory Tests ────────────────────────────────────

    @Test
    void clubPerformanceResponse_fromEntity_preservesAllFields() {
        ClubPerformance entity = new ClubPerformance();
        entity.setClubId(1L);
        entity.setGolfBagId(2L);
        entity.setGolferAccountId(3L);
        entity.setSampleSize(15);
        entity.setSampleSizeLabel(ClubPerformanceStats.SampleSizeLabel.MODERATE);
        entity.setConfidenceLevel(ClubPerformanceStats.ConfidenceLevel.MEDIUM);
        entity.setRecommendationsLocked(true);
        entity.setCarryAvg(BigDecimal.valueOf(180.00));
        entity.setCarryMedian(BigDecimal.valueOf(178.00));
        entity.setCarryStdDev(BigDecimal.valueOf(6.00));
        entity.setCarryMin(BigDecimal.valueOf(160.00));
        entity.setCarryMax(BigDecimal.valueOf(200.00));
        entity.setTotalAvg(BigDecimal.valueOf(215.00));
        entity.setTotalMedian(BigDecimal.valueOf(212.00));
        entity.setTotalStdDev(BigDecimal.valueOf(8.00));
        entity.setTotalMin(BigDecimal.valueOf(190.00));
        entity.setTotalMax(BigDecimal.valueOf(240.00));
        entity.setLeftRightAvg(BigDecimal.valueOf(3.00));
        entity.setLeftRightStdDev(BigDecimal.valueOf(5.00));
        entity.setShortLongAvg(BigDecimal.valueOf(-2.00));
        entity.setShortLongStdDev(BigDecimal.valueOf(4.00));
        entity.setComputedAt(Instant.parse("2026-08-01T10:00:00Z"));
        entity.setBasedOnShotAt(Instant.parse("2026-08-01T09:55:00Z"));

        ClubPerformanceResponse response = ClubPerformanceResponse.fromEntity(entity);

        assertEquals(1L, response.getClubId());
        assertEquals(2L, response.getBagId());
        assertEquals(15, response.getSampleSize());
        assertEquals(ClubPerformanceStats.SampleSizeLabel.MODERATE, response.getSampleSizeLabel());
        assertEquals(ClubPerformanceStats.ConfidenceLevel.MEDIUM, response.getConfidenceLevel());
        assertTrue(response.isRecommendationsLocked());
        assertEquals(BigDecimal.valueOf(180.00), response.getCarryAvg());
        assertEquals(BigDecimal.valueOf(178.00), response.getCarryMedian());
        assertEquals(BigDecimal.valueOf(6.00), response.getCarryStdDev());
        assertEquals(BigDecimal.valueOf(160.00), response.getCarryMin());
        assertEquals(BigDecimal.valueOf(200.00), response.getCarryMax());
        assertEquals(BigDecimal.valueOf(215.00), response.getTotalAvg());
        assertEquals(BigDecimal.valueOf(212.00), response.getTotalMedian());
        assertEquals(BigDecimal.valueOf(8.00), response.getTotalStdDev());
        assertEquals(BigDecimal.valueOf(190.00), response.getTotalMin());
        assertEquals(BigDecimal.valueOf(240.00), response.getTotalMax());
        assertEquals(BigDecimal.valueOf(3.00), response.getLeftRightAvg());
        assertEquals(BigDecimal.valueOf(5.00), response.getLeftRightStdDev());
        assertEquals(BigDecimal.valueOf(-2.00), response.getShortLongAvg());
        assertEquals(BigDecimal.valueOf(4.00), response.getShortLongStdDev());
        assertEquals(Instant.parse("2026-08-01T10:00:00Z"), response.getComputedAt());
        assertEquals(Instant.parse("2026-08-01T09:55:00Z"), response.getBasedOnShotAt());
    }

    @Test
    void bagPerformanceResponse_fromEntities_computesCorrectly() {
        ClubPerformance entity1 = new ClubPerformance();
        entity1.setClubId(1L);
        entity1.setGolfBagId(5L);
        entity1.setGolferAccountId(100L);
        entity1.setSampleSize(30);
        entity1.setSampleSizeLabel(ClubPerformanceStats.SampleSizeLabel.ROBUST);
        entity1.setConfidenceLevel(ClubPerformanceStats.ConfidenceLevel.HIGH);
        entity1.setRecommendationsLocked(false);
        entity1.setCarryAvg(BigDecimal.valueOf(200.00));

        ClubPerformance entity2 = new ClubPerformance();
        entity2.setClubId(2L);
        entity2.setGolfBagId(5L);
        entity2.setGolferAccountId(100L);
        entity2.setSampleSize(10);
        entity2.setSampleSizeLabel(ClubPerformanceStats.SampleSizeLabel.MODERATE);
        entity2.setConfidenceLevel(ClubPerformanceStats.ConfidenceLevel.MEDIUM);
        entity2.setRecommendationsLocked(true);
        entity2.setCarryAvg(BigDecimal.valueOf(150.00));

        BagPerformanceResponse response = BagPerformanceResponse.fromEntities(5L, List.of(entity1, entity2));

        assertEquals(5L, response.getBagId());
        assertEquals(2, response.getClubs().size());
        assertEquals(1L, response.getClubs().get(0).getClubId());
        assertEquals(2L, response.getClubs().get(1).getClubId());
        assertEquals(BigDecimal.valueOf(200.00), response.getClubs().get(0).getCarryAvg());
        assertEquals(BigDecimal.valueOf(150.00), response.getClubs().get(1).getCarryAvg());
    }
}
