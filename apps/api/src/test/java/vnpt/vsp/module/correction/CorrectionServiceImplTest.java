package vnpt.vsp.module.correction;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import org.mockito.ArgumentMatchers;
import org.springframework.data.jpa.domain.Specification;
import vnpt.vsp.module.correction.dto.CorrectionQueueRequest;
import vnpt.vsp.module.correction.dto.CorrectionQueueResponse;
import vnpt.vsp.module.correction.dto.CorrectionResolutionRequest;
import vnpt.vsp.module.correction.dto.CorrectionResolutionResponse;
import vnpt.vsp.module.correction.dto.CorrectionReviewRequest;
import vnpt.vsp.module.correction.entity.CorrectionReviewAction;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.entity.CorrectionType;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.notification.NotificationService;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.mockito.Mockito.doNothing;

/**
 * Unit tests for {@link CorrectionServiceImpl#resolveCorrection(Long, CorrectionResolutionRequest, Long)}.
 * Per Story 9.3 Wave 5 AC-1, AC-2, AC-3.
 *
 * <p>Test scenarios:
 * <ol>
 *   <li>Happy path: PENDING → APPROVED, status updated, audit logged, notification dispatched</li>
 *   <li>PENDING → REJECTED with reason</li>
 *   <li>Correction not found → CORRECTION_001</li>
 *   <li>Correction already reviewed (status = APPROVED) → CORRECTION_002</li>
 *   <li>Correction already reviewed (status = REJECTED) → CORRECTION_002</li>
 *   <li>IN_REVIEW → APPROVED (valid starting state)</li>
 *   <li>Reporter notification failure (notification service throws) — non-fatal, log and continue</li>
 *   <li>APPROVED with produceDraftChange = false — no draft created (stub)</li>
 *   <li>Audit entry contains all required fields: reviewer, decision, reason</li>
 *   <li>ResultingVersionId is null until publish (reflected in response)</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
class CorrectionServiceImplTest {

    @Mock private CourseCorrectionRepository correctionRepository;
    @Mock private CourseRepository courseRepository;
    @Mock private HoleRepository holeRepository;
    @Mock private AuditService auditService;
    @Mock private NotificationService notificationService;
    @Mock private ScorecardCorrectionService scorecardCorrectionService;

    private CorrectionServiceImpl correctionService;

    private Course course;
    private CourseCorrection pendingCorrection;

    @BeforeEach
    void setUp() {
        correctionService = new CorrectionServiceImpl(
                correctionRepository,
                courseRepository,
                holeRepository,
                auditService,
                notificationService,
                scorecardCorrectionService);

        course = new Course();
        course.setId(1L);
        course.setName("Pine Valley GC");

        pendingCorrection = createCorrection(1L, CorrectionStatus.PENDING);
    }

    // ─── Helper factories ─────────────────────────────────────────────────────────

    private CourseCorrection createCorrection(Long id, CorrectionStatus status) {
        CourseCorrection c = new CourseCorrection();
        c.setId(id);
        c.setCourseId(course.getId());
        c.setReporterId(200L);
        c.setCorrectionType(CorrectionType.PIN_POSITION);
        c.setStatus(status);
        c.setConfidence(BigDecimal.valueOf(85.0));
        c.setSubmittedAt(Instant.now());
        c.setReporterNote("Pin was at 18ft, now at 21ft per RTK survey");
        return c;
    }

    private CorrectionResolutionRequest approveRequest(boolean produceDraftChange) {
        return new CorrectionResolutionRequest(
                CorrectionResolutionRequest.Decision.APPROVE,
                "Verified per RTK survey",
                produceDraftChange);
    }

    private CorrectionResolutionRequest rejectRequest() {
        return new CorrectionResolutionRequest(
                CorrectionResolutionRequest.Decision.REJECT,
                "GPS data insufficient to confirm",
                false);
    }

    // ─── Happy path: PENDING → APPROVED ─────────────────────────────────────────

    @Test
    void resolveCorrection_approve_updatesStatusAndLogsAuditAndNotifiesReporter() {
        // Given
        Long reviewedBy = 99L;
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());
        when(notificationService.sendPushNotification(anyMap())).thenReturn("token-abc");

        // When
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                1L, approveRequest(false), reviewedBy);

        // Then
        assertEquals(CorrectionStatus.APPROVED.name(), response.status());
        assertEquals(1L, response.correctionId());
        assertNull(response.resultingVersionId()); // not published yet
        assertNull(response.auditId()); // AuditService is async, ID not available synchronously
        assertNotNull(response.notifiedAt());

        // Verify status transition
        assertEquals(CorrectionStatus.APPROVED, pendingCorrection.getStatus());
        assertEquals("Verified per RTK survey", pendingCorrection.getResolution());
        assertEquals(reviewedBy, pendingCorrection.getReviewedBy());
        assertNotNull(pendingCorrection.getReviewedAt());

        // Verify audit was called with CORRECTION_RESOLVED
        verify(auditService).log(
                eq(AuditAction.CORRECTION_RESOLVED),
                eq("Correction"),
                eq("1"),
                anyString(), // beforeJson
                anyString(), // afterJson
                anyString()); // metadata

        // Verify notification was dispatched
        ArgumentCaptor<Map<String, Object>> payloadCaptor = ArgumentCaptor.forClass(Map.class);
        verify(notificationService).sendPushNotification(payloadCaptor.capture());
        Map<String, Object> payload = payloadCaptor.getValue();
        assertEquals("CORRECTION_RESOLVED", payload.get("alertType"));
        assertEquals(1L, payload.get("targetId"));
    }

    // ─── Happy path: PENDING → REJECTED ─────────────────────────────────────────

    @Test
    void resolveCorrection_reject_updatesStatusAndLogsAuditAndNotifiesReporter() {
        // Given
        Long reviewedBy = 99L;
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());

        // When
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                1L, rejectRequest(), reviewedBy);

        // Then
        assertEquals(CorrectionStatus.REJECTED.name(), response.status());
        assertEquals(1L, response.correctionId());
        assertNull(response.auditId()); // AuditService is async, ID not available synchronously
        assertEquals(CorrectionStatus.REJECTED, pendingCorrection.getStatus());
        assertEquals("GPS data insufficient to confirm", pendingCorrection.getResolution());
    }

    // ─── IN_REVIEW → APPROVED is valid ──────────────────────────────────────────

    @Test
    void resolveCorrection_fromInReview_approvesSuccessfully() {
        // Given
        CourseCorrection inReviewCorrection = createCorrection(2L, CorrectionStatus.IN_REVIEW);
        Long reviewedBy = 99L;
        when(correctionRepository.findById(2L)).thenReturn(Optional.of(inReviewCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());

        // When
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                2L, approveRequest(false), reviewedBy);

        // Then
        assertEquals(CorrectionStatus.APPROVED.name(), response.status());
        assertEquals(CorrectionStatus.APPROVED, inReviewCorrection.getStatus());
    }

    // ─── review() must work on a PENDING correction ─────────────────────────────

    @Test
    void review_fromPending_requestsInfo() {
        // The review queue's four buttons all go through review(), and every one
        // of them used to fail on a correction the same screen showed as
        // Pending: the code demanded IN_REVIEW, and nothing in the system can
        // put a correction into IN_REVIEW — no endpoint calls markInReview().
        // The whole review workflow was unreachable.
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());

        CorrectionReviewRequest request = new CorrectionReviewRequest();
        request.setAction(CorrectionReviewAction.REQUEST_INFO);
        request.setReason("Gửi thêm ảnh chụp vị trí giúp mình nhé");

        CourseCorrection reviewed = correctionService.review(1L, request, 99L);

        assertEquals(CorrectionStatus.INFO_REQUESTED, reviewed.getStatus());
    }

    @Test
    void review_stillRefusesACorrectionAlreadyReviewed() {
        // The relaxation is PENDING only — a decision already taken must not be
        // quietly overwritten by a second reviewer.
        CourseCorrection approved = createCorrection(4L, CorrectionStatus.APPROVED);
        when(correctionRepository.findById(4L)).thenReturn(Optional.of(approved));

        CorrectionReviewRequest request = new CorrectionReviewRequest();
        request.setAction(CorrectionReviewAction.REJECT);
        request.setReason("nope");

        assertThrows(VspApiException.class, () -> correctionService.review(4L, request, 99L));
        assertEquals(CorrectionStatus.APPROVED, approved.getStatus());
    }

    // ─── Correction not found ───────────────────────────────────────────────────

    @Test
    void resolveCorrection_notFound_throwsCORRECTION_001() {
        // Given
        when(correctionRepository.findById(999L)).thenReturn(Optional.empty());

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class, () ->
                correctionService.resolveCorrection(999L, approveRequest(false), 99L));

        assertEquals(VspErrorCode.CORRECTION_001, ex.getErrorCode());
    }

    // ─── Already APPROVED ───────────────────────────────────────────────────────

    @Test
    void resolveCorrection_alreadyApproved_throwsCORRECTION_002() {
        // Given
        CourseCorrection approvedCorrection = createCorrection(3L, CorrectionStatus.APPROVED);
        when(correctionRepository.findById(3L)).thenReturn(Optional.of(approvedCorrection));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class, () ->
                correctionService.resolveCorrection(3L, approveRequest(false), 99L));

        assertEquals(VspErrorCode.CORRECTION_002, ex.getErrorCode());
    }

    // ─── Already REJECTED ──────────────────────────────────────────────────────

    @Test
    void resolveCorrection_alreadyRejected_throwsCORRECTION_002() {
        // Given
        CourseCorrection rejectedCorrection = createCorrection(4L, CorrectionStatus.REJECTED);
        when(correctionRepository.findById(4L)).thenReturn(Optional.of(rejectedCorrection));

        // When/Then
        VspApiException ex = assertThrows(VspApiException.class, () ->
                correctionService.resolveCorrection(4L, approveRequest(false), 99L));

        assertEquals(VspErrorCode.CORRECTION_002, ex.getErrorCode());
    }

    // ─── Notification failure is non-fatal ──────────────────────────────────────

    @Test
    void resolveCorrection_notificationFailure_stillReturnsSuccess() {
        // Given
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());
        when(notificationService.sendPushNotification(anyMap()))
                .thenThrow(new RuntimeException("FCM endpoint unreachable"));

        // When — must NOT throw
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                1L, approveRequest(false), 99L);

        // Then — resolution succeeded despite notification failure
        assertEquals(CorrectionStatus.APPROVED.name(), response.status());
        assertNull(response.auditId()); // AuditService is async, ID not available
        // notifiedAt may be null because notification threw before we could record it
    }

    // ─── Audit entry contains all required fields ────────────────────────────────

    @Test
    void resolveCorrection_auditEntry_containsReviewerDecisionAndReason() {
        // Given
        String reason = "Verified per RTK survey - pin offset by 3ft";
        CorrectionResolutionRequest request = new CorrectionResolutionRequest(
                CorrectionResolutionRequest.Decision.APPROVE,
                reason,
                false);
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());

        // When
        correctionService.resolveCorrection(1L, request, 99L);

        // Then
        ArgumentCaptor<String> metadataCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditService).log(
                eq(AuditAction.CORRECTION_RESOLVED),
                eq("Correction"),
                eq("1"),
                anyString(), // beforeJson
                anyString(), // afterJson
                metadataCaptor.capture());

        String metadata = metadataCaptor.getValue();
        assertTrue(metadata.contains("reviewedBy"));
        assertTrue(metadata.contains("99"));
        assertTrue(metadata.contains(reason));
    }

    // ─── produceDraftChange = false (stub — no draft entity in MVP) ──────────────

    @Test
    void resolveCorrection_approveWithProduceDraftChangeFalse_completesWithoutDraftCreation() {
        // Given
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());
        when(notificationService.sendPushNotification(anyMap())).thenReturn(null);

        // When
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                1L, approveRequest(false), 99L);

        // Then
        assertEquals(CorrectionStatus.APPROVED.name(), response.status());
        assertNull(response.resultingVersionId()); // no draft → no version yet
        // No additional repository calls beyond save
        verify(correctionRepository, times(1)).save(any(CourseCorrection.class));
    }

    // ─── Response fields are correctly populated ─────────────────────────────────

    @Test
    void resolveCorrection_response_containsAllFields() {
        // Given
        when(correctionRepository.findById(1L)).thenReturn(Optional.of(pendingCorrection));
        when(correctionRepository.save(any(CourseCorrection.class))).thenAnswer(inv -> inv.getArgument(0));
        doNothing().when(auditService).log(any(AuditAction.class), anyString(), anyString(),
                anyString(), anyString(), anyString());
        when(notificationService.sendPushNotification(anyMap())).thenReturn("token-xyz");

        // When
        CorrectionResolutionResponse response = correctionService.resolveCorrection(
                1L, approveRequest(true), 77L);

        // Then
        assertNotNull(response.correctionId());
        assertNotNull(response.status());
        assertNull(response.auditId()); // AuditService is async, ID not available synchronously
        assertNotNull(response.notifiedAt());
        // resultingVersionId is null until the draft is published
        assertNull(response.resultingVersionId());
    }

    // ─── The hole a reviewer is being sent to ─────────────────────────────────

    @Test
    void theQueueNamesTheHoleOnTheCardNotTheDatabaseRow() {
        // Hole 1 of Long Thành is row 127. The queue used to print the row id
        // in the hole-number column, so a report about the 1st arrived as
        // "hole 127" of an eighteen-hole course — a hole a reviewer cannot walk
        // to, on a card that does not have one.
        Hole hole = new Hole();
        hole.setId(127L);
        hole.setHoleNumber(1);

        CourseCorrection correction = createCorrection(1L, CorrectionStatus.PENDING);
        correction.setHoleId(127L);

        when(correctionRepository.findAll(ArgumentMatchers.<Specification<CourseCorrection>>any()))
                .thenReturn(List.of(correction));
        when(courseRepository.findAllById(anyIterable())).thenReturn(List.of(course));
        when(holeRepository.findAllById(anyIterable())).thenReturn(List.of(hole));

        CorrectionQueueResponse response =
                correctionService.getQueue(new CorrectionQueueRequest());

        assertEquals(1, response.getCorrections().get(0).getHoleNumber());
    }

    @Test
    void aCourseWideReportNamesNoHole() {
        CourseCorrection correction = createCorrection(2L, CorrectionStatus.PENDING);
        correction.setHoleId(null);

        when(correctionRepository.findAll(ArgumentMatchers.<Specification<CourseCorrection>>any()))
                .thenReturn(List.of(correction));
        when(courseRepository.findAllById(anyIterable())).thenReturn(List.of(course));

        CorrectionQueueResponse response =
                correctionService.getQueue(new CorrectionQueueRequest());

        // Null, not zero and not a row id. A report about the whole course is
        // not a report about hole 0.
        assertNull(response.getCorrections().get(0).getHoleNumber());
    }
}
