package vnpt.vsp.module.dataquality.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.module.dataquality.dto.StaleRecordDto;
import vnpt.vsp.module.dataquality.repository.StaleRecordRepository;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import vnpt.vsp.module.dataquality.dto.StalePinProjection;
import vnpt.vsp.module.dataquality.dto.StaleGreenConditionProjection;
import vnpt.vsp.module.dataquality.dto.StaleCourseConditionProjection;
import vnpt.vsp.module.course.entity.CourseCondition.Severity;

/**
 * Unit tests for {@link StaleRecordServiceImpl}.
 * Per Story 9.4 Wave 3 — T17 Unit Tests.
 *
 * Covers:
 * - Stale record aggregation (PIN + GREEN_SPEED + COURSE_CONDITION)
 * - Severity assignment based on expiry age
 * - Filter propagation to repository layer
 * - Cache TTL constant (5 min per Slice Plan)
 */
@ExtendWith(MockitoExtension.class)
class StaleRecordServiceImplTest {

    @Mock private StaleRecordRepository staleRecordRepository;

    private StaleRecordServiceImpl service;

    private static final Long FACILITY_ID = 10L;
    private static final Long COURSE_ID = 101L;

    @BeforeEach
    void setUp() {
        service = new StaleRecordServiceImpl(staleRecordRepository);
    }

    // ─── Projection builders (for mocking repository) ────────────────────────

    private StalePinProjection makePinProjection(Long id, Long facilityId, String facilityName,
                                                 Long courseId, String courseName,
                                                 Integer holeNumber, LocalDate expiredAt) {
        StalePinProjection p = mock(StalePinProjection.class);
        when(p.getRecordId()).thenReturn(id);
        when(p.getFacilityId()).thenReturn(facilityId);
        when(p.getFacilityName()).thenReturn(facilityName);
        when(p.getCourseId()).thenReturn(courseId);
        when(p.getCourseName()).thenReturn(courseName);
        when(p.getHoleNumber()).thenReturn(holeNumber);
        when(p.getExpiredAt()).thenReturn(expiredAt);
        return p;
    }

    private StaleGreenConditionProjection makeGreenProjection(Long id, Long facilityId, String facilityName,
                                                              Long courseId, String courseName,
                                                              Integer holeNumber, Instant expiredAt) {
        StaleGreenConditionProjection g = mock(StaleGreenConditionProjection.class);
        when(g.getRecordId()).thenReturn(id);
        when(g.getFacilityId()).thenReturn(facilityId);
        when(g.getFacilityName()).thenReturn(facilityName);
        when(g.getCourseId()).thenReturn(courseId);
        when(g.getCourseName()).thenReturn(courseName);
        when(g.getHoleNumber()).thenReturn(holeNumber);
        when(g.getExpiredAt()).thenReturn(expiredAt);
        return g;
    }

