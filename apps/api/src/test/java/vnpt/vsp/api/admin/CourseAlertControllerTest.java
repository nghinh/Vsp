package vnpt.vsp.api.admin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
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
import vnpt.vsp.api.pagination.PageTokenService;
import vnpt.vsp.module.coursealert.CourseAlertService;
import vnpt.vsp.module.coursealert.dto.CourseAlertCreateRequest;
import vnpt.vsp.module.coursealert.dto.CourseAlertListResponse;
import vnpt.vsp.module.coursealert.dto.CourseAlertResponse;
import vnpt.vsp.module.coursealert.dto.CourseAlertUpdateRequest;
import vnpt.vsp.module.coursealert.entity.AlertTargetType;
import vnpt.vsp.module.coursealert.entity.AlertType;
import vnpt.vsp.module.coursealert.entity.CourseAlert;
import vnpt.vsp.module.coursealert.entity.DeliveryStatus;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseAlertController}.
 * Per Story 8.6:
 * - AC-1: targeting scope
 * - AC-2: alertType visual distinction
 * - AC-3: delivery/expiry/acknowledge/audit
 * Uses pure Mockito — no Spring context loading required.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CourseAlertControllerTest {

    @Mock
    private CourseAlertService alertService;

    @Mock
    private RoleService roleService;

    @Mock
    private PageTokenService pageTokenService;

    @Mock
    private Authentication authentication;

    private CourseAlertController controller;
    private ObjectMapper objectMapper;

    private static final Long ACCOUNT_ID = 100L;
    private static final String ACTOR_NAME = "admin@vsp.com";

    @BeforeEach
    void setUp() {
        controller = new CourseAlertController(alertService, roleService, pageTokenService);
        objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());

        when(authentication.getPrincipal()).thenReturn(ACCOUNT_ID);
        when(authentication.getName()).thenReturn(ACTOR_NAME);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(true);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST /admin/alerts — create and send alert
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void createAlert_returns201WithCreatedAlert() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        CourseAlert alert = createAlert(1L, request);
        when(alertService.sendAlert(any(CourseAlertCreateRequest.class), anyString()))
                .thenReturn(alert);

        // When
        ResponseEntity<CourseAlertResponse> response = controller.createAlert(authentication, request);

        // Then
        assertEquals(201, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(1L, response.getBody().getId());
        assertEquals(AlertType.SAFETY, response.getBody().getAlertType());
        verify(roleService).hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN);
    }

    @Test
    void createAlert_forbidden_whenNoCourseAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);
        CourseAlertCreateRequest request = createValidRequest();

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createAlert(authentication, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /admin/alerts — list alerts with filtering
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void listAlerts_returns200WithPaginatedAlerts() {
        // Given
        CourseAlert alert1 = createAlert(1L, createValidRequest());
        alert1.setAlertType(AlertType.SAFETY);
        CourseAlert alert2 = createAlert(2L, createValidRequest());
        alert2.setAlertType(AlertType.PROMOTION);
        when(alertService.listAlerts(any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(alert1, alert2));

        // When
        ResponseEntity<CourseAlertListResponse> response = controller.listAlerts(
                authentication, null, null, null, null, null, null, null, 20);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(2, response.getBody().getAlerts().size());
    }

    @Test
    void listAlerts_filtersByAlertType() {
        // Given
        CourseAlert safetyAlert = createAlert(1L, createValidRequest());
        safetyAlert.setAlertType(AlertType.SAFETY);
        when(alertService.listAlerts(eq(AlertType.SAFETY), any(), any(), any(), any(), any()))
                .thenReturn(List.of(safetyAlert));

        // When
        ResponseEntity<CourseAlertListResponse> response = controller.listAlerts(
                authentication, AlertType.SAFETY, null, null, null, null, null, null, 20);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertEquals(1, response.getBody().getAlerts().size());
        assertEquals(AlertType.SAFETY, response.getBody().getAlerts().get(0).getAlertType());
    }

    @Test
    void listAlerts_filtersByTargetTypeAndId() {
        // Given
        UUID targetId = UUID.randomUUID();
        CourseAlert courseAlert = createAlert(1L, createValidRequest());
        courseAlert.setCourseId(targetId);
        when(alertService.listAlerts(any(), eq(AlertTargetType.COURSE), eq(targetId), any(), any(), any()))
                .thenReturn(List.of(courseAlert));

        // When
        ResponseEntity<CourseAlertListResponse> response = controller.listAlerts(
                authentication, null, AlertTargetType.COURSE, targetId, null, null, null, null, 20);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertEquals(1, response.getBody().getAlerts().size());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GET /admin/alerts/{alertId} — get alert detail
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void getAlert_returns200WithAlertDetail() {
        // Given
        Long alertId = 1L;
        CourseAlert alert = createAlert(alertId, createValidRequest());
        when(alertService.getAlert(alertId)).thenReturn(alert);

        // When
        ResponseEntity<CourseAlertResponse> response = controller.getAlert(authentication, alertId);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(alertId, response.getBody().getId());
    }

    @Test
    void getAlert_notFound_whenAlertDoesNotExist() {
        // Given
        Long alertId = 999L;
        when(alertService.getAlert(alertId))
                .thenThrow(new VspApiException(VspErrorCode.ALERT_001));

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getAlert(authentication, alertId));
        assertEquals(VspErrorCode.ALERT_001, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PATCH /admin/alerts/{alertId} — update alert
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void updateAlert_returns200WithUpdatedAlert() {
        // Given
        Long alertId = 1L;
        CourseAlertUpdateRequest updateRequest = new CourseAlertUpdateRequest();
        updateRequest.setTitle("Updated Title");
        CourseAlert updatedAlert = createAlert(alertId, createValidRequest());
        updatedAlert.setTitle("Updated Title");
        when(alertService.updateAlert(eq(alertId), any(CourseAlertUpdateRequest.class)))
                .thenReturn(updatedAlert);

        // When
        ResponseEntity<CourseAlertResponse> response =
                controller.updateAlert(authentication, alertId, updateRequest);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals("Updated Title", response.getBody().getTitle());
    }

    @Test
    void updateAlert_conflict_whenAlertAlreadyEffective() {
        // Given
        Long alertId = 1L;
        CourseAlertUpdateRequest updateRequest = new CourseAlertUpdateRequest();
        updateRequest.setTitle("Updated Title");
        when(alertService.updateAlert(eq(alertId), any(CourseAlertUpdateRequest.class)))
                .thenThrow(new VspApiException(VspErrorCode.ALERT_002));

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.updateAlert(authentication, alertId, updateRequest));
        assertEquals(VspErrorCode.ALERT_002, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DELETE /admin/alerts/{alertId} — cancel alert
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void cancelAlert_returns204() {
        // Given
        Long alertId = 1L;
        doNothing().when(alertService).cancelAlert(eq(alertId), anyString());

        // When
        ResponseEntity<Void> response = controller.cancelAlert(authentication, alertId);

        // Then
        assertEquals(204, response.getStatusCode().value());
        verify(alertService).cancelAlert(eq(alertId), eq(String.valueOf(ACCOUNT_ID)));
    }

    @Test
    void cancelAlert_notFound_whenAlertDoesNotExist() {
        // Given
        Long alertId = 999L;
        doThrow(new VspApiException(VspErrorCode.ALERT_001))
                .when(alertService).cancelAlert(eq(alertId), anyString());

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.cancelAlert(authentication, alertId));
        assertEquals(VspErrorCode.ALERT_001, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST /admin/alerts/{alertId}/acknowledge — acknowledge alert
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void acknowledgeAlert_returns200() {
        // Given
        Long alertId = 1L;
        doNothing().when(alertService).acknowledgeAlert(eq(alertId), anyString());

        // When
        ResponseEntity<Void> response = controller.acknowledgeAlert(authentication, alertId);

        // Then
        assertEquals(200, response.getStatusCode().value());
        verify(alertService).acknowledgeAlert(eq(alertId), eq(String.valueOf(ACCOUNT_ID)));
    }

    @Test
    void acknowledgeAlert_badRequest_whenNotRequired() {
        // Given
        Long alertId = 1L;
        doThrow(new VspApiException(VspErrorCode.ALERT_003))
                .when(alertService).acknowledgeAlert(eq(alertId), anyString());

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.acknowledgeAlert(authentication, alertId));
        assertEquals(VspErrorCode.ALERT_003, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RBAC enforcement
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void createAlert_forbidden_whenGolferRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);
        CourseAlertCreateRequest request = createValidRequest();

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.createAlert(authentication, request));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
        verify(alertService, never()).sendAlert(any(), anyString());
    }

    @Test
    void listAlerts_forbidden_whenNoAdminRole() {
        // Given
        when(roleService.hasRole(ACCOUNT_ID, RoleName.COURSE_ADMIN)).thenReturn(false);
        when(roleService.hasRole(ACCOUNT_ID, RoleName.SUPER_ADMIN)).thenReturn(false);

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.listAlerts(authentication, null, null, null, null, null, null, null, 20));
        assertEquals(VspErrorCode.AUTH_005, ex.getErrorCode());
        verify(alertService, never()).listAlerts(any(), any(), any(), any(), any(), any());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════════════════════

    private CourseAlertCreateRequest createValidRequest() {
        CourseAlertCreateRequest request = new CourseAlertCreateRequest();
        request.setCourseId(UUID.randomUUID());
        request.setAlertType(AlertType.SAFETY);
        request.setTitle("Lightning Advisory");
        request.setBody("Lightning detected within 10km. Seek shelter immediately.");
        return request;
    }

    private CourseAlert createAlert(Long id, CourseAlertCreateRequest request) {
        CourseAlert alert = new CourseAlert();
        alert.setId(id);
        alert.setCourseId(request.getCourseId());
        alert.setAlertType(request.getAlertType());
        alert.setTitle(request.getTitle());
        alert.setBody(request.getBody());
        alert.setPriority(1);
        alert.setEffectiveAt(OffsetDateTime.now());
        alert.setDeliveryStatus(DeliveryStatus.PENDING);
        alert.setAcknowledgmentRequired(false);
        alert.setCreatedBy(ACTOR_NAME);
        alert.setCreatedAt(Instant.now());
        alert.setPublishedVersion(1);
        alert.setVersion(1);
        return alert;
    }
}
