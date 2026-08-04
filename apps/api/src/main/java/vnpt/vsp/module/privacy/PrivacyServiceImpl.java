package vnpt.vsp.module.privacy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link PrivacyService}.
 * Per Story 2.5 AC-3: Users can request data export, account deletion,
 * and round deletion with auditable processing.
 * <p>
 * State machine: PENDING → PROCESSING → COMPLETED / REJECTED
 */
@Service
@vnpt.vsp.module.privacy.PrivacyModule
public class PrivacyServiceImpl implements PrivacyService {

    private static final Logger log = LoggerFactory.getLogger(PrivacyServiceImpl.class);

    private final PrivacyRequestRepository privacyRequestRepository;
    private final GolferAccountRepository golferAccountRepository;
    private final RoundRepository roundRepository;
    private final ScoreRepository scoreRepository;
    private final AuditService auditService;

    public PrivacyServiceImpl(
            PrivacyRequestRepository privacyRequestRepository,
            GolferAccountRepository golferAccountRepository,
            RoundRepository roundRepository,
            ScoreRepository scoreRepository,
            AuditService auditService) {
        this.privacyRequestRepository = privacyRequestRepository;
        this.golferAccountRepository = golferAccountRepository;
        this.roundRepository = roundRepository;
        this.scoreRepository = scoreRepository;
        this.auditService = auditService;
    }

    // ─── Create request ─────────────────────────────────────────────────────

    @Override
    @Transactional
    public PrivacyRequestResponse createRequest(Long requesterGolferAccountId, CreatePrivacyRequestRequest request) {
        log.debug("Creating privacy request for golferAccountId={}, requestType={}",
                requesterGolferAccountId, request.getRequestType());

        RequestType requestType;
        try {
            requestType = RequestType.valueOf(request.getRequestType().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new VspApiException(VspErrorCode.PRIVACY_006);
        }

        // Validate ROUND_DELETION: round must exist and belong to requester
        if (requestType == RequestType.ROUND_DELETION) {
            if (request.getTargetRoundId() == null) {
                throw new VspApiException(VspErrorCode.VALIDATION_001);
            }
            UUID roundId = request.getTargetRoundId();
            roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, requesterGolferAccountId)
                    .orElseThrow(() -> new VspApiException(VspErrorCode.PRIVACY_005));
        }

        // Validate ACCOUNT_DELETION: no active rounds allowed
        if (requestType == RequestType.ACCOUNT_DELETION) {
            long activeRounds = roundRepository.countByGolferAccountIdAndDeletedAtIsNull(requesterGolferAccountId);
            if (activeRounds > 0) {
                throw new VspApiException(VspErrorCode.PRIVACY_004);
            }
        }

        PrivacyRequest privacyRequest = new PrivacyRequest();
        privacyRequest.setRequesterGolferAccountId(requesterGolferAccountId);
        privacyRequest.setRequestType(requestType);
        privacyRequest.setStatus(Status.PENDING);
        privacyRequest.setRequestedAt(Instant.now());
        if (requestType == RequestType.ROUND_DELETION) {
            privacyRequest.setTargetRoundId(request.getTargetRoundId());
        }

        PrivacyRequest saved = privacyRequestRepository.save(privacyRequest);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.PRIVACY_REQUEST_SUBMITTED,
                "PrivacyRequest",
                String.valueOf(saved.getId()),
                null,
                serializeRequestToJson(saved),
                null
        );

        log.info(append("action", "PRIVACY_REQUEST_SUBMITTED"),
                "Privacy request created: golferAccountId={}, requestId={}, type={}",
                requesterGolferAccountId, saved.getId(), requestType);

