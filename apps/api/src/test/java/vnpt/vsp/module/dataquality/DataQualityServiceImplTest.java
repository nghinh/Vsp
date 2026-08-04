package vnpt.vsp.module.dataquality.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.dataquality.dto.DataQualityMetricsDto;
import vnpt.vsp.module.dataquality.dto.DataQualityQueryRequest;
import vnpt.vsp.module.dataquality.repository.DataQualityRepository;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link DataQualityServiceImpl}.
 * Per Story 9.4 Wave 3 — T17 Unit Tests.
 *
 * Covers metric computation logic, query request handling,
 * and edge cases (null filters, empty results).
 */
@ExtendWith(MockitoExtension.class)
class DataQualityServiceImplTest {

    @Mock private DataQualityRepository repository;

    private DataQualityServiceImpl service;

    private static final Long FACILITY_ID = 10L;
    private static final Long COURSE_ID = 101L;
    private static final LocalDate FROM = LocalDate.of(2025, 7, 1);
    private static final LocalDate TO = LocalDate.of(2025, 7, 31);

    @BeforeEach
    void setUp() {
        service = new DataQualityServiceImpl(repository);
    }

    // ─── computeMetrics — happy path ─────────────────────────────────────────

    @Test
    void computeMetrics_returnsAllFields_whenAllDataPresent() {
        when(repository.countHolesWithCompleteLayers(isNull(), isNull())).thenReturn(87L);
        when(repository.countTotalHoles(isNull(), isNull())).thenReturn(100L);
        when(repository.countVerifiedCourses(isNull())).thenReturn(42L);
        when(repository.countTotalCourses(isNull())).thenReturn(50L);
        when(repository.countClassABCourses(isNull())).thenReturn(39L);
        // countCorrectionsInRange
        when(repository.countCorrectionsInRange(any(Instant.class), any(Instant.class), isNull(), isNull()))
            .thenReturn(127L);
        when(repository.avgResolutionTimeSeconds(any(Instant.class), any(Instant.class), isNull(), isNull()))
            .thenReturn(66240.0); // 18.4 hours in seconds
        when(repository.resolutionTimesSeconds(any(Instant.class), any(Instant.class), isNull(), isNull()))
            .thenReturn(List.of(43200.0, 66240.0)); // 12h, 18.4h

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFromDate(FROM);
        request.setToDate(TO);

        DataQualityMetricsDto result = service.computeMetrics(request);

        assertNotNull(result);
        // 87/100 = 87%
        assertEquals(new BigDecimal("87.00"), result.getGeometryCompleteness());
        assertEquals(42L, result.getVerifiedCoursesCount());
        assertEquals(50L, result.getTotalCoursesCount());
        // 39/50 = 78%
        assertEquals(new BigDecimal("78.00"), result.getClassABCoverage());
        assertEquals(127L, result.getCorrectionVolume());
        assertEquals(new BigDecimal("18.40"), result.getAvgResolutionTimeHours());
        // median of [43200, 66240] = (43200 + 66240) / 2 = 54720s = 15.2h
        assertEquals(new BigDecimal("15.20"), result.getMedianResolutionTimeHours());
        assertEquals(FROM.toString(), result.getFromDate());
        assertEquals(TO.toString(), result.getToDate());
    }

    @Test
    void computeMetrics_appliesFacilityFilter_whenProvided() {
        when(repository.countHolesWithCompleteLayers(eq(FACILITY_ID), isNull())).thenReturn(19L);
        when(repository.countTotalHoles(eq(FACILITY_ID), isNull())).thenReturn(20L);
        when(repository.countVerifiedCourses(eq(FACILITY_ID))).thenReturn(20L);
        when(repository.countTotalCourses(eq(FACILITY_ID))).thenReturn(20L);
        when(repository.countClassABCourses(eq(FACILITY_ID))).thenReturn(20L);
        when(repository.countCorrectionsInRange(any(Instant.class), any(Instant.class), isNull(), eq(FACILITY_ID)))
            .thenReturn(5L);
        when(repository.avgResolutionTimeSeconds(any(Instant.class), any(Instant.class), isNull(), eq(FACILITY_ID)))
            .thenReturn(14400.0); // 4 hours
        when(repository.resolutionTimesSeconds(any(Instant.class), any(Instant.class), isNull(), eq(FACILITY_ID)))
            .thenReturn(List.of(14400.0)); // 4h median

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFacilityId(FACILITY_ID);
        request.setFromDate(FROM);
        request.setToDate(TO);

        DataQualityMetricsDto result = service.computeMetrics(request);

        assertEquals(new BigDecimal("95.00"), result.getGeometryCompleteness());
        assertEquals(20L, result.getVerifiedCoursesCount());
        assertEquals(20L, result.getTotalCoursesCount());
        assertEquals(new BigDecimal("100.00"), result.getClassABCoverage());
        assertEquals(5L, result.getCorrectionVolume());
        assertEquals(new BigDecimal("4.00"), result.getAvgResolutionTimeHours());
    }

