package vnpt.vsp.module.privacy;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.identity.entity.GolferAccount;
import vnpt.vsp.module.identity.repository.GolferAccountRepository;
import vnpt.vsp.module.privacy.dto.CreatePrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.ProcessPrivacyRequestRequest;
import vnpt.vsp.module.privacy.dto.PrivacyRequestResponse;
import vnpt.vsp.module.privacy.entity.PrivacyRequest;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.RequestType;
import vnpt.vsp.module.privacy.entity.PrivacyRequest.Status;
import vnpt.vsp.module.privacy.repository.PrivacyRequestRepository;
import vnpt.vsp.module.round.entity.Round;
import vnpt.vsp.module.round.repository.RoundRepository;
import vnpt.vsp.module.score.entity.Score;
import vnpt.vsp.module.score.repository.ScoreRepository;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link PrivacyServiceImpl}.
 * Per Story 2.5 AC-3: Users can request data export, account deletion,
 * round deletion with auditable processing.
 * <p>
 * Tests: create DATA_EXPORT request, create ACCOUNT_DELETION request (blocks with active rounds),
 * create ROUND_DELETION request (requires valid round ownership), processRequest transitions,
 * deleteAccount anonymization, deleteRound soft-delete.
 */
@ExtendWith(MockitoExtension.class)
class PrivacyServiceImplTest {

    @Mock
    private PrivacyRequestRepository privacyRequestRepository;

    @Mock
    private GolferAccountRepository golferAccountRepository;

    @Mock
    private RoundRepository roundRepository;

    @Mock
    private ScoreRepository scoreRepository;

    @Mock
    private AuditService auditService;

    private PrivacyServiceImpl privacyService;

    @BeforeEach
    void setUp() {
        privacyService = new PrivacyServiceImpl(
                privacyRequestRepository,
                golferAccountRepository,
                roundRepository,
                scoreRepository,
                auditService
        );
    }

    // ─── Create request tests ───────────────────────────────────────────────