        return PrivacyRequestResponse.fromEntity(saved);
    }

    // ─── Read requests ─────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<PrivacyRequestResponse> getMyRequests(Long requesterGolferAccountId) {
        log.debug("Getting privacy requests for golferAccountId={}", requesterGolferAccountId);
        return privacyRequestRepository.findByRequesterGolferAccountId(requesterGolferAccountId)
                .stream()
                .map(PrivacyRequestResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public PrivacyRequestResponse getRequestById(Long requesterGolferAccountId, Long requestId) {
        log.debug("Getting privacy request golferAccountId={}, requestId={}", requesterGolferAccountId, requestId);
        PrivacyRequest request = privacyRequestRepository
                .findByIdAndRequesterGolferAccountId(requestId, requesterGolferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.PRIVACY_001));
        return PrivacyRequestResponse.fromEntity(request);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PrivacyRequestResponse> getRequestsByStatus(Status status) {
        log.debug("Getting privacy requests by status={}", status);
        return privacyRequestRepository.findByStatus(status)
                .stream()
                .map(PrivacyRequestResponse::fromEntity)
                .collect(Collectors.toList());
    }

    // ─── Process request ───────────────────────────────────────────────────

    @Override
    @Transactional
    public PrivacyRequestResponse processRequest(Long adminId, Long requestId, ProcessPrivacyRequestRequest request) {
        log.debug("Processing privacy request: adminId={}, requestId={}, status={}",
                adminId, requestId, request.getStatus());

        PrivacyRequest privacyRequest = privacyRequestRepository.findById(requestId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.PRIVACY_001));

        if (privacyRequest.getStatus() == Status.COMPLETED || privacyRequest.getStatus() == Status.REJECTED) {
            throw new VspApiException(VspErrorCode.PRIVACY_002);
        }

        Status targetStatus;
        try {
            targetStatus = Status.valueOf(request.getStatus().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new VspApiException(VspErrorCode.PRIVACY_003);
        }

        // Only allow PROCESSING or REJECTED from PENDING; only allow COMPLETED from PROCESSING
        if (privacyRequest.getStatus() == Status.PENDING) {
            if (targetStatus != Status.PROCESSING && targetStatus != Status.REJECTED) {
                throw new VspApiException(VspErrorCode.PRIVACY_003);
            }
        } else if (privacyRequest.getStatus() == Status.PROCESSING) {
            if (targetStatus != Status.COMPLETED && targetStatus != Status.REJECTED) {
                throw new VspApiException(VspErrorCode.PRIVACY_003);
            }
        }

        String beforeJson = serializeRequestToJson(privacyRequest);

        privacyRequest.setStatus(targetStatus);
        privacyRequest.setProcessedBy(adminId);
        privacyRequest.setProcessedAt(Instant.now());

        if (targetStatus == Status.REJECTED) {
            privacyRequest.setRejectionReason(request.getRejectionReason());
        } else if (targetStatus == Status.COMPLETED) {
            // Execute the actual action
            executeAction(privacyRequest);
        }

        PrivacyRequest saved = privacyRequestRepository.save(privacyRequest);
        String afterJson = serializeRequestToJson(saved);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.PRIVACY_REQUEST_PROCESSED,
                "PrivacyRequest",
                String.valueOf(saved.getId()),
                beforeJson,
                afterJson,
                null
        );

        log.info(append("action", "PRIVACY_REQUEST_PROCESSED"),
                "Privacy request processed: adminId={}, requestId={}, status={}",
                adminId, saved.getId(), targetStatus);

        return PrivacyRequestResponse.fromEntity(saved);
    }

    // ─── Action execution ──────────────────────────────────────────────────

    private void executeAction(PrivacyRequest request) {
        if (request.getRequestType() == RequestType.DATA_EXPORT) {
            // Data export is generated on-demand via getDataExport()
            auditService.log(
                    vnpt.vsp.module.audit.AuditAction.ACCOUNT_DATA_EXPORTED,
                    "PrivacyRequest",
                    String.valueOf(request.getId()),
                    null,
                    null,
                    null
            );
        } else if (request.getRequestType() == RequestType.ACCOUNT_DELETION) {
            deleteAccount(request.getRequesterGolferAccountId());
        } else if (request.getRequestType() == RequestType.ROUND_DELETION) {
            if (request.getTargetRoundId() != null) {
                deleteRound(request.getRequesterGolferAccountId(), request.getTargetRoundId());
            }
        }
    }

    @Override
    @Transactional
    public void deleteAccount(Long golferAccountId) {
        log.debug("Anonymizing account golferAccountId={}", golferAccountId);

        GolferAccount account = golferAccountRepository.findById(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.AUTH_010));

        // Serialize PII before clearing
        String piiJson = serializePiiToJson(account);
        String encryptedPii = encrypt(piiJson);

        account.setDisplayName("Deleted User");
        account.setPhone(null);
        account.setEmail(null);
        account.setPasswordHash(null);
        account.setGoogleSubject(null);
        account.setAppleSubject(null);
        account.setAnonymizedAt(Instant.now());
        account.setAnonymizedData(encryptedPii);
        account.setStatus(GolferAccount.Status.DELETED);

        golferAccountRepository.save(account);

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.ACCOUNT_DELETED,
                "GolferAccount",
                String.valueOf(golferAccountId),
                "{\"id\":" + golferAccountId + "}",
                "{\"id\":" + golferAccountId + ",\"anonymized\":true}",
                null
        );

        log.info(append("action", "ACCOUNT_DELETED"),
                "Account anonymized: golferAccountId={}", golferAccountId);
    }

    @Override
    @Transactional
    public void deleteRound(Long golferAccountId, UUID roundId) {
        log.debug("Soft-deleting round golferAccountId={}, roundId={}", golferAccountId, roundId);

        Round round = roundRepository.findByIdAndGolferAccountIdAndDeletedAtIsNull(roundId, golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.PRIVACY_005));

        Instant now = Instant.now();

        // Soft-delete the round
        round.setDeletedAt(now);
        roundRepository.save(round);

        // Soft-delete associated scores
        List<Score> scores = scoreRepository.findByRoundIdAndDeletedAtIsNull(roundId);
        for (Score score : scores) {
            score.setDeletedAt(now);
            scoreRepository.save(score);
        }

        auditService.log(
                vnpt.vsp.module.audit.AuditAction.ROUND_DELETED,
                "Round",
                roundId.toString(),
                "{\"id\":\"" + roundId + "\",\"golferAccountId\":" + golferAccountId + "}",
                "{\"id\":\"" + roundId + "\",\"deletedAt\":\"" + now + "\"}",
                null
        );

        log.info(append("action", "ROUND_DELETED"),
                "Round soft-deleted: golferAccountId={}, roundId={}", golferAccountId, roundId);
    }

    // ─── Data export ───────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public String getDataExport(Long golferAccountId) {
        log.debug("Generating data export for golferAccountId={}", golferAccountId);

        GolferAccount account = golferAccountRepository.findById(golferAccountId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.AUTH_010));

        StringBuilder sb = new StringBuilder();
        sb.append("{\"golferAccountId\":").append(golferAccountId).append(",");
        sb.append("\"displayName\":\"").append(escapeJson(account.getDisplayName())).append("\",");
        sb.append("\"status\":\"").append(account.getStatus()).append("\",");
        sb.append("\"rounds\":[");

        List<Round> rounds = roundRepository.findActiveByGolferAccountId(golferAccountId);
        for (int i = 0; i < rounds.size(); i++) {
            Round round = rounds.get(i);
            if (i > 0) sb.append(",");
            sb.append("{\"id\":\"").append(round.getId()).append("\",");
            sb.append("\"status\":\"").append(round.getStatus()).append("\",");
            sb.append("\"startedAt\":\"").append(round.getStartedAt()).append("\"}");
        }

        sb.append("]}");
        return sb.toString();
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private String serializeRequestToJson(PrivacyRequest request) {
        return "{\"id\":" + request.getId() +
                ",\"requesterGolferAccountId\":" + request.getRequesterGolferAccountId() +
                ",\"requestType\":\"" + (request.getRequestType() != null ? request.getRequestType().name() : "") + "\"" +
                ",\"status\":\"" + (request.getStatus() != null ? request.getStatus().name() : "") + "\"" +
                ",\"targetRoundId\":" + request.getTargetRoundId() +
                "}";
    }

    private String serializePiiToJson(GolferAccount account) {
        return "{\"phone\":\"" + (account.getPhone() != null ? escapeJson(account.getPhone()) : "") + "\"," +
                "\"email\":\"" + (account.getEmail() != null ? escapeJson(account.getEmail()) : "") + "\"," +
                "\"displayName\":\"" + escapeJson(account.getDisplayName()) + "\"}";
    }

    private String encrypt(String data) {
        // Simple Base64 encoding for anonymization storage.
        // In production, use AES-256 encryption with a key from environment config.
        return Base64.getEncoder().encodeToString(data.getBytes(StandardCharsets.UTF_8));
    }

    private String escapeJson(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
