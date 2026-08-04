package vnpt.vsp.module.coursealert;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.coursealert.dto.CourseAlertCreateRequest;
import vnpt.vsp.module.coursealert.dto.CourseAlertUpdateRequest;
import vnpt.vsp.module.coursealert.entity.AlertTargetType;
import vnpt.vsp.module.coursealert.entity.AlertType;
import vnpt.vsp.module.coursealert.entity.CourseAlert;
import vnpt.vsp.module.coursealert.entity.DeliveryStatus;
import vnpt.vsp.module.coursealert.repository.CourseAlertRepository;
import vnpt.vsp.module.notification.NotificationService;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link CourseAlertServiceImpl}.
 * Per Story 8.6:
 * - AC-1: targeting validation
 * - AC-2: alertType visual distinction
 * - AC-3: delivery/expiry/acknowledge/audit
 */
@ExtendWith(MockitoExtension.class)
class CourseAlertServiceImplTest {

    @Mock
    private CourseAlertRepository alertRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private AuditService auditService;

    private CourseAlertServiceImpl alertService;

    private static final String CREATED_BY = "admin@vsp.com";
    private static final UUID COURSE_ID = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        alertService = new CourseAlertServiceImpl(alertRepository, notificationService, auditService);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-1: Targeting validation — sendAlert with valid targeting
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void sendAlert_withCourseTarget_succeeds() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        request.setCourseId(COURSE_ID);
        request.setAlertType(AlertType.SAFETY);

        CourseAlert savedAlert = createAlert(1L, request);
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(savedAlert);

        // When
        CourseAlert result = alertService.sendAlert(request, CREATED_BY);