    // ─── computeMetrics — null/zero handling ─────────────────────────────────

    @Test
    void computeMetrics_handlesZeroTotalHoles() {
        when(repository.countHolesWithCompleteLayers(any(), any())).thenReturn(0L);
        when(repository.countTotalHoles(any(), any())).thenReturn(0L);
        when(repository.countVerifiedCourses(any())).thenReturn(0L);
        when(repository.countTotalCourses(any())).thenReturn(0L);
        when(repository.countClassABCourses(any())).thenReturn(0L);
        when(repository.countCorrectionsInRange(any(Instant.class), any(Instant.class), any(), any()))
            .thenReturn(0L);
        when(repository.avgResolutionTimeSeconds(any(), any(), any(), any())).thenReturn(0.0);
        when(repository.resolutionTimesSeconds(any(), any(), any(), any()))
            .thenReturn(List.of());

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFromDate(FROM);
        request.setToDate(TO);

        DataQualityMetricsDto result = service.computeMetrics(request);

        // Geometry completeness: 0/0 = 0%
        assertEquals(new BigDecimal("0.00"), result.getGeometryCompleteness());
        // Class A/B coverage: 0/0 = 0%
        assertEquals(new BigDecimal("0.00"), result.getClassABCoverage());
        // Resolution times: empty = 0
        assertEquals(new BigDecimal("0.00"), result.getAvgResolutionTimeHours());
        assertEquals(new BigDecimal("0.00"), result.getMedianResolutionTimeHours());
    }

    @Test
    void computeMetrics_handlesNoResolvedCorrections() {
        when(repository.countHolesWithCompleteLayers(any(), any())).thenReturn(50L);
        when(repository.countTotalHoles(any(), any())).thenReturn(100L);
        when(repository.countVerifiedCourses(any())).thenReturn(10L);
        when(repository.countTotalCourses(any())).thenReturn(20L);
        when(repository.countClassABCourses(any())).thenReturn(10L);
        when(repository.countCorrectionsInRange(any(), any(), any(), any())).thenReturn(0L);
        when(repository.avgResolutionTimeSeconds(any(), any(), any(), any())).thenReturn(0.0);
        when(repository.resolutionTimesSeconds(any(), any(), any(), any())).thenReturn(List.of());

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFromDate(FROM);
        request.setToDate(TO);

        DataQualityMetricsDto result = service.computeMetrics(request);

        // avg/median return 0 (not null) when no resolved corrections
        assertEquals(new BigDecimal("0.00"), result.getAvgResolutionTimeHours());
        assertEquals(new BigDecimal("0.00"), result.getMedianResolutionTimeHours());
        assertEquals(0L, result.getCorrectionVolume());
    }

    @Test
    void computeMetrics_nullFacilityAndCourse_isTreatedAsAll() {
        when(repository.countHolesWithCompleteLayers(isNull(), isNull())).thenReturn(50L);
        when(repository.countTotalHoles(isNull(), isNull())).thenReturn(100L);
        when(repository.countVerifiedCourses(isNull())).thenReturn(0L);
        when(repository.countTotalCourses(isNull())).thenReturn(0L);
        when(repository.countClassABCourses(isNull())).thenReturn(0L);
        when(repository.countCorrectionsInRange(any(), any(), isNull(), isNull())).thenReturn(0L);
        when(repository.avgResolutionTimeSeconds(any(), any(), isNull(), isNull())).thenReturn(0.0);
        when(repository.resolutionTimesSeconds(any(), any(), isNull(), isNull())).thenReturn(List.of());

        DataQualityQueryRequest request = new DataQualityQueryRequest();
        request.setFromDate(FROM);
        request.setToDate(TO);
        // facilityId and courseId are null by default

        DataQualityMetricsDto result = service.computeMetrics(request);

        assertEquals(new BigDecimal("50.00"), result.getGeometryCompleteness());
        assertEquals(0L, result.getTotalCoursesCount());
        verify(repository).countHolesWithCompleteLayers(isNull(), isNull());
    }

    // ─── Individual metric methods ───────────────────────────────────────────

