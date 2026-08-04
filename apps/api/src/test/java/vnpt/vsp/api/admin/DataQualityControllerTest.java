package vnpt.vsp.api.admin;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.dataquality.dto.DataQualityMetricsDto;
import vnpt.vsp.module.dataquality.dto.StaleRecordDto;
import vnpt.vsp.module.dataquality.service.DataQualityService;
import vnpt.vsp.module.dataquality.service.StaleRecordService;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link DataQualityController}.
 * Per Story 9.4 Wave 3 — T18 Integration Tests.
 *
 * Covers:
 * - RBAC enforcement (SUPER_ADMIN, COURSE_ADMIN, AUDITOR)
 * - Date range validation (required, to >= from, max 90 days)
 * - Export format validation (csv, xlsx)
 * - Happy-path metrics and stale record retrieval
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DataQualityControllerTest {

    @Mock private DataQualityService dataQualityService;
    @Mock private StaleRecordService staleRecordService;
    @Mock private RoleService roleService;
    @Mock private Authentication authentication;

    private DataQualityController controller;

    private static final Long ACCOUNT_ID = 100L;
    private static final LocalDate FROM = LocalDate.of(2025, 7, 1);
    private static final LocalDate TO = LocalDate.of(2025, 7, 31);

    @BeforeEach
    void setUp() {
        controller = new DataQualityController(dataQualityService, staleRecordService, roleService);
        when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
    }

    // ─── RBAC helpers ─────────────────────────────────────────────────────────

    private void allowSuperAdmin() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(true);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.AUDITOR)).thenReturn(false);
    }

    private void allowCourseAdmin() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.AUDITOR)).thenReturn(false);
    }

    private void allowAuditor() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.AUDITOR)).thenReturn(true);
    }

    private void denyAll() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.AUDITOR)).thenReturn(false);
    }

    // ─── Happy path: getMetrics ────────────────────────────────────────────────

    @Test
    void getMetrics_returnsOk_whenSuperAdmin() {
        allowSuperAdmin();

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        dto.setGeometryCompleteness(new BigDecimal("87.5"));
        dto.setVerifiedCoursesCount(42);
        dto.setTotalCoursesCount(50);
        dto.setClassABCoverage(new BigDecimal("78.0"));
        dto.setCorrectionVolume(127);
        dto.setAvgResolutionTimeHours(new BigDecimal("18.4"));
        dto.setMedianResolutionTimeHours(new BigDecimal("12.0"));

        when(dataQualityService.computeMetrics(any())).thenReturn(dto);

        ResponseEntity<DataQualityMetricsDto> response = controller.getMetrics(
            authentication, null, null, FROM, TO);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(new BigDecimal("87.5"), response.getBody().getGeometryCompleteness());
        assertEquals(42, response.getBody().getVerifiedCoursesCount());
    }

    @Test
    void getMetrics_returnsOk_whenCourseAdmin() {
        allowCourseAdmin();

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        dto.setGeometryCompleteness(new BigDecimal("90.0"));
        when(dataQualityService.computeMetrics(any())).thenReturn(dto);

        ResponseEntity<DataQualityMetricsDto> response = controller.getMetrics(
            authentication, 1L, 10L, FROM, TO);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
    }

    @Test
    void getMetrics_returnsOk_whenAuditor() {
        allowAuditor();

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        when(dataQualityService.computeMetrics(any())).thenReturn(dto);

        ResponseEntity<DataQualityMetricsDto> response = controller.getMetrics(
            authentication, null, null, FROM, TO);

        assertEquals(200, response.getStatusCode().value());
    }

    @Test
    void getMetrics_throwsAuthException_whenNoRole() {
        denyAll();

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.getMetrics(authentication, null, null, FROM, TO));

        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Date range validation ─────────────────────────────────────────────────

    @Test
    void getMetrics_throwsValidationException_whenFromIsNull() {
        allowSuperAdmin();

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.getMetrics(authentication, null, null, null, TO));

        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
    }

    @Test
    void getMetrics_throwsValidationException_whenToBeforeFrom() {
        allowSuperAdmin();

        LocalDate invalidFrom = LocalDate.of(2025, 8, 1);
        LocalDate invalidTo = LocalDate.of(2025, 7, 1);

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.getMetrics(authentication, null, null, invalidFrom, invalidTo));

        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
    }

    @Test
    void getMetrics_throwsValidationException_whenRangeExceeds90Days() {
        allowSuperAdmin();

        LocalDate farFrom = LocalDate.of(2025, 1, 1);
        LocalDate farTo = LocalDate.of(2025, 7, 31); // > 90 days

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.getMetrics(authentication, null, null, farFrom, farTo));

        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
    }

    @Test
    void getMetrics_acceptsExactly90DayRange() {
        allowSuperAdmin();

        LocalDate from = LocalDate.of(2025, 7, 1);
        LocalDate to = LocalDate.of(2025, 9, 29); // exactly 90 days

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        when(dataQualityService.computeMetrics(any())).thenReturn(dto);

        ResponseEntity<DataQualityMetricsDto> response =
            controller.getMetrics(authentication, null, null, from, to);

        assertEquals(200, response.getStatusCode().value());
    }

    // ─── Happy path: getStaleRecords ──────────────────────────────────────────

    @Test
    void getStaleRecords_returnsOk_whenSuperAdmin() {
        allowSuperAdmin();

        StaleRecordDto stale = new StaleRecordDto();
        stale.setRecordType("PIN");
        stale.setRecordId(1L);
        stale.setFacilityId(10L);
        stale.setFacilityName("Pine Valley");
        stale.setSeverity("HIGH");

        when(staleRecordService.findAllStaleRecords(null, null))
            .thenReturn(List.of(stale));

        ResponseEntity<List<StaleRecordDto>> response =
            controller.getStaleRecords(authentication, null, null);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(1, response.getBody().size());
        assertEquals("PIN", response.getBody().get(0).getRecordType());
    }

    @Test
    void getStaleRecords_filtersByFacility() {
        allowSuperAdmin();

        when(staleRecordService.findAllStaleRecords(10L, null))
            .thenReturn(List.of());

        ResponseEntity<List<StaleRecordDto>> response =
            controller.getStaleRecords(authentication, 10L, null);

        assertEquals(200, response.getStatusCode().value());
        verify(staleRecordService).findAllStaleRecords(10L, null);
    }

    @Test
    void getStaleRecords_throwsAuthException_whenNoRole() {
        denyAll();

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.getStaleRecords(authentication, null, null));

        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Happy path: exportDataQuality ───────────────────────────────────────

    @Test
    void exportDataQuality_returnsCsv_whenSuperAdmin() {
        allowSuperAdmin();

        DataQualityMetricsDto dto = new DataQualityMetricsDto();
        dto.setGeometryCompleteness(new BigDecimal("87.5"));
        dto.setVerifiedCoursesCount(42);
        dto.setTotalCoursesCount(50);
        dto.setClassABCoverage(new BigDecimal("78.0"));
        dto.setCorrectionVolume(127);
        dto.setAvgResolutionTimeHours(new BigDecimal("18.4"));
        dto.setMedianResolutionTimeHours(new BigDecimal("12.0"));

        when(dataQualityService.computeMetrics(any())).thenReturn(dto);
        when(staleRecordService.findAllStaleRecords(null, null)).thenReturn(List.of());

        ResponseEntity<String> response = controller.exportDataQuality(
            authentication, null, null, FROM, TO, "csv");

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertTrue(response.getBody().contains("geometry_completeness"));
        assertTrue(response.getBody().contains("87.5"));
        assertTrue(response.getHeaders().getFirst("Content-Disposition")
            .contains("attachment"));
        assertTrue(response.getHeaders().getFirst("Content-Disposition")
            .contains(".csv"));
    }

    @Test
    void exportDataQuality_throwsValidationException_whenFormatInvalid() {
        allowSuperAdmin();

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.exportDataQuality(authentication, null, null, FROM, TO, "pdf"));

        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
    }

    @Test
    void exportDataQuality_throwsAuthException_whenNoRole() {
        denyAll();

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.exportDataQuality(authentication, null, null, FROM, TO, "csv"));

        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Audit annotation present on export ────────────────────────────────────
    // (Verified by controller class-level annotation check — audited in integration tests)

    @Test
    void exportDataQuality_respectsMaxDateRange() {
        allowSuperAdmin();

        // Exceeding 90 days
        LocalDate from = LocalDate.of(2025, 1, 1);
        LocalDate to = LocalDate.of(2025, 7, 31);

        VspApiException ex = assertThrows(VspApiException.class, () ->
            controller.exportDataQuality(authentication, null, null, from, to, "csv"));

        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
    }
}
