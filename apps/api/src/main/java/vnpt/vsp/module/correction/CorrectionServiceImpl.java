package vnpt.vsp.module.correction;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.correction.dto.CorrectionDetailResponse;
import vnpt.vsp.module.correction.dto.CorrectionQueueRequest;
import vnpt.vsp.module.correction.dto.CorrectionQueueResponse;
import vnpt.vsp.module.correction.dto.CorrectionResolutionRequest;
import vnpt.vsp.module.correction.dto.CorrectionResolutionResponse;
import vnpt.vsp.module.correction.dto.CorrectionReviewRequest;
import vnpt.vsp.module.correction.entity.CorrectionReviewAction;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.entity.CorrectionStatus;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.course.entity.Course;
import vnpt.vsp.module.course.entity.Hole;
import vnpt.vsp.module.course.repository.CourseRepository;
import vnpt.vsp.module.course.repository.HoleRepository;
import vnpt.vsp.module.notification.NotificationService;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link CorrectionService}.
 * Per Story 9.2 AC-1 (queue filters), AC-2 (detail view), AC-3 (review actions).
 */
@Service
@CorrectionModule
public class CorrectionServiceImpl implements CorrectionService {

    private static final Logger log = LoggerFactory.getLogger(CorrectionServiceImpl.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final CourseCorrectionRepository correctionRepository;
    private final CourseRepository courseRepository;
    private final HoleRepository holeRepository;
    private final AuditService auditService;
    private final NotificationService notificationService;

    public CorrectionServiceImpl(
            CourseCorrectionRepository correctionRepository,
            CourseRepository courseRepository,
            HoleRepository holeRepository,
            AuditService auditService,
            NotificationService notificationService) {
        this.correctionRepository = correctionRepository;
        this.courseRepository = courseRepository;
        this.holeRepository = holeRepository;
        this.auditService = auditService;
        this.notificationService = notificationService;
    }

    // ─── queue ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public CorrectionQueueResponse getQueue(CorrectionQueueRequest request) {
        log.debug(append("action", "GET_QUEUE"), "Fetching correction queue: courseId={}, hole={}, type={}, status={}, page={}",
                request.getCourseId(), request.getHoleNumber(), request.getType(), request.getStatus(), request.getPage());

        // Fetch all matching corrections (service-level filtering for now)
        List<CourseCorrection> all = correctionRepository.findAll((root, query, cb) -> {
            List<jakarta.persistence.criteria.Predicate> predicates = new ArrayList<>();

            if (request.getCourseId() != null) {
                predicates.add(cb.equal(root.get("courseId"), request.getCourseId()));
            }
            if (request.getHoleNumber() != null) {
                predicates.add(cb.equal(root.get("holeId"), request.getHoleNumber().longValue()));
            }
            if (request.getType() != null) {
                predicates.add(cb.equal(root.get("correctionType"), request.getType()));
            }
            if (request.getStatus() != null) {
                predicates.add(cb.equal(root.get("status"), request.getStatus()));
            }
            if (request.getConfidenceMin() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("confidence"), request.getConfidenceMin()));
            }
            if (request.getConfidenceMax() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("confidence"), request.getConfidenceMax()));
            }
            if (request.getFromDate() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("submittedAt"), request.getFromDate()));
            }
            if (request.getToDate() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("submittedAt"), request.getToDate()));
            }

            query.orderBy(cb.desc(root.get("submittedAt")));
            return cb.and(predicates.toArray(new jakarta.persistence.criteria.Predicate[0]));
        });

        // Build course ID → name map for batch lookup
        Map<Long, String> courseNameMap = buildCourseNameMap(all);

        // Paginate
        int total = all.size();
        int pageSize = request.getPageSize() > 0 ? request.getPageSize() : 20;
        int start = request.getPage() * pageSize;
        int end = Math.min(start + pageSize, total);

        List<CorrectionQueueResponse.CorrectionSummary> summaries = start < total
                ? all.subList(start, end).stream()
                        .map(c -> CorrectionQueueResponse.CorrectionSummary.fromEntity(
                                c, courseNameMap.getOrDefault(c.getCourseId(), "Unknown")))
                        .collect(Collectors.toList())
                : List.of();

        return new CorrectionQueueResponse(summaries, total, request.getPage(), pageSize);
    }

    // ─── getDetail ─────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public CorrectionDetailResponse getDetail(Long correctionId) {
        log.debug(append("action", "GET_DETAIL"), "Fetching correction detail: id={}", correctionId);

        CourseCorrection correction = correctionRepository.findById(correctionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CORRECTION_001, "correction not found: " + correctionId));

        String courseName = courseRepository.findById(correction.getCourseId())
                .map(Course::getName)
                .orElse("Unknown");

        Integer holeNumber = null;
        if (correction.getHoleId() != null) {
            holeNumber = holeRepository.findById(correction.getHoleId())
                    .map(Hole::getHoleNumber)
                    .orElse(null);
        }

        return CorrectionDetailResponse.fromEntity(correction, courseName, holeNumber);
    }

    // ─── review ────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public CourseCorrection review(Long correctionId, CorrectionReviewRequest request, Long reviewedBy) {
        log.info(append("action", "CORRECTION_REVIEW"), "Reviewing correction: id={}, action={}, reviewedBy={}",
                correctionId, request.getAction(), reviewedBy);

        CourseCorrection correction = correctionRepository.findById(correctionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.CORRECTION_001, "correction not found: " + correctionId));

        // Validate status transitions
        validateStatusTransition(correction, request);

        // Apply the review action
        switch (request.getAction()) {
            case APPROVE -> {
                correction.approve(request.getReason(), reviewedBy, request.getNote());
                auditCorrection(correction, AuditAction.CORRECTION_APPROVE, reviewedBy);
            }
            case REJECT -> {
                if (request.getReason() == null || request.getReason().isBlank()) {
                    throw VspApiException.forField(VspErrorCode.VALIDATION_001, "reason",
                            Map.of("reason", "Reason is required for REJECT action"));
                }
                correction.reject(request.getReason(), reviewedBy, request.getNote());
                auditCorrection(correction, AuditAction.CORRECTION_REJECT, reviewedBy);
            }
            case REQUEST_INFO -> {
                if (request.getReason() == null || request.getReason().isBlank()) {
                    throw VspApiException.forField(VspErrorCode.VALIDATION_001, "reason",
                            Map.of("reason", "Message is required for REQUEST_INFO action"));
                }
                correction.requestInfo(request.getReason(), reviewedBy, request.getNote());
                auditCorrection(correction, AuditAction.CORRECTION_INFO_REQUESTED, reviewedBy);
            }
            case CONVERT_TO_DRAFT -> {
                correction.convertToDraft(request.getReason(), reviewedBy, request.getNote());
                auditCorrection(correction, AuditAction.CORRECTION_CONVERTED_TO_DRAFT, reviewedBy);
            }
            default -> throw new IllegalArgumentException("Unknown review action: " + request.getAction());
        }

        return correctionRepository.save(correction);
    }

    // ─── resolveCorrection (Story 9.3 Wave 2) ─────────────────────────────────

    @Override
    @Transactional
    public CorrectionResolutionResponse resolveCorrection(
            Long correctionId,
            CorrectionResolutionRequest request,
            Long reviewedBy) {
        log.info(append("action", "CORRECTION_RESOLVE"),
                "Resolving correction: id={}, decision={}, produceDraftChange={}, reviewedBy={}",
                correctionId, request.decision(), request.produceDraftChange(), reviewedBy);

        // 1. Validate correction exists
        CourseCorrection correction = correctionRepository.findById(correctionId)
                .orElseThrow(() -> new VspApiException(
                        VspErrorCode.CORRECTION_001,
                        "Correction not found: " + correctionId));

        // 2. Validate status allows resolution (non-terminal)
        CorrectionStatus currentStatus = correction.getStatus();
        if (currentStatus == CorrectionStatus.APPROVED ||
            currentStatus == CorrectionStatus.REJECTED ||
            currentStatus == CorrectionStatus.INFO_REQUESTED ||
            currentStatus == CorrectionStatus.CONVERTED_TO_DRAFT) {
            throw new VspApiException(
                    VspErrorCode.CORRECTION_002,
                    "Correction has already been reviewed");
        }

        // 3. Apply resolution via entity method
        CourseCorrection.Decision entityDecision =
                request.decision() == CorrectionResolutionRequest.Decision.APPROVE
                        ? CourseCorrection.Decision.APPROVE
                        : CourseCorrection.Decision.REJECT;
        correction.resolve(entityDecision, reviewedBy, request.reason());
        correctionRepository.save(correction);

        // 4. Audit entry — CORRECTION_RESOLVED (async, auditId not available synchronously)
        auditCorrectionResolved(correction, reviewedBy, request.reason());

        // 5. Dispatch non-fatal notification to reporter
        Instant notifiedAt = _notifyReporter(correction, request.decision().name());

        // 6. Build response
        return new CorrectionResolutionResponse(
                correction.getId(),
                correction.getStatus().name(),
                correction.getResultingVersionId(),
                null, // auditId — AuditService is async, ID not available synchronously
                notifiedAt);
    }

    private void auditCorrectionResolved(CourseCorrection correction, Long reviewedBy, String reason) {
        try {
            String beforeJson = MAPPER.writeValueAsString(Map.of(
                    "id", correction.getId(),
                    "courseId", correction.getCourseId(),
                    "status", correction.getStatus().name()));
            String afterJson = MAPPER.writeValueAsString(Map.of(
                    "id", correction.getId(),
                    "courseId", correction.getCourseId(),
                    "status", correction.getStatus().name(),
                    "resolution", correction.getResolution() != null ? correction.getResolution() : "",
                    "reviewNote", correction.getReviewNote() != null ? correction.getReviewNote() : ""));
            String metadata = MAPPER.writeValueAsString(Map.of(
                    "reviewedBy", reviewedBy,
                    "reason", reason != null ? reason : "",
                    "produceDraftChange", "N/A at resolve time"));
            auditService.log(
                    AuditAction.CORRECTION_RESOLVED,
                    "Correction",
                    String.valueOf(correction.getId()),
                    beforeJson,
                    afterJson,
                    metadata);
        } catch (Exception e) {
            log.warn("Failed to serialize correction for audit", e);
        }
    }

    private Instant _notifyReporter(CourseCorrection correction, String decision) {
        try {
            Map<String, Object> payload = Map.of(
                    "alertId", "correction-resolved-" + correction.getId(),
                    "alertType", "CORRECTION_RESOLVED",
                    "title", "Your correction has been " + decision,
                    "body", correction.getResolution() != null
                            ? correction.getResolution()
                            : "Your correction has been reviewed.",
                    "targetType", "CORRECTION",
                    "targetId", correction.getId(),
                    "priority", "NORMAL");
            notificationService.sendPushNotification(payload);
            return Instant.now();
        } catch (Exception e) {
            log.warn("Failed to dispatch reporter notification for correction {}: {}",
                    correction.getId(), e.getMessage());
            return null;
        }
    }

    // ─── Validation helpers ─────────────────────────────────────────────────────

    private void validateStatusTransition(CourseCorrection correction, CorrectionReviewRequest request) {
        CorrectionStatus current = correction.getStatus();

        // APPROVE/REJECT/REQUEST_INFO/CONVERT_TO_DRAFT require IN_REVIEW
        if (current == CorrectionStatus.PENDING) {
            throw new VspApiException(VspErrorCode.CORRECTION_004,
                    "Correction must be moved to IN_REVIEW before applying a terminal action");
        }

        if (current == CorrectionStatus.APPROVED ||
            current == CorrectionStatus.REJECTED ||
            current == CorrectionStatus.INFO_REQUESTED ||
            current == CorrectionStatus.CONVERTED_TO_DRAFT) {
            throw new VspApiException(VspErrorCode.CORRECTION_002,
                    "Correction has already been reviewed");
        }

        // REQUEST_INFO requires reason
        if (request.getAction() == CorrectionReviewAction.REQUEST_INFO &&
            (request.getReason() == null || request.getReason().isBlank())) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "reason",
                    Map.of("reason", "Message is required for REQUEST_INFO action"));
        }

        // REJECT requires reason
        if (request.getAction() == CorrectionReviewAction.REJECT &&
            (request.getReason() == null || request.getReason().isBlank())) {
            throw VspApiException.forField(VspErrorCode.VALIDATION_001, "reason",
                    Map.of("reason", "Reason is required for REJECT action"));
        }
    }

    // ─── Audit helper ──────────────────────────────────────────────────────────

    private void auditCorrection(CourseCorrection correction, AuditAction action, Long reviewedBy) {
        try {
            String beforeJson = MAPPER.writeValueAsString(Map.of(
                    "id", correction.getId(),
                    "courseId", correction.getCourseId(),
                    "status", correction.getStatus().name()
            ));
            String afterJson = MAPPER.writeValueAsString(Map.of(
                    "id", correction.getId(),
                    "courseId", correction.getCourseId(),
                    "status", correction.getStatus().name(),
                    "resolution", correction.getResolution() != null ? correction.getResolution() : "",
                    "reviewNote", correction.getReviewNote() != null ? correction.getReviewNote() : ""
            ));
            String metadata = MAPPER.writeValueAsString(Map.of(
                    "reviewedBy", reviewedBy,
                    "action", action.name()
            ));
            auditService.log(action, "Correction", String.valueOf(correction.getId()),
                    beforeJson, afterJson, metadata);
        } catch (Exception e) {
            log.warn("Failed to serialize correction for audit", e);
        }
    }

    // ─── Course name map helper ─────────────────────────────────────────────────

    private Map<Long, String> buildCourseNameMap(List<CourseCorrection> corrections) {
        if (corrections.isEmpty()) {
            return Map.of();
        }
        List<Long> courseIds = corrections.stream()
                .map(CourseCorrection::getCourseId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());

        return courseRepository.findAllById(courseIds).stream()
                .collect(Collectors.toMap(Course::getId, Course::getName));
    }
}
