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
import vnpt.vsp.module.operations.dto.PinPositionDto;
import vnpt.vsp.module.operations.dto.PinPositionCreateRequest;
import vnpt.vsp.module.operations.dto.PinPositionUpdateRequest;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link PinPositionController}.
 * Per Story 8.5 AC-1: pin placement/scheduling with effective + expiration times.
 * Per Architecture §10: requires GREENKEEPER or higher role.
 *
 * Tests Phase 5.2: Controller integration tests - auth, validation, happy path.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PinPositionControllerTest {

    @Mock private OperationsService operationsService;
    @Mock private RoleService roleService;
    @Mock private Authentication authentication;

    private PinPositionController controller;

    private static final Long COURSE_ID = 1L;
    private static final Integer HOLE_NUMBER = 5;
    private static final Long ACCOUNT_ID = 100L;
    private static final String ACTOR_NAME = "greenkeeper@vsp.com";
    private static final Long PIN_ID = 10L;

    @BeforeEach
    void setUp() {
        controller = new PinPositionController(operationsService, roleService);
        when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
        when(authentication.getName()).thenReturn(ACTOR_NAME);
    }

    private void allowGreenkeeper() {
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(true);
    }

    // ─── Auth Tests ─────────────────────────────────────────────────────────────

    @Test
    void createPin_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createPin(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void createPin_unauthorized_returns403_whenOnlyGolferRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createPin(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    @Test
    void getPinsForHole_unauthorized_returns403_whenNoRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getPinsForHole(authentication, COURSE_ID, HOLE_NUMBER, null));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ─── Happy Path Tests ──────────────────────────────────────────────────────

    @Test
    void createPin_success_returns201() {
        // Given
        allowGreenkeeper();

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        request.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));
        request.setConfidence(new BigDecimal("0.95"));

        PinPositionDto expected = new PinPositionDto();
        expected.setId(PIN_ID);
        expected.setCourseId(COURSE_ID);
        expected.setHoleNumber(HOLE_NUMBER);
        expected.setPosition("POINT(106.123 10.456)");
        expected.setEffectiveFrom(Instant.parse("2026-08-01T06:00:00Z"));
        expected.setExpiresAt(Instant.parse("2026-08-01T18:00:00Z"));
        expected.setPublishedBy(ACTOR_NAME);
        expected.setConfidence(new BigDecimal("0.95"));

        when(operationsService.createPinPosition(
                eq(COURSE_ID), eq(HOLE_NUMBER), eq("POINT(106.123 10.456)"),
                eq(Instant.parse("2026-08-01T06:00:00Z")),
                eq(Instant.parse("2026-08-01T18:00:00Z")),
                eq(ACTOR_NAME), eq(new BigDecimal("0.95"))
        )).thenReturn(expected);

        // When
        ResponseEntity<PinPositionDto> response = controller.createPin(
                authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(PIN_ID, response.getBody().getId());
        assertEquals(COURSE_ID, response.getBody().getCourseId());
        assertEquals(HOLE_NUMBER, response.getBody().getHoleNumber());
        assertEquals("POINT(106.123 10.456)", response.getBody().getPosition());
        assertEquals(ACTOR_NAME, response.getBody().getPublishedBy());
    }

    @Test
    void updatePin_success_returns200() {
        // Given
        allowGreenkeeper();

        PinPositionUpdateRequest request = new PinPositionUpdateRequest();
        request.setPosition("POINT(106.789 10.123)");
        request.setEffectiveFrom(Instant.parse("2026-08-02T06:00:00Z"));
        request.setExpiresAt(Instant.parse("2026-08-02T18:00:00Z"));

        PinPositionDto expected = new PinPositionDto();
        expected.setId(PIN_ID);
        expected.setCourseId(COURSE_ID);
        expected.setHoleNumber(HOLE_NUMBER);
        expected.setPosition("POINT(106.789 10.123)");
        expected.setEffectiveFrom(Instant.parse("2026-08-02T06:00:00Z"));
        expected.setExpiresAt(Instant.parse("2026-08-02T18:00:00Z"));

        when(operationsService.updatePinPosition(
                eq(PIN_ID), eq("POINT(106.789 10.123)"),
                eq(Instant.parse("2026-08-02T06:00:00Z")),
                eq(Instant.parse("2026-08-02T18:00:00Z"))
        )).thenReturn(expected);

        // When
        ResponseEntity<PinPositionDto> response = controller.updatePin(
                authentication, COURSE_ID, HOLE_NUMBER, PIN_ID, request);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(PIN_ID, response.getBody().getId());
        assertEquals("POINT(106.789 10.123)", response.getBody().getPosition());
    }

    @Test
    void getPinsForHole_success_returns200() {
        // Given
        allowGreenkeeper();

        PinPositionDto pin = new PinPositionDto();
        pin.setId(PIN_ID);
        pin.setCourseId(COURSE_ID);
        pin.setHoleNumber(HOLE_NUMBER);
        pin.setPosition("POINT(106.123 10.456)");
        pin.setEffectiveFrom(Instant.now().minusSeconds(1800));
        pin.setExpiresAt(Instant.now().plusSeconds(1800));

        when(operationsService.getPinPositions(eq(COURSE_ID), eq(HOLE_NUMBER), any()))
                .thenReturn(List.of(pin));

        // When
        ResponseEntity<List<PinPositionDto>> response =
                controller.getPinsForHole(authentication, COURSE_ID, HOLE_NUMBER, Instant.now());

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(1, response.getBody().size());
        assertEquals(PIN_ID, response.getBody().get(0).getId());
    }

    @Test
    void getAllPinsForCourse_success_returns200() {
        // Given
        allowGreenkeeper();

        PinPositionDto pin1 = new PinPositionDto();
        pin1.setId(1L);
        pin1.setHoleNumber(1);
        pin1.setPosition("POINT(106.1 10.1)");

        PinPositionDto pin2 = new PinPositionDto();
        pin2.setId(2L);
        pin2.setHoleNumber(2);
        pin2.setPosition("POINT(106.2 10.2)");

        when(operationsService.getAllPinPositions(eq(COURSE_ID), any()))
                .thenReturn(List.of(pin1, pin2));

        // When
        ResponseEntity<List<PinPositionDto>> response =
                controller.getAllPinsForCourse(authentication, COURSE_ID, Instant.now());

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().size());
    }

    @Test
    void getPinsForHole_withAsOfDate_passesDateToService() {
        // Given
        allowGreenkeeper();

        Instant asOfDate = Instant.parse("2026-08-01T12:00:00Z");
        when(operationsService.getPinPositions(COURSE_ID, HOLE_NUMBER, asOfDate))
                .thenReturn(List.of());

        // When
        controller.getPinsForHole(authentication, COURSE_ID, HOLE_NUMBER, asOfDate);

        // Then
        verify(operationsService).getPinPositions(COURSE_ID, HOLE_NUMBER, asOfDate);
    }

    // ─── Validation Tests ──────────────────────────────────────────────────────

    @Test
    void createPin_throwsServiceValidation_whenEffectiveFromMissing() {
        // Given
        allowGreenkeeper();

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        // effectiveFrom is null
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        when(operationsService.createPinPosition(
                eq(COURSE_ID), eq(HOLE_NUMBER), any(), isNull(), any(), any(), any()
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_002,
                "effectiveFrom is required", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createPin(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.VALIDATION_002, ex.getErrorCode());
    }

    @Test
    void createPin_throwsServiceValidation_whenExpiresAtMissing() {
        // Given
        allowGreenkeeper();

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.now());
        // expiresAt is null - this is validated in service

        when(operationsService.createPinPosition(
                eq(COURSE_ID), eq(HOLE_NUMBER), any(), any(), isNull(), any(), any()
        )).thenThrow(new VspApiException(VspErrorCode.VALIDATION_002,
                "expiresAt is required for pin positions (per AC-3)", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createPin(authentication, COURSE_ID, HOLE_NUMBER, request));
        assertEquals(VspErrorCode.VALIDATION_002, ex.getErrorCode());
    }

    @Test
    void updatePin_throwsNotFound_whenPinDoesNotExist() {
        // Given
        allowGreenkeeper();

        PinPositionUpdateRequest request = new PinPositionUpdateRequest();
        request.setPosition("POINT(1 2)");

        when(operationsService.updatePinPosition(eq(999L), any(), any(), any()))
                .thenThrow(new VspApiException(VspErrorCode.PIN_001,
                        "Pin position not found: 999", null, null));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updatePin(authentication, COURSE_ID, HOLE_NUMBER, 999L, request));
        assertEquals(VspErrorCode.PIN_001, ex.getErrorCode());
    }

    // ─── Role Authorization Tests ──────────────────────────────────────────────

    @Test
    void createPin_success_withCourseAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        PinPositionDto expected = new PinPositionDto();
        expected.setId(PIN_ID);
        when(operationsService.createPinPosition(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<PinPositionDto> response = controller.createPin(
                authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }

    @Test
    void createPin_success_withSuperAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.GREENKEEPER)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(true);

        PinPositionCreateRequest request = new PinPositionCreateRequest();
        request.setPosition("POINT(106.123 10.456)");
        request.setEffectiveFrom(Instant.now());
        request.setExpiresAt(Instant.now().plusSeconds(3600));

        PinPositionDto expected = new PinPositionDto();
        expected.setId(PIN_ID);
        when(operationsService.createPinPosition(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(expected);

        // When
        ResponseEntity<PinPositionDto> response = controller.createPin(
                authentication, COURSE_ID, HOLE_NUMBER, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
    }
}