        // Then
        assertNotNull(result);
        assertEquals(AlertType.SAFETY, result.getAlertType());
        assertEquals(COURSE_ID, result.getCourseId());
        assertEquals(DeliveryStatus.PENDING, result.getDeliveryStatus());
        verify(alertRepository).save(any(CourseAlert.class));
        verify(auditService).log(any(), anyString(), anyString(), any(), any(), any());
    }

    @Test
    void sendAlert_withFacilityTarget_succeeds() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        request.setFacilityId(UUID.randomUUID());
        request.setAlertType(AlertType.PROMOTION);

        CourseAlert savedAlert = createAlert(2L, request);
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(savedAlert);

        // When
        CourseAlert result = alertService.sendAlert(request, CREATED_BY);

        // Then
        assertNotNull(result);
        assertEquals(AlertType.PROMOTION, result.getAlertType());
        assertNotNull(result.getFacilityId());
    }

    @Test
    void sendAlert_withHoleTarget_succeeds() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        request.setHoleId(UUID.randomUUID());
        request.setAlertType(AlertType.SAFETY);

        CourseAlert savedAlert = createAlert(3L, request);
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(savedAlert);

        // When
        CourseAlert result = alertService.sendAlert(request, CREATED_BY);

        // Then
        assertNotNull(result);
        assertEquals(AlertType.SAFETY, result.getAlertType());
        assertNotNull(result.getHoleId());
    }

    @Test
    void sendAlert_withFlightTarget_succeeds() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        request.setFlightId(UUID.randomUUID());

        CourseAlert savedAlert = createAlert(4L, request);
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(savedAlert);

        // When
        CourseAlert result = alertService.sendAlert(request, CREATED_BY);

        // Then
        assertNotNull(result);
        assertNotNull(result.getFlightId());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-1: Targeting validation — sendAlert with no targeting fails
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void sendAlert_withNoTarget_fails() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        // Clear all targeting fields
        request.setFacilityId(null);
        request.setCourseId(null);
        request.setHoleId(null);
        request.setFlightId(null);
        request.setGroupId(null);

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> alertService.sendAlert(request, CREATED_BY));
        assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode());
        verify(alertRepository, never()).save(any());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-3: Delivery status transitions
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void sendAlert_setsDeliveryStatusToPending() {
        // Given
        CourseAlertCreateRequest request = createValidRequest();
        request.setCourseId(COURSE_ID);

        CourseAlert savedAlert = createAlert(1L, request);
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(savedAlert);

        // When
        CourseAlert result = alertService.sendAlert(request, CREATED_BY);

        // Then
        assertEquals(DeliveryStatus.PENDING, result.getDeliveryStatus());
    }

    @Test
    void cancelAlert_setsDeliveryStatusToExpired() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(existing);

        // When
        alertService.cancelAlert(alertId, CREATED_BY);

        // Then
        verify(alertRepository).save(argThat(alert ->
            alert.getDeliveryStatus() == DeliveryStatus.EXPIRED &&
            alert.getExpiresAt() != null
        ));
        verify(auditService).log(any(), anyString(), anyString(), any(), any(), any());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-3: Acknowledgment flow
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void acknowledgeAlert_succeeds_whenAcknowledgmentRequired() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        existing.setAcknowledgmentRequired(true);
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(existing);

        // When
        alertService.acknowledgeAlert(alertId, "golfer@vsp.com");

        // Then
        verify(alertRepository).save(argThat(alert ->
            alert.getAcknowledgedAt() != null &&
            "golfer@vsp.com".equals(alert.getAcknowledgedBy())
        ));
    }

    @Test
    void acknowledgeAlert_fails_whenAcknowledgmentNotRequired() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        existing.setAcknowledgmentRequired(false);
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> alertService.acknowledgeAlert(alertId, "golfer@vsp.com"));
        assertEquals(VspErrorCode.ALERT_003, ex.getErrorCode());
    }

    @Test
    void acknowledgeAlert_idempotent_whenAlreadyAcknowledged() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        existing.setAcknowledgmentRequired(true);
        existing.setAcknowledgedAt(java.time.Instant.now());
        existing.setAcknowledgedBy("first-golfer@vsp.com");
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));

        // When — should not throw, should be idempotent
        assertDoesNotThrow(() -> alertService.acknowledgeAlert(alertId, "second-golfer@vsp.com"));

        // Then — save should not be called again
        verify(alertRepository, never()).save(any());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-3: Update only before effectiveAt
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void updateAlert_succeeds_beforeEffective() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        existing.setEffectiveAt(OffsetDateTime.now().plusHours(1)); // future effective
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));
        when(alertRepository.save(any(CourseAlert.class))).thenReturn(existing);

        CourseAlertUpdateRequest updateRequest = new CourseAlertUpdateRequest();
        updateRequest.setTitle("Updated Title");

        // When
        CourseAlert result = alertService.updateAlert(alertId, updateRequest);

        // Then
        assertNotNull(result);
        verify(auditService).log(any(), anyString(), anyString(), any(), any(), any());
    }

    @Test
    void updateAlert_fails_afterEffective() {
        // Given
        Long alertId = 1L;
        CourseAlert existing = createAlert(alertId, createValidRequest());
        existing.setEffectiveAt(OffsetDateTime.now().minusHours(1)); // past effective
        when(alertRepository.findById(alertId)).thenReturn(Optional.of(existing));

        CourseAlertUpdateRequest updateRequest = new CourseAlertUpdateRequest();
        updateRequest.setTitle("Updated Title");

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> alertService.updateAlert(alertId, updateRequest));
        assertEquals(VspErrorCode.ALERT_002, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-1: List with targeting filters
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void listAlerts_filtersByAlertType() {
        // Given
        CourseAlert safetyAlert = createAlert(1L, createValidRequest());
        safetyAlert.setAlertType(AlertType.SAFETY);
        CourseAlert promoAlert = createAlert(2L, createValidRequest());
        promoAlert.setAlertType(AlertType.PROMOTION);
        promoAlert.setCourseId(COURSE_ID);

        when(alertRepository.findAll()).thenReturn(List.of(safetyAlert, promoAlert));

        // When
        List<CourseAlert> results = alertService.listAlerts(
                AlertType.SAFETY, null, null, null, null, null);

        // Then
        assertEquals(1, results.size());
        assertEquals(AlertType.SAFETY, results.get(0).getAlertType());
    }

    @Test
    void listAlerts_filtersByTargetTypeAndId() {
        // Given
        CourseAlert courseAlert = createAlert(1L, createValidRequest());
        courseAlert.setCourseId(COURSE_ID);
        CourseAlert facilityAlert = createAlert(2L, createValidRequest());
        facilityAlert.setCourseId(null); // clear courseId so only courseAlert matches
        facilityAlert.setFacilityId(UUID.randomUUID());

        when(alertRepository.findAll()).thenReturn(List.of(courseAlert, facilityAlert));

        // When
        List<CourseAlert> results = alertService.listAlerts(
                null, AlertTargetType.COURSE, COURSE_ID, null, null, null);

        // Then
        assertEquals(1, results.size());
        assertEquals(COURSE_ID, results.get(0).getCourseId());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AC-3: Expiry handling
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void getActiveAlertsForTarget_returnsOnlyActiveAlerts() {
        // Given
        UUID targetId = UUID.randomUUID();
        CourseAlert activeAlert = createAlert(1L, createValidRequest());
        activeAlert.setCourseId(targetId);
        activeAlert.setEffectiveAt(OffsetDateTime.now().minusHours(1));
        activeAlert.setExpiresAt(OffsetDateTime.now().plusHours(1));
        activeAlert.setDeliveryStatus(DeliveryStatus.DELIVERED);

        when(alertRepository.findActiveAlertsByCourseId(eq(targetId), any(OffsetDateTime.class)))
                .thenReturn(List.of(activeAlert));

        // When
        List<CourseAlert> results = alertService.getActiveAlertsForTarget(
                AlertTargetType.COURSE, targetId);

        // Then
        assertEquals(1, results.size());
        assertEquals(targetId, results.get(0).getCourseId());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Error handling
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    void getAlert_throwsNotFound_whenAlertDoesNotExist() {
        // Given
        Long alertId = 999L;
        when(alertRepository.findById(alertId)).thenReturn(Optional.empty());

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> alertService.getAlert(alertId));
        assertEquals(VspErrorCode.ALERT_001, ex.getErrorCode());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════════════════════

    private CourseAlertCreateRequest createValidRequest() {
        CourseAlertCreateRequest request = new CourseAlertCreateRequest();
        request.setCourseId(COURSE_ID);
        request.setAlertType(AlertType.SAFETY);
        request.setTitle("Lightning Advisory");
        request.setBody("Lightning detected within 10km. Seek shelter immediately.");
        return request;
    }

    private CourseAlert createAlert(Long id, CourseAlertCreateRequest request) {
        CourseAlert alert = new CourseAlert();
        alert.setId(id);
        alert.setCourseId(request.getCourseId());
        alert.setFacilityId(request.getFacilityId());
        alert.setHoleId(request.getHoleId());
        alert.setFlightId(request.getFlightId());
        alert.setGroupId(request.getGroupId());
        alert.setAlertType(request.getAlertType());
        alert.setTitle(request.getTitle());
        alert.setBody(request.getBody());
        alert.setPriority(1);
        alert.setEffectiveAt(OffsetDateTime.now());
        alert.setDeliveryStatus(DeliveryStatus.PENDING);
        alert.setAcknowledgmentRequired(request.getAcknowledgmentRequired() != null
                ? request.getAcknowledgmentRequired() : false);
        alert.setCreatedBy(CREATED_BY);
        alert.setCreatedAt(java.time.Instant.now());
        alert.setPublishedVersion(1);
        alert.setVersion(1);
        return alert;
    }
}