    @Test
    void computeGeometryCompleteness_returns0_whenNoHoles() {
        when(repository.countHolesWithCompleteLayers(FACILITY_ID, COURSE_ID)).thenReturn(0L);
        when(repository.countTotalHoles(FACILITY_ID, COURSE_ID)).thenReturn(0L);

        double result = service.computeGeometryCompleteness(FACILITY_ID, COURSE_ID);

        assertEquals(0.0, result);
    }

    @Test
    void computeGeometryCompleteness_computesPercentage() {
        when(repository.countHolesWithCompleteLayers(FACILITY_ID, COURSE_ID)).thenReturn(75L);
        when(repository.countTotalHoles(FACILITY_ID, COURSE_ID)).thenReturn(100L);

        double result = service.computeGeometryCompleteness(FACILITY_ID, COURSE_ID);

        assertEquals(75.0, result);
    }

    @Test
    void countVerifiedCourses_delegatesToRepository() {
        when(repository.countVerifiedCourses(FACILITY_ID)).thenReturn(15L);

        long result = service.countVerifiedCourses(FACILITY_ID);

        assertEquals(15L, result);
        verify(repository).countVerifiedCourses(FACILITY_ID);
    }

    @Test
    void countTotalCourses_delegatesToRepository() {
        when(repository.countTotalCourses(FACILITY_ID)).thenReturn(25L);

        long result = service.countTotalCourses(FACILITY_ID);

        assertEquals(25L, result);
    }

    @Test
    void computeClassABCoverage_returns0_whenNoCourses() {
        when(repository.countClassABCourses(FACILITY_ID)).thenReturn(0L);
        when(repository.countTotalCourses(FACILITY_ID)).thenReturn(0L);

        double result = service.computeClassABCoverage(FACILITY_ID);

        assertEquals(0.0, result);
    }

    @Test
    void computeClassABCoverage_computesPercentage() {
        when(repository.countClassABCourses(FACILITY_ID)).thenReturn(15L);
        when(repository.countTotalCourses(FACILITY_ID)).thenReturn(20L);

        double result = service.computeClassABCoverage(FACILITY_ID);

        assertEquals(75.0, result);
    }

    @Test
    void countCorrectionsInRange_convertsLocalDateToInstant() {
        Instant fromInstant = FROM.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = TO.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        when(repository.countCorrectionsInRange(eq(fromInstant), eq(toInstant), eq(COURSE_ID), eq(FACILITY_ID)))
            .thenReturn(50L);

        long result = service.countCorrectionsInRange(FROM, TO, COURSE_ID, FACILITY_ID);

        assertEquals(50L, result);
    }

    @Test
    void avgResolutionTimeHours_convertsSecondsToHours() {
        Instant fromInstant = FROM.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = TO.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        when(repository.avgResolutionTimeSeconds(eq(fromInstant), eq(toInstant), eq(COURSE_ID), eq(FACILITY_ID)))
            .thenReturn(72000.0); // 20 hours in seconds

        double result = service.avgResolutionTimeHours(FROM, TO, COURSE_ID, FACILITY_ID);

        assertEquals(20.0, result);
    }

    @Test
    void medianResolutionTimeHours_medianOfOddList() {
        Instant fromInstant = FROM.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = TO.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        // 3 values: 10h, 20h, 30h in seconds
        when(repository.resolutionTimesSeconds(eq(fromInstant), eq(toInstant), eq(COURSE_ID), eq(FACILITY_ID)))
            .thenReturn(List.of(36000.0, 72000.0, 108000.0));

        double result = service.medianResolutionTimeHours(FROM, TO, COURSE_ID, FACILITY_ID);

        assertEquals(20.0, result); // middle value
    }

    @Test
    void medianResolutionTimeHours_medianOfEvenList() {
        Instant fromInstant = FROM.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toInstant = TO.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().minusNanos(1);
        // 2 values: 10h, 20h in seconds
        when(repository.resolutionTimesSeconds(eq(fromInstant), eq(toInstant), eq(COURSE_ID), eq(FACILITY_ID)))
            .thenReturn(List.of(36000.0, 72000.0));

        double result = service.medianResolutionTimeHours(FROM, TO, COURSE_ID, FACILITY_ID);

        // (10 + 20) / 2 = 15h
        assertEquals(15.0, result);
    }

    @Test
    void medianResolutionTimeHours_returns0_whenEmpty() {
        when(repository.resolutionTimesSeconds(any(), any(), any(), any())).thenReturn(List.of());

        double result = service.medianResolutionTimeHours(FROM, TO, COURSE_ID, FACILITY_ID);

        assertEquals(0.0, result);
    }
}