    @Test
    void createRequest_dataExport_createsPendingRequest() {
        Long accountId = 42L;
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("DATA_EXPORT", null);

        PrivacyRequest savedRequest = new PrivacyRequest();
        savedRequest.setId(1L);
        savedRequest.setRequesterGolferAccountId(accountId);
        savedRequest.setRequestType(RequestType.DATA_EXPORT);
        savedRequest.setStatus(Status.PENDING);
        savedRequest.setRequestedAt(Instant.now());

        when(privacyRequestRepository.save(any(PrivacyRequest.class))).thenReturn(savedRequest);

        PrivacyRequestResponse response = privacyService.createRequest(accountId, request);

        assertNotNull(response);
        assertEquals(1L, response.getId());
        assertEquals("DATA_EXPORT", response.getRequestType());
        assertEquals("PENDING", response.getStatus());
        verify(privacyRequestRepository).save(any(PrivacyRequest.class));
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.PRIVACY_REQUEST_SUBMITTED),
                eq("PrivacyRequest"),
                eq("1"),
                isNull(),
                anyString(),
                isNull()
        );
    }

    @Test
    void createRequest_accountDeletionWithActiveRounds_throwsPRIVACY_004() {
        Long accountId = 42L;
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("ACCOUNT_DELETION", null);

        when(roundRepository.countByGolferAccountIdAndDeletedAtIsNull(accountId)).thenReturn(3L);

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.createRequest(accountId, request));
        assertEquals(VspErrorCode.PRIVACY_004, exception.getErrorCode());
    }

    @Test
    void createRequest_accountDeletionWithNoActiveRounds_createsRequest() {
        Long accountId = 42L;
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("ACCOUNT_DELETION", null);

        PrivacyRequest savedRequest = new PrivacyRequest();
        savedRequest.setId(2L);
        savedRequest.setRequesterGolferAccountId(accountId);
        savedRequest.setRequestType(RequestType.ACCOUNT_DELETION);
        savedRequest.setStatus(Status.PENDING);
        savedRequest.setRequestedAt(Instant.now());

        when(roundRepository.countByGolferAccountIdAndDeletedAtIsNull(accountId)).thenReturn(0L);
        when(privacyRequestRepository.save(any(PrivacyRequest.class))).thenReturn(savedRequest);

        PrivacyRequestResponse response = privacyService.createRequest(accountId, request);

        assertNotNull(response);
        assertEquals("ACCOUNT_DELETION", response.getRequestType());
        assertEquals("PENDING", response.getStatus());
    }

    @Test
    void createRequest_roundDeletionWithInvalidRoundId_throwsPRIVACY_005() {
        Long accountId = 42L;
        UUID roundId = UUID.randomUUID();
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("ROUND_DELETION", roundId);

        when(roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, accountId))
                .thenReturn(Optional.empty());

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.createRequest(accountId, request));
        assertEquals(VspErrorCode.PRIVACY_005, exception.getErrorCode());
    }

    @Test
    void createRequest_roundDeletionWithValidRound_createsRequest() {
        Long accountId = 42L;
        UUID roundId = UUID.randomUUID();
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("ROUND_DELETION", roundId);

        Round round = new Round();
        round.setId(roundId);
        round.setGolferAccountId(accountId);

        PrivacyRequest savedRequest = new PrivacyRequest();
        savedRequest.setId(3L);
        savedRequest.setRequesterGolferAccountId(accountId);
        savedRequest.setRequestType(RequestType.ROUND_DELETION);
        savedRequest.setStatus(Status.PENDING);
        savedRequest.setTargetRoundId(roundId);
        savedRequest.setRequestedAt(Instant.now());

        when(roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, accountId))
                .thenReturn(Optional.of(round));
        when(privacyRequestRepository.save(any(PrivacyRequest.class))).thenReturn(savedRequest);

        PrivacyRequestResponse response = privacyService.createRequest(accountId, request);

        assertNotNull(response);
        assertEquals("ROUND_DELETION", response.getRequestType());
        assertEquals(roundId, response.getTargetRoundId());
    }

    @Test
    void createRequest_invalidRequestType_throwsPRIVACY_006() {
        Long accountId = 42L;
        CreatePrivacyRequestRequest request = new CreatePrivacyRequestRequest("INVALID_TYPE", null);

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.createRequest(accountId, request));
        assertEquals(VspErrorCode.PRIVACY_006, exception.getErrorCode());
    }

    // ─── Process request tests ─────────────────────────────────────────────

    @Test
    void processRequest_pendingToProcessing_transitionsStatus() {
        Long adminId = 1L;
        Long requestId = 5L;

        PrivacyRequest existingRequest = new PrivacyRequest();
        existingRequest.setId(requestId);
        existingRequest.setRequesterGolferAccountId(42L);
        existingRequest.setRequestType(RequestType.DATA_EXPORT);
        existingRequest.setStatus(Status.PENDING);

        PrivacyRequest savedRequest = new PrivacyRequest();
        savedRequest.setId(requestId);
        savedRequest.setRequesterGolferAccountId(42L);
        savedRequest.setRequestType(RequestType.DATA_EXPORT);
        savedRequest.setStatus(Status.PROCESSING);
        savedRequest.setProcessedBy(adminId);
        savedRequest.setProcessedAt(Instant.now());

        ProcessPrivacyRequestRequest processRequest = new ProcessPrivacyRequestRequest("PROCESSING", null);

        when(privacyRequestRepository.findById(requestId)).thenReturn(Optional.of(existingRequest));
        when(privacyRequestRepository.save(any(PrivacyRequest.class))).thenReturn(savedRequest);

        PrivacyRequestResponse response = privacyService.processRequest(adminId, requestId, processRequest);

        assertNotNull(response);
        assertEquals("PROCESSING", response.getStatus());
        assertEquals(adminId, response.getProcessedBy());
        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.PRIVACY_REQUEST_PROCESSED),
                eq("PrivacyRequest"),
                eq("5"),
                anyString(),
                anyString(),
                isNull()
        );
    }

    @Test
    void processRequest_alreadyCompleted_throwsPRIVACY_002() {
        Long adminId = 1L;
        Long requestId = 5L;

        PrivacyRequest existingRequest = new PrivacyRequest();
        existingRequest.setId(requestId);
        existingRequest.setStatus(Status.COMPLETED);

        ProcessPrivacyRequestRequest processRequest = new ProcessPrivacyRequestRequest("PROCESSING", null);

        when(privacyRequestRepository.findById(requestId)).thenReturn(Optional.of(existingRequest));

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.processRequest(adminId, requestId, processRequest));
        assertEquals(VspErrorCode.PRIVACY_002, exception.getErrorCode());
    }

    @Test
    void processRequest_rejectWithReason_setsRejectionReason() {
        Long adminId = 1L;
        Long requestId = 6L;

        PrivacyRequest existingRequest = new PrivacyRequest();
        existingRequest.setId(requestId);
        existingRequest.setRequesterGolferAccountId(42L);
        existingRequest.setRequestType(RequestType.ACCOUNT_DELETION);
        existingRequest.setStatus(Status.PENDING);

        PrivacyRequest savedRequest = new PrivacyRequest();
        savedRequest.setId(requestId);
        savedRequest.setRequesterGolferAccountId(42L);
        savedRequest.setRequestType(RequestType.ACCOUNT_DELETION);
        savedRequest.setStatus(Status.REJECTED);
        savedRequest.setProcessedBy(adminId);
        savedRequest.setProcessedAt(Instant.now());
        savedRequest.setRejectionReason("Account has active disputes");

        ProcessPrivacyRequestRequest processRequest = new ProcessPrivacyRequestRequest("REJECTED", "Account has active disputes");

        when(privacyRequestRepository.findById(requestId)).thenReturn(Optional.of(existingRequest));
        when(privacyRequestRepository.save(any(PrivacyRequest.class))).thenReturn(savedRequest);

        PrivacyRequestResponse response = privacyService.processRequest(adminId, requestId, processRequest);

        assertNotNull(response);
        assertEquals("REJECTED", response.getStatus());
        assertEquals("Account has active disputes", response.getRejectionReason());
    }

    @Test
    void processRequest_notFound_throwsPRIVACY_001() {
        Long adminId = 1L;
        Long requestId = 999L;
        ProcessPrivacyRequestRequest processRequest = new ProcessPrivacyRequestRequest("PROCESSING", null);

        when(privacyRequestRepository.findById(requestId)).thenReturn(Optional.empty());

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.processRequest(adminId, requestId, processRequest));
        assertEquals(VspErrorCode.PRIVACY_001, exception.getErrorCode());
    }

    @Test
    void processRequest_invalidStatusTransition_throwsPRIVACY_003() {
        Long adminId = 1L;
        Long requestId = 7L;

        PrivacyRequest existingRequest = new PrivacyRequest();
        existingRequest.setId(requestId);
        existingRequest.setStatus(Status.PENDING);

        // Try to transition PENDING → COMPLETED (invalid: must go through PROCESSING first)
        ProcessPrivacyRequestRequest processRequest = new ProcessPrivacyRequestRequest("COMPLETED", null);

        when(privacyRequestRepository.findById(requestId)).thenReturn(Optional.of(existingRequest));

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.processRequest(adminId, requestId, processRequest));
        assertEquals(VspErrorCode.PRIVACY_003, exception.getErrorCode());
    }

    // ─── deleteAccount tests ───────────────────────────────────────────────

    @Test
    void deleteAccount_anonymizesAccount() {
        Long accountId = 42L;

        GolferAccount account = new GolferAccount();
        account.setId(accountId);
        account.setDisplayName("John Doe");
        account.setPhone("+84123456789");
        account.setEmail("john@example.com");
        account.setPasswordHash("hashed");
        account.setStatus(GolferAccount.Status.ACTIVE);

        when(golferAccountRepository.findById(accountId)).thenReturn(Optional.of(account));
        when(golferAccountRepository.save(any(GolferAccount.class))).thenReturn(account);

        privacyService.deleteAccount(accountId);

        verify(golferAccountRepository).save(argThat(saved -> {
            return "Deleted User".equals(saved.getDisplayName())
                    && saved.getPhone() == null
                    && saved.getEmail() == null
                    && saved.getPasswordHash() == null
                    && saved.getGoogleSubject() == null
                    && saved.getAppleSubject() == null
                    && saved.getAnonymizedAt() != null
                    && saved.getAnonymizedData() != null
                    && saved.getStatus() == GolferAccount.Status.DELETED;
        }));

        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.ACCOUNT_DELETED),
                eq("GolferAccount"),
                eq("42"),
                anyString(),
                anyString(),
                isNull()
        );
    }

    @Test
    void deleteAccount_notFound_throwsAUTH_010() {
        Long accountId = 999L;

        when(golferAccountRepository.findById(accountId)).thenReturn(Optional.empty());

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.deleteAccount(accountId));
        assertEquals(VspErrorCode.AUTH_010, exception.getErrorCode());
    }

    // ─── deleteRound tests ─────────────────────────────────────────────────

    @Test
    void deleteRound_softDeletesRoundAndScores() {
        Long accountId = 42L;
        UUID roundId = UUID.randomUUID();

        Round round = new Round();
        round.setId(roundId);
        round.setGolferAccountId(accountId);
        round.setStatus(Round.RoundStatus.COMPLETED);

        Score score1 = new Score();
        score1.setId(UUID.randomUUID());
        score1.setRoundId(roundId);

        Score score2 = new Score();
        score2.setId(UUID.randomUUID());
        score2.setRoundId(roundId);

        when(roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, accountId))
                .thenReturn(Optional.of(round));
        when(roundRepository.save(any(Round.class))).thenReturn(round);
        when(scoreRepository.findByRoundIdAndDeletedAtIsNull(roundId))
                .thenReturn(List.of(score1, score2));

        privacyService.deleteRound(accountId, roundId);

        verify(roundRepository).save(argThat(r -> r.getDeletedAt() != null));
        verify(scoreRepository, times(2)).save(argThat(s -> s.getDeletedAt() != null));

        verify(auditService).log(
                eq(vnpt.vsp.module.audit.AuditAction.ROUND_DELETED),
                eq("Round"),
                eq(roundId.toString()),
                anyString(),
                anyString(),
                isNull()
        );
    }

    @Test
    void deleteRound_roundNotFound_throwsPRIVACY_005() {
        Long accountId = 42L;
        UUID roundId = UUID.randomUUID();

        when(roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, accountId))
                .thenReturn(Optional.empty());

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.deleteRound(accountId, roundId));
        assertEquals(VspErrorCode.PRIVACY_005, exception.getErrorCode());
    }

    // ─── getMyRequests tests ───────────────────────────────────────────────

    @Test
    void getMyRequests_returnsAllRequestsForAccount() {
        Long accountId = 42L;

        PrivacyRequest request1 = new PrivacyRequest();
        request1.setId(1L);
        request1.setRequesterGolferAccountId(accountId);
        request1.setRequestType(RequestType.DATA_EXPORT);
        request1.setStatus(Status.PENDING);
        request1.setRequestedAt(Instant.now());

        PrivacyRequest request2 = new PrivacyRequest();
        request2.setId(2L);
        request2.setRequesterGolferAccountId(accountId);
        request2.setRequestType(RequestType.ACCOUNT_DELETION);
        request2.setStatus(Status.COMPLETED);
        request2.setRequestedAt(Instant.now());

        when(privacyRequestRepository.findByRequesterGolferAccountId(accountId))
                .thenReturn(List.of(request1, request2));

        List<PrivacyRequestResponse> responses = privacyService.getMyRequests(accountId);

        assertEquals(2, responses.size());
    }

    @Test
    void getRequestById_notFound_throwsPRIVACY_001() {
        Long accountId = 42L;
        Long requestId = 999L;

        when(privacyRequestRepository.findByIdAndRequesterGolferAccountId(requestId, accountId))
                .thenReturn(Optional.empty());

        VspApiException exception = assertThrows(VspApiException.class,
                () -> privacyService.getRequestById(accountId, requestId));
        assertEquals(VspErrorCode.PRIVACY_001, exception.getErrorCode());
    }
}
