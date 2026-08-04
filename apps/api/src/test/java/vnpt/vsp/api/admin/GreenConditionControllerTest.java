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
import vnpt.vsp.module.operations.OperationsService;
import vnpt.vsp.module.operations.dto.GreenConditionDto;
import vnpt.vsp.module.operations.dto.GreenConditionCreateRequest;
import vnpt.vsp.module.operations.dto.GreenConditionUpdateRequest;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link GreenConditionController}.
 * Per Story 8.5 AC-2: green speed (stimpmeter), firmness, moisture updates.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Tests Phase 5.2: Controller integration tests - auth, validation, happy path.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GreenConditionControllerTest {

    @Mock private OperationsService operationsService;
    @Mock private RoleService roleService;
    @Mock private Authentication authentication;

    private GreenConditionController controller;

    private static final Long COURSE_ID = 1L;
    private static final Integer HOLE_NUMBER = 5;
    private static final Long ACCOUNT_ID = 100L;
    private static final String ACTOR_NAME = "greenkeeper@vsp.com";
    private static final Long CONDITION_ID = 10L;

    @BeforeEach
    void setUp() {
        controller = new GreenConditionController(operationsService, roleService);
        when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
        when(authentication.getName()).thenReturn(ACTOR_NAME);
    }

    private void allowGreenkeeper() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(true);
    }

    // ─── Auth Tests ─────────────────────────────────────────────────────────────

    @Test
    void createGreenCondition_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        GreenConditionCreateRequest request = makeValidRequest();

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void getGreenConditions_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getGreenConditionsForHole(authentication, COURSE_ID, HOLE_NUMBER, null));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void updateGreenCondition_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        GreenConditionUpdateRequest request = new GreenConditionUpdateRequest();

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updateGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, CONDITION_ID, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Happy Path Tests ──────────────────────────────────────────────────────

    @Test
    void createGreenCondition_success_returns201() {
        // Given
        allowGreenkeeper();

        GreenConditionCreateRequest request = makeValidRequest();

        GreenConditionDto expected = new GreenConditionDto();
        expected.setId(CONDITION_ID);
        expected.setCourseId(COURSE_ID);
        expected.setHoleNumber(HOLE_NUMBER);
        expected.setStimpmeterReading(new BigDecimal("10.5"));
        expected.setFirmness("FIRM");
        expected.setMoisture("NORMAL");
        expected.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        expected.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));
        expected.setPublishedBy(ACTOR_NAME);

        when(operationsService.createGreenCondition(
                eq(COURSE_ID), eq(HOLE_NUMBER),
                eq(new BigDecimal("10.5")), eq("FIRM"), eq("NORMAL"),
                eq(Instant.parse("2026-08-01T06:00:00Z")),
                eq(Instant.parse("2026-08-01T18:00:00Z")),
                eq(ACTOR_NAME)
        )).thenReturn(expected);

        // When
        ResponseEntity<GreenConditionDto> response =
                controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(CONDITION_ID, response.getBody().getId());
        assertEquals(COURSE_ID, response.getBody().getCourseId());
        assertEquals(HOLE_NUMBER, response.getBody().getHoleNumber());
        assertEquals("10.5", response.getBody().getStimpmeterReading().toString());
        assertEquals("FIRM", response.getBody().getFirmness());
        assertEquals("NORMAL", response.getBody().getMoisture());
        assertEquals(ACTOR_NAME, response.getBody().getPublishedBy());
    }

    @Test
    void updateGreenCondition_success_returns200() {
        // Given
        allowGreenkeeper();

        GreenConditionUpdateRequest request = new GreenConditionUpdateRequest();
        request.setStimpmeter(new BigDecimal("11.5"));
        request.setFirmness("HARD");
        request.setMoisture("DRY");

        GreenConditionDto expected = new GreenConditionDto();
        expected.setId(CONDITION_ID);
        expected.setCourseId(COURSE_ID);
        expected.setHoleNumber(HOLE_NUMBER);
        expected.setStimpmeterReading(new BigDecimal("11.5"));
        expected.setFirmness("HARD");
        expected.setMoisture("DRY");

        when(operationsService.updateGreenCondition(
                eq(CONDITION_ID),
                eq(new BigDecimal("11.5")), eq("HARD"), eq("DRY"),
                isNull(), isNull()
        )).thenReturn(expected);

        // When
        ResponseEntity<GreenConditionDto> response = controller.updateGreenCondition(
                authentication, COURSE_ID, HOLE_NUMBER, CONDITION_ID, request);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(CONDITION_ID, response.getBody().getId());
        assertEquals("11.5", response.getBody().getStimpmeterReading().toString());
        assertEquals("HARD", response.getBody().getFirmness());
        assertEquals("DRY", response.getBody().getMoisture());
    }

    @Test
    void getGreenConditionsForHole_success_returns200() {
        // Given
        allowGreenkeeper();

        GreenConditionDto condition = new GreenConditionDto();
        condition.setId(CONDITION_ID);
        condition.setCourseId(COURSE_ID);
        condition.setHoleNumber(HOLE_NUMBER);
        condition.setStimpmeterReading(new BigDecimal("10.5"));
        condition.setEffectiveFrom(Instant.now().minusSeconds(1800));
        condition.setExpiresAt(Instant.now().plusSeconds(1800));

        when(operationsService.getGreenConditions(eq(COURSE_ID), eq(HOLE_NUMBER), any()))
                .thenReturn(List.of(condition));

        // When
        ResponseEntity<List<GreenConditionDto>> response =
                controller.getGreenConditionsForHole(authentication, COURSE_ID, HOLE_NUMBER, Instant.now());

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(1, response.getBody().size());
        assertEquals(CONDITION_ID, response.getBody().get(0).getId());
    }

    @Test
    void getAllGreenConditionsForCourse_success_returns200() {
        // Given
        allowGreenkeeper();

        GreenConditionDto condition1 = new GreenConditionDto();
        condition1.setId(1L);
        condition1.setHoleNumber(1);

        GreenConditionDto condition2 = new GreenConditionDto();
        condition2.setId(2L);
        condition2.setHoleNumber(2);

        when(operationsService.getAllGreenConditions(eq(COURSE_ID), any()))
                .thenReturn(List.of(condition1, condition2));

        // When
        ResponseEntity<List<GreenConditionDto>> response =
                controller.getAllGreenConditionsForCourse(authentication, COURSE_ID, Instant.now());

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().size());
    }

    @Test
    void getGreenConditionsForHole_withAsOfDate_passesDateToService() {
        // Given
        allowGreenkeeper();

        Instant asOfDate = Instant.parse("2026-08-01T12:00:00Z");
        when(operationsService.getGreenConditions(COURSE_ID, HOLE_NUMBER, asOfDate))
                .thenReturn(List.of());

        // When
        controller.getGreenConditionsForHole(authentication, COURSE_ID, HOLE_NUMBER, asOfDate);

        // Then
        verify(operationsService).getGreenConditions(COURSE_ID, HOLE_NUMBER, asOfDate);
    }

    // ─── Validation Tests ──────────────────────────────────────────────────────

    @Test
    void createGreenCondition_throwsServiceValidation_whenEffectiveFromMissing() {
        // Given
        allowGreenkeeper();

        GreenConditionCreateRequest request = new GreenConditionCreateRequest();
        request.setStimpmeter(new BigDecimal("10.5"));
        request.setFirmness("FIRM");
        request.setMoisture("NORMAL");
        // effectiveFrom is null

        when(operationsService.createGreenCondition(
                eq(COURSE_ID), eq(HOLE_NUMBER),
                eq(new BigDecimal("10.5")), eq("FIRM"), eq("NORMAL"),
                isNull(), any(), eq(ACTOR_NAME)
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_002,
                "Green condition effectiveFrom is required", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.VALIDATION_002, ex.getErrorCode());
    }

    @Test
    void createGreenCondition_throwsServiceValidation_whenStimpmeterOutOfRange() {
        // Given
        allowGreenkeeper();

        GreenConditionCreateRequest request = new GreenConditionCreateRequest();
        request.setStimpmeter(new BigDecimal("20.0")); // Out of range 6-14
        request.setFirmness("FIRM");
        request.setMoisture("NORMAL");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        when(operationsService.createGreenCondition(
                eq(COURSE_ID), eq(HOLE_NUMBER),
                eq(new BigDecimal("20.0")), eq("FIRM"), eq("NORMAL"),
                any(), any(), eq(ACTOR_NAME)
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_003,
                "Stimpmeter reading must be between 6.0 and 14.0 feet (per AC-2)", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.VALIDATION_003, ex.getErrorCode());
    }

    @Test
    void updateGreenCondition_throwsServiceValidation_whenStimpmeterOutOfRange() {
        // Given
        allowGreenkeeper();

        GreenConditionUpdateRequest request = new GreenConditionUpdateRequest();
        request.setStimpmeter(new BigDecimal("5.0")); // Below minimum of 6

        when(operationsService.updateGreenCondition(
                eq(CONDITION_ID),
                eq(new BigDecimal("5.0")), isNull(), isNull(), isNull(), isNull()
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_003,
                "Stimpmeter reading must be between 6.0 and 14.0 feet (per AC-2)", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updateGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, CONDITION_ID, request));
        assertEquals(VspErrorCode.VALIDATION_003, ex.getErrorCode());
    }

    @Test
    void updateGreenCondition_throwsNotFound_whenConditionDoesNotExist() {
        // Given
        allowGreenkeeper();

        GreenConditionUpdateRequest request = new GreenConditionUpdateRequest();
        request.setStimpmeter(new BigDecimal("10.0"));

        when(operationsService.updateGreenCondition(eq(999L), any(), any(), any(), any(), any()))
                .thenThrow(new VspApiException(VspErrorCode.CONDITION_001,
                        "Green condition not found: 999", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updateGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, 999L, request));
        assertEquals(VspErrorCode.CONDITION_001, ex.getErrorCode());
    }

    // ─── Firmness and Moisture Enum Tests ─────────────────────────────────────

    @Test
    void createGreenCondition_acceptsAllFirmnessValues() {
        // Given
        allowGreenkeeper();

        String[] firmnessValues = {"SOFT", "MEDIUM", "FIRM", "HARD"};

        for (String firmness : firmnessValues) {
            GreenConditionCreateRequest request = makeValidRequest();
            request.setFirmness(firmness);

            GreenConditionDto expected = new GreenConditionDto();
            expected.setId(CONDITION_ID);
            expected.setFirmness(firmness);

            when(operationsService.createGreenCondition(
                    eq(COURSE_ID), eq(HOLE_NUMBER), any(), eq(firmness), any(), any(), any(), eq(ACTOR_NAME)
            )).thenReturn(expected);

            // When
            ResponseEntity<GreenConditionDto> response =
                    controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

            // Then
            assertEquals(201, response.getStatusCode().value(),
                    "Failed for firmness: " + firmness);
            assertEquals(firmness, response.getBody().getFirmness());
        }
    }

    @Test
    void createGreenCondition_acceptsAllMoistureValues() {
        // Given
        allowGreenkeeper();

        String[] moistureValues = {"DRY", "NORMAL", "WET", "SATURATED"};

        for (String moisture : moistureValues) {
            GreenConditionCreateRequest request = makeValidRequest();
            request.setMoisture(moisture);

            GreenConditionDto expected = new GreenConditionDto();
            expected.setId(CONDITION_ID);
            expected.setMoisture(moisture);

            when(operationsService.createGreenCondition(
                    eq(COURSE_ID), eq(HOLE_NUMBER), any(), any(), eq(moisture), any(), any(), eq(ACTOR_NAME)
            )).thenReturn(expected);

            // When
            ResponseEntity<GreenConditionDto> response =
                    controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

            // Then
            assertEquals(201, response.getStatusCode().value(),
                    "Failed for moisture: " + moisture);
            assertEquals(moisture, response.getBody().getMoisture());
        }
    }

    // ─── Stimpmeter Range Boundary Tests ───────────────────────────────────────

    @Test
    void createGreenCondition_acceptsBoundaryStimpmeterValues() {
        // Given
        allowGreenkeeper();

        BigDecimal[] boundaryValues = {
                new BigDecimal("6.0"),  // minimum
                new BigDecimal("6.1"),
                new BigDecimal("10.0"),
                new BigDecimal("13.9"),
                new BigDecimal("14.0")   // maximum
        };

        for (BigDecimal stimpmeter : boundaryValues) {
            GreenConditionCreateRequest request = makeValidRequest();
            request.setStimpmeter(stimpmeter);

            GreenConditionDto expected = new GreenConditionDto();
            expected.setId(CONDITION_ID);
            expected.setStimpmeterReading(stimpmeter);

            when(operationsService.createGreenCondition(
                    eq(COURSE_ID), eq(HOLE_NUMBER),
                    eq(stimpmeter), any(), any(), any(), any(), eq(ACTOR_NAME)
            )).thenReturn(expected);

            // When
            ResponseEntity<GreenConditionDto> response =
                    controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

            // Then
            assertEquals(201, response.getStatusCode().value(),
                    "Failed for stimpmeter: " + stimpmeter);
            assertEquals(0, stimpmeter.compareTo(response.getBody().getStimpmeterReading()));
        }
    }

    // ─── Role Authorization Tests ──────────────────────────────────────────────

    @Test
    void createGreenCondition_success_withCourseAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        GreenConditionCreateRequest request = makeValidRequest();

        GreenConditionDto expected = new GreenConditionDto();
        expected.setId(CONDITION_ID);
        when(operationsService.createGreenCondition(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<GreenConditionDto> response =
                controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }

    @Test
    void createGreenCondition_success_withSuperAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(true);

        GreenConditionCreateRequest request = makeValidRequest();

        GreenConditionDto expected = new GreenConditionDto();
        expected.setId(CONDITION_ID);
        when(operationsService.createGreenCondition(any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<GreenConditionDto> response =
                controller.createGreenCondition(authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }

    // ─── Helper Methods ─────────────────────────────────────────────────────────

    private GreenConditionCreateRequest makeValidRequest() {
        GreenConditionCreateRequest request = new GreenConditionCreateRequest();
        request.setStimpmeter(new BigDecimal("10.5"));
        request.setFirmness("FIRM");
        request.setMoisture("NORMAL");
        request.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        request.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));
        return request;
    }
}
