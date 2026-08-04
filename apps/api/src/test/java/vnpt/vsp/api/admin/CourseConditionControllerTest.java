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
import vnpt.vsp.module.operations.dto.CourseConditionDto;
import vnpt.vsp.module.operations.dto.CourseConditionCreateRequest;
import vnpt.vsp.module.operations.dto.CourseConditionUpdateRequest;
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
 * Unit tests for {@link CourseConditionController}.
 * Per Story 8.5 AC-2: course status, maintenance, and course-level conditions.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Tests Phase 5.2: Controller integration tests - auth, validation, happy path.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourseConditionControllerTest {

    @Mock private OperationsService operationsService;
    @Mock private RoleService roleService;
    @Mock private Authentication authentication;

    private CourseConditionController controller;

    private static final Long COURSE_ID = 1L;
    private static final Long ACCOUNT_ID = 100L;
    private static final String ACTOR_NAME = "greenkeeper@vsp.com";
    private static final Long CONDITION_ID = 10L;

    @BeforeEach
    void setUp() {
        controller = new CourseConditionController(operationsService, roleService);
        when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
        when(authentication.getName()).thenReturn(ACTOR_NAME);
    }

    private void allowGreenkeeper() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(true);
    }

    // ─── Auth Tests ─────────────────────────────────────────────────────────────

    @Test
    void createCourseCondition_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        CourseConditionCreateRequest request = new CourseConditionCreateRequest();
        request.setConditionType("COURSE_OVERALL");
        request.setSeverity("MODERATE");
        request.setDescription("Greens running fast");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createCourseCondition(authentication, COURSE_ID, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void getCourseConditions_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getCourseConditions(authentication, COURSE_ID, null));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Happy Path Tests ──────────────────────────────────────────────────────

    @Test
    void createCourseCondition_success_returns201() {
        // Given
        allowGreenkeeper();

        CourseConditionCreateRequest request = new CourseConditionCreateRequest();
        request.setConditionType("COURSE_OVERALL");
        request.setSeverity("MODERATE");
        request.setDescription("Greens running fast at 11 on stimpmeter");
        request.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        request.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));

        CourseConditionDto expected = new CourseConditionDto();
        expected.setId(CONDITION_ID);
        expected.setCourseId(COURSE_ID);
        expected.setConditionType("COURSE_OVERALL");
        expected.setSeverity("MODERATE");
        expected.setDescription("Greens running fast at 11 on stimpmeter");
        expected.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        expected.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));
        expected.setPublishedBy(ACTOR_NAME);

        when(operationsService.createCourseCondition(
                eq(COURSE_ID), eq("COURSE_OVERALL"), eq("MODERATE"),
                eq("Greens running fast at 11 on stimpmeter"),
                eq(Instant.parse("2026-08-01T06:00:00Z")),
                eq(Instant.parse("2026-08-01T18:00:00Z")),
                eq(ACTOR_NAME)
        )).thenReturn(expected);

        // When
        ResponseEntity<CourseConditionDto> response =
                controller.createCourseCondition(authentication, COURSE_ID, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(CONDITION_ID, response.getBody().getId());
        assertEquals(COURSE_ID, response.getBody().getCourseId());
        assertEquals("COURSE_OVERALL", response.getBody().getConditionType());
        assertEquals("MODERATE", response.getBody().getSeverity());
        assertEquals("Greens running fast at 11 on stimpmeter", response.getBody().getDescription());
        assertEquals(ACTOR_NAME, response.getBody().getPublishedBy());
    }

    @Test
    void updateCourseCondition_success_returns200() {
        // Given
        allowGreenkeeper();

        CourseConditionUpdateRequest request = new CourseConditionUpdateRequest();
        request.setSeverity("HIGH");
        request.setDescription("Updated: greens are now 12 on stimpmeter");

        CourseConditionDto expected = new CourseConditionDto();
        expected.setId(CONDITION_ID);
        expected.setCourseId(COURSE_ID);
        expected.setConditionType("COURSE_OVERALL");
        expected.setSeverity("HIGH");
        expected.setDescription("Updated: greens are now 12 on stimpmeter");

        when(operationsService.updateCourseCondition(
                eq(CONDITION_ID), isNull(), eq("HIGH"),
                eq("Updated: greens are now 12 on stimpmeter"),
                isNull(), isNull()
        )).thenReturn(expected);

        // When
        ResponseEntity<CourseConditionDto> response = controller.updateCourseCondition(
                authentication, COURSE_ID, CONDITION_ID, request);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(CONDITION_ID, response.getBody().getId());
        assertEquals("HIGH", response.getBody().getSeverity());
        assertEquals("Updated: greens are now 12 on stimpmeter", response.getBody().getDescription());
    }

    @Test
    void getCourseConditions_success_returns200() {
        // Given
        allowGreenkeeper();

        CourseConditionDto condition1 = new CourseConditionDto();
        condition1.setId(1L);
        condition1.setConditionType("GREEN_SPEED");
        condition1.setSeverity("MODERATE");

        CourseConditionDto condition2 = new CourseConditionDto();
        condition2.setId(2L);
        condition2.setConditionType("COURSE_OVERALL");
        condition2.setSeverity("LOW");

        when(operationsService.getCourseConditions(eq(COURSE_ID), any()))
                .thenReturn(List.of(condition1, condition2));

        // When
        ResponseEntity<List<CourseConditionDto>> response =
                controller.getCourseConditions(authentication, COURSE_ID, Instant.now());

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().size());
    }

    @Test
    void getCourseConditions_withAsOfDate_passesDateToService() {
        // Given
        allowGreenkeeper();

        Instant asOfDate = Instant.parse("2026-08-01T12:00:00Z");
        when(operationsService.getCourseConditions(COURSE_ID, asOfDate))
                .thenReturn(List.of());

        // When
        controller.getCourseConditions(authentication, COURSE_ID, asOfDate);

        // Then
        verify(operationsService).getCourseConditions(COURSE_ID, asOfDate);
    }

    // ─── Validation Tests ──────────────────────────────────────────────────────

    @Test
    void createCourseCondition_throwsServiceValidation_whenEffectiveFromMissing() {
        // Given
        allowGreenkeeper();

        CourseConditionCreateRequest request = new CourseConditionCreateRequest();
        request.setConditionType("COURSE_OVERALL");
        request.setSeverity("MODERATE");
        request.setDescription("Test");
        // effectiveFrom is null

        when(operationsService.createCourseCondition(
                eq(COURSE_ID), eq("COURSE_OVERALL"), eq("MODERATE"), eq("Test"),
                isNull(), any(), eq(ACTOR_NAME)
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_002,
                "Course condition effectiveFrom is required", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createCourseCondition(authentication, COURSE_ID, request));
        assertEquals(VspErrorCode.VALIDATION_002, ex.getErrorCode());
    }

    @Test
    void updateCourseCondition_throwsNotFound_whenConditionDoesNotExist() {
        // Given
        allowGreenkeeper();

        CourseConditionUpdateRequest request = new CourseConditionUpdateRequest();
        request.setSeverity("HIGH");

        when(operationsService.updateCourseCondition(eq(999L), any(), any(), any(), any(), any()))
                .thenThrow(new VspApiException(VspErrorCode.CONDITION_001,
                        "Course condition not found: 999", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updateCourseCondition(authentication, COURSE_ID, 999L, request));
        assertEquals(VspErrorCode.CONDITION_001, ex.getErrorCode());
    }

    // ─── All Condition Types Tests ────────────────────────────────────────────

    @Test
    void createCourseCondition_acceptsAllConditionTypes() {
        // Given
        allowGreenkeeper();

        String[] conditionTypes = {
                "GREEN_SPEED", "GREEN_FIRMNESS", "FAIRWAY_FIRMNESS",
                "ROUGH_DENSITY", "BUNKER_CONDITION", "COURSE_MOISTURE",
                "COURSE_OVERALL", "WEATHER_IMPACT", "OTHER"
        };

        for (String conditionType : conditionTypes) {
            CourseConditionCreateRequest request = new CourseConditionCreateRequest();
            request.setConditionType(conditionType);
            request.setSeverity("LOW");
            request.setDescription("Test " + conditionType);
            request.setEffectiveFrom(Instant.now());
            request.setExpiresAt(Instant.now().plusSeconds(3600));

            CourseConditionDto expected = new CourseConditionDto();
            expected.setId(CONDITION_ID);
            expected.setConditionType(conditionType);
            expected.setSeverity("LOW");

            when(operationsService.createCourseCondition(
                    eq(COURSE_ID), eq(conditionType), eq("LOW"),
                        eq("Test " + conditionType), any(), any(), eq(ACTOR_NAME)
            )).thenReturn(expected);

            // When
            ResponseEntity<CourseConditionDto> response =
                    controller.createCourseCondition(authentication, COURSE_ID, request);

            // Then
            assertEquals(201, response.getStatusCode().value(),
                    "Failed for conditionType: " + conditionType);
            assertEquals(conditionType, response.getBody().getConditionType());
        }
    }

    @Test
    void createCourseCondition_acceptsAllSeverityLevels() {
        // Given
        allowGreenkeeper();

        String[] severities = {"LOW", "MODERATE", "HIGH", "CRITICAL"};

        for (String severity : severities) {
            CourseConditionCreateRequest request = new CourseConditionCreateRequest();
            request.setConditionType("COURSE_OVERALL");
            request.setSeverity(severity);
            request.setDescription("Test severity " + severity);
            request.setEffectiveFrom(Instant.now());
            request.setExpiresAt(Instant.now().plusSeconds(3600));

            CourseConditionDto expected = new CourseConditionDto();
            expected.setId(CONDITION_ID);
            expected.setSeverity(severity);

            when(operationsService.createCourseCondition(
                    eq(COURSE_ID), eq("COURSE_OVERALL"), eq(severity),
                        any(), any(), any(), eq(ACTOR_NAME)
            )).thenReturn(expected);

            // When
            ResponseEntity<CourseConditionDto> response =
                    controller.createCourseCondition(authentication, COURSE_ID, request);

            // Then
            assertEquals(201, response.getStatusCode().value(),
                    "Failed for severity: " + severity);
            assertEquals(severity, response.getBody().getSeverity());
        }
    }

    // ─── Role Authorization Tests ──────────────────────────────────────────────

    @Test
    void createCourseCondition_success_withCourseAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        CourseConditionCreateRequest request = new CourseConditionCreateRequest();
        request.setConditionType("COURSE_OVERALL");
        request.setSeverity("LOW");
        request.setDescription("Test");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        CourseConditionDto expected = new CourseConditionDto();
        expected.setId(CONDITION_ID);
        when(operationsService.createCourseCondition(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<CourseConditionDto> response =
                controller.createCourseCondition(authentication, COURSE_ID, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }

    @Test
    void createCourseCondition_success_withSuperAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(true);

        CourseConditionCreateRequest request = new CourseConditionCreateRequest();
        request.setConditionType("COURSE_OVERALL");
        request.setSeverity("LOW");
        request.setDescription("Test");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        CourseConditionDto expected = new CourseConditionDto();
        expected.setId(CONDITION_ID);
        when(operationsService.createCourseCondition(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<CourseConditionDto> response =
                controller.createCourseCondition(authentication, COURSE_ID, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }
}