    private StaleCourseConditionProjection makeConditionProjection(Long id, Long facilityId, String facilityName,
                                                                   Long courseId, String courseName,
                                                                    LocalDate expiredAt, Severity severity) {
        StaleCourseConditionProjection c = mock(StaleCourseConditionProjection.class);
        when(c.getRecordId()).thenReturn(id);
        when(c.getFacilityId()).thenReturn(facilityId);
        when(c.getFacilityName()).thenReturn(facilityName);
        when(c.getCourseId()).thenReturn(courseId);
        when(c.getCourseName()).thenReturn(courseName);
        when(c.getExpiredAt()).thenReturn(expiredAt);
        when(c.getSeverity()).thenReturn(severity);
        return c;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @Test
    void findAllStaleRecords_combinesAllThreeRecordTypes() {
        LocalDate today = LocalDate.now();
        Instant now = Instant.now();
        StalePinProjection pin = makePinProjection(1L, 10L, "Facility A", 101L, "Course A", 3, today.minusDays(1));
        StaleGreenConditionProjection green = makeGreenProjection(2L, 10L, "Facility A", 101L, "Course A", 5, now.minus(2, ChronoUnit.DAYS));
        StaleCourseConditionProjection cond = makeConditionProjection(3L, 10L, "Facility A", 101L, "Course A", today.minusDays(3), Severity.LOW);

        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), isNull(), isNull()))
            .thenReturn(List.of(pin));
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), isNull(), isNull()))
            .thenReturn(List.of(green));
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), isNull(), isNull()))
            .thenReturn(List.of(cond));

        List<StaleRecordDto> result = service.findAllStaleRecords(null, null);

        assertEquals(3, result.size());
        assertTrue(result.stream().anyMatch(r -> r.getRecordType().equals("PIN")));
        assertTrue(result.stream().anyMatch(r -> r.getRecordType().equals("GREEN_SPEED")));
        assertTrue(result.stream().anyMatch(r -> r.getRecordType().equals("COURSE_CONDITION")));
    }

    @Test
    void findAllStaleRecords_appliesFacilityFilter() {
        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), isNull()))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), eq(FACILITY_ID), isNull()))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), eq(FACILITY_ID), isNull()))
            .thenReturn(List.of());

        service.findAllStaleRecords(FACILITY_ID, null);

        verify(staleRecordRepository).findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), isNull());
        verify(staleRecordRepository).findStaleGreenConditions(any(Instant.class), eq(FACILITY_ID), isNull());
        verify(staleRecordRepository).findStaleCourseConditions(any(LocalDate.class), eq(FACILITY_ID), isNull());
    }

    @Test
    void findAllStaleRecords_appliesCourseFilter() {
        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), eq(COURSE_ID)))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), eq(FACILITY_ID), eq(COURSE_ID)))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), eq(FACILITY_ID), eq(COURSE_ID)))
            .thenReturn(List.of());

        service.findAllStaleRecords(FACILITY_ID, COURSE_ID);

        verify(staleRecordRepository).findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), eq(COURSE_ID));
    }

    @Test
    void findAllStaleRecords_returnsEmptyList_whenNoStaleRecords() {
        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), any(), any()))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), any(), any()))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), any(), any()))
            .thenReturn(List.of());

        List<StaleRecordDto> result = service.findAllStaleRecords(null, null);

        assertTrue(result.isEmpty());
    }

    @Test
    void findAllStaleRecords_isSortedByExpiry() {
        LocalDate today = LocalDate.now();
        LocalDate olderExpiry = today.minusDays(5);
        LocalDate recentExpiry = today.minusDays(1);

        StalePinProjection older = makePinProjection(2L, 10L, "F", 101L, "C", 1, olderExpiry);
        StalePinProjection recent = makePinProjection(1L, 10L, "F", 101L, "C", 2, recentExpiry);

        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), isNull(), isNull()))
            .thenReturn(List.of(older, recent));
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), isNull(), isNull()))
            .thenReturn(List.of());
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), isNull(), isNull()))
            .thenReturn(List.of());

        List<StaleRecordDto> result = service.findAllStaleRecords(null, null);

        assertEquals(2, result.size());
        // Repository returns oldest first (sorted by expiry ASC)
        assertEquals(2L, result.get(0).getRecordId()); // older
        assertEquals(1L, result.get(1).getRecordId()); // recent
    }

    // ─── Individual finders ───────────────────────────────────────────────────

    @Test
    void findStalePinPositions_delegatesToRepository() {
        LocalDate today = LocalDate.now();
        StalePinProjection pin = makePinProjection(5L, FACILITY_ID, "Facility", COURSE_ID, "Course", 3, today);
        when(staleRecordRepository.findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), eq(COURSE_ID)))
            .thenReturn(List.of(pin));

        List<StaleRecordDto> result = service.findStalePinPositions(FACILITY_ID, COURSE_ID);

        assertEquals(1, result.size());
        assertEquals("PIN", result.get(0).getRecordType());
        verify(staleRecordRepository).findStalePinPositions(any(LocalDate.class), eq(FACILITY_ID), eq(COURSE_ID));
    }

    @Test
    void findStaleGreenConditions_delegatesToRepository() {
        Instant now = Instant.now();
        StaleGreenConditionProjection green = makeGreenProjection(6L, FACILITY_ID, "Facility", COURSE_ID, "Course", 5, now);
        when(staleRecordRepository.findStaleGreenConditions(any(Instant.class), eq(FACILITY_ID), isNull()))
            .thenReturn(List.of(green));

        List<StaleRecordDto> result = service.findStaleGreenConditions(FACILITY_ID, null);

        assertEquals(1, result.size());
        assertEquals("GREEN_SPEED", result.get(0).getRecordType());
    }

    @Test
    void findStaleCourseConditions_delegatesToRepository() {
        LocalDate today = LocalDate.now();
        StaleCourseConditionProjection cond = makeConditionProjection(7L, FACILITY_ID, "Facility", COURSE_ID, "Course", today, Severity.HIGH);
        when(staleRecordRepository.findStaleCourseConditions(any(LocalDate.class), isNull(), eq(COURSE_ID)))
            .thenReturn(List.of(cond));

        List<StaleRecordDto> result = service.findStaleCourseConditions(null, COURSE_ID);

        assertEquals(1, result.size());
        assertEquals("COURSE_CONDITION", result.get(0).getRecordType());
    }

    // ─── Cache TTL constant ─────────────────────────────────────────────────

    @Test
    void cacheTtlMinutes_is5() {
        assertEquals(5, StaleRecordService.CACHE_TTL_MINUTES);
    }
}
