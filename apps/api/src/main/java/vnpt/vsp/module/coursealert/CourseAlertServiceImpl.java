package vnpt.vsp.module.coursealert;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.coursealert.dto.CourseAlertCreateRequest;
import vnpt.vsp.module.coursealert.dto.CourseAlertResponse;
import vnpt.vsp.module.coursealert.dto.CourseAlertUpdateRequest;
import vnpt.vsp.module.coursealert.entity.*;
import vnpt.vsp.module.coursealert.repository.CourseAlertRepository;
import vnpt.vsp.module.notification.NotificationService;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link CourseAlertService}.
 * Per Story 8.6 AC-1: targeting validation and filtering.
 * Per Story 8.6 AC-2: alertType drives visual distinction.
 * Per Story 8.6 AC-3: delivery tracking, acknowledgment, audit.
 */
@Service
@CourseAlertModule
public class CourseAlertServiceImpl implements CourseAlertService {

    private static final Logger log = LoggerFactory.getLogger(CourseAlertServiceImpl.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final CourseAlertRepository alertRepository;
    private final NotificationService notificationService;
    private final AuditService auditService;

    public CourseAlertServiceImpl(
            CourseAlertRepository alertRepository,
            NotificationService notificationService,
            AuditService auditService) {
        this.alertRepository = alertRepository;
        this.notificationService = notificationService;
        this.auditService = auditService;
    }

    @Override
    @Transactional
    public CourseAlert sendAlert(CourseAlertCreateRequest request, String createdBy) {
        log.debug(append("action", "SEND_ALERT"), "Sending alert: title={}, alertType={}, createdBy={}",
                request.getTitle(), request.getAlertType(), createdBy);

        // AC-1: Validate at least one targeting field is set
        if (!request.hasTargeting()) {
            throw new VspApiException(VspErrorCode.VALIDATION_001, "target",
                    java.util.Map.of("reason", "At least one targeting field (facilityId, courseId, holeId, flightId, or groupId) is required"));
        }

        CourseAlert alert = new CourseAlert();
        alert.setFacilityId(request.getFacilityId());
        alert.setCourseId(request.getCourseId());
        alert.setHoleId(request.getHoleId());
        alert.setFlightId(request.getFlightId());
        alert.setGroupId(request.getGroupId());
        alert.setAlertType(request.getAlertType());
        alert.setTitle(request.getTitle());
        alert.setBody(request.getBody());
        alert.setPriority(parsePriority(request.getPriority()));
        alert.setEffectiveAt(request.getEffectiveAt() != null ? request.getEffectiveAt() : OffsetDateTime.now());
        alert.setExpiresAt(request.getExpiresAt());
        alert.setDeliveryStatus(DeliveryStatus.PENDING);
        alert.setAcknowledgmentRequired(request.getAcknowledgmentRequired() != null ? request.getAcknowledgmentRequired() : false);
        alert.setCreatedBy(createdBy);
        alert.setPublishedVersion(1);

        CourseAlert saved = alertRepository.save(alert);

        // Dispatch to NotificationService for push delivery (stub if not implemented)
        dispatchToPush(saved);

        // Audit log
        auditService.log(AuditAction.ALERT_SEND, "CourseAlert", String.valueOf(saved.getId()),
                null, serializeToJson(saved),
                buildMetadataJson(createdBy, "alert sent"));

        log.info(append("action", "ALERT_SENT"), "Alert sent: id={}, alertType={}, createdBy={}",
                saved.getId(), saved.getAlertType(), createdBy);

        return saved;
    }

    @Override
    @Transactional(readOnly = true)
    public CourseAlert getAlert(Long alertId) {
        return alertRepository.findById(alertId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ALERT_001));
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseAlert> listAlerts(AlertType alertType, AlertTargetType targetType, UUID targetId,
                                         DeliveryStatus deliveryStatus, OffsetDateTime from, OffsetDateTime to) {
        // For simplicity, use findAll and filter in-memory.
        // A more optimized implementation would add repository query methods.
        List<CourseAlert> all = alertRepository.findAll();

        return all.stream()
                .filter(a -> alertType == null || a.getAlertType() == alertType)
                .filter(a -> targetType == null || matchesTarget(a, targetType, targetId))
                .filter(a -> deliveryStatus == null || a.getDeliveryStatus() == deliveryStatus)
                .filter(a -> from == null || (a.getEffectiveAt() != null && !a.getEffectiveAt().isBefore(from)))
                .filter(a -> to == null || (a.getEffectiveAt() != null && !a.getEffectiveAt().isAfter(to)))
                .sorted((a, b) -> {
                    // Order by effectiveAt desc, then priority desc
                    int cmp = b.getEffectiveAt().compareTo(a.getEffectiveAt());
                    if (cmp != 0) return cmp;
                    return Integer.compare(
                            b.getPriority() != null ? b.getPriority() : 0,
                            a.getPriority() != null ? a.getPriority() : 0
                    );
                })
                .toList();
    }

    @Override
    @Transactional
    public CourseAlert updateAlert(Long alertId, CourseAlertUpdateRequest request) {
        CourseAlert existing = alertRepository.findById(alertId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ALERT_001));

        // AC-3: Updates only allowed before effectiveAt
        if (existing.getEffectiveAt() != null && !existing.getEffectiveAt().isAfter(OffsetDateTime.now())) {
            throw new VspApiException(VspErrorCode.ALERT_002);
        }

        String beforeJson = serializeToJson(existing);

        if (request.getTitle() != null) {
            existing.setTitle(request.getTitle());
        }
        if (request.getBody() != null) {
            existing.setBody(request.getBody());
        }
        if (request.getPriority() != null) {
            existing.setPriority(parsePriority(request.getPriority()));
        }
        if (request.getEffectiveAt() != null) {
            existing.setEffectiveAt(request.getEffectiveAt());
        }
        if (request.getExpiresAt() != null) {
            existing.setExpiresAt(request.getExpiresAt());
        }

        // Increment version for optimistic concurrency
        existing.setVersion(existing.getVersion() + 1);

        CourseAlert saved = alertRepository.save(existing);

        // Audit log
        auditService.log(AuditAction.ALERT_UPDATE, "CourseAlert", String.valueOf(saved.getId()),
                beforeJson, serializeToJson(saved),
                buildMetadataJson(null, "alert updated"));

        log.info(append("action", "ALERT_UPDATED"), "Alert updated: id={}", saved.getId());

        return saved;
    }

    @Override
    @Transactional
    public void cancelAlert(Long alertId, String cancelledBy) {
        CourseAlert existing = alertRepository.findById(alertId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ALERT_001));

        String beforeJson = serializeToJson(existing);

        // Set expiresAt to now to cancel
        existing.setExpiresAt(OffsetDateTime.now());
        existing.setDeliveryStatus(DeliveryStatus.EXPIRED);
        existing.setVersion(existing.getVersion() + 1);

        alertRepository.save(existing);

        // Audit log
        auditService.log(AuditAction.ALERT_CANCEL, "CourseAlert", String.valueOf(existing.getId()),
                beforeJson, serializeToJson(existing),
                buildMetadataJson(cancelledBy, "alert cancelled"));

        log.info(append("action", "ALERT_CANCELLED"), "Alert cancelled: id={}, cancelledBy={}", alertId, cancelledBy);
    }

    @Override
    @Transactional
    public void acknowledgeAlert(Long alertId, String acknowledgedBy) {
        CourseAlert existing = alertRepository.findById(alertId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.ALERT_001));

        if (!Boolean.TRUE.equals(existing.getAcknowledgmentRequired())) {
            throw new VspApiException(VspErrorCode.ALERT_003);
        }

        if (existing.getAcknowledgedAt() != null) {
            // Already acknowledged — idempotent
            return;
        }

        String beforeJson = serializeToJson(existing);

        existing.setAcknowledgedAt(Instant.now());
        existing.setAcknowledgedBy(acknowledgedBy);
        existing.setVersion(existing.getVersion() + 1);

        alertRepository.save(existing);

        // Audit log
        auditService.log(AuditAction.ALERT_ACK, "CourseAlert", String.valueOf(existing.getId()),
                beforeJson, serializeToJson(existing),
                buildMetadataJson(acknowledgedBy, "alert acknowledged"));

        log.info(append("action", "ALERT_ACKNOWLEDGED"), "Alert acknowledged: id={}, acknowledgedBy={}", alertId, acknowledgedBy);
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseAlert> getActiveAlertsForTarget(AlertTargetType targetType, UUID targetId) {
        OffsetDateTime now = OffsetDateTime.now();

        return switch (targetType) {
            case FACILITY -> alertRepository.findActiveAlerts(now).stream()
                    .filter(a -> targetId.equals(a.getFacilityId()))
                    .toList();
            case COURSE -> alertRepository.findActiveAlertsByCourseId(targetId, now);
            case HOLE -> alertRepository.findActiveAlertsByHoleId(targetId, now);
            case FLIGHT, GROUP -> alertRepository.findActiveAlerts(now).stream()
                    .filter(a -> targetType == AlertTargetType.FLIGHT
                            ? targetId.equals(a.getFlightId())
                            : targetId.equals(a.getGroupId()))
                    .toList();
        };
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private boolean matchesTarget(CourseAlert alert, AlertTargetType targetType, UUID targetId) {
        if (targetId == null) return true;
        return switch (targetType) {
            case FACILITY -> targetId.equals(alert.getFacilityId());
            case COURSE -> targetId.equals(alert.getCourseId());
            case HOLE -> targetId.equals(alert.getHoleId());
            case FLIGHT -> targetId.equals(alert.getFlightId());
            case GROUP -> targetId.equals(alert.getGroupId());
        };
    }

    private int parsePriority(String priority) {
        if (priority == null) return 0;
        return switch (priority.toUpperCase()) {
            case "LOW" -> -1;
            case "NORMAL" -> 0;
            case "HIGH" -> 1;
            case "CRITICAL" -> 2;
            default -> 0;
        };
    }

    private void dispatchToPush(CourseAlert alert) {
        // Stub: actual push dispatch to FCM/APNs is deferred to later epic.
        // The NotificationService will handle the push dispatch.
        log.debug(append("action", "DISPATCH_TO_PUSH"), "Dispatching alert to push service: id={}", alert.getId());
        // notificationService.sendPushNotification(...) would be called here
    }

    private String serializeToJson(CourseAlert alert) {
        try {
            return MAPPER.writeValueAsString(CourseAlertResponse.fromEntity(alert));
        } catch (Exception e) {
            log.warn("Failed to serialize alert to JSON: id={}", alert.getId(), e);
            return "{}";
        }
    }

    private String buildMetadataJson(String actor, String action) {
        try {
            return MAPPER.writeValueAsString(java.util.Map.of(
                    "actor", actor != null ? actor : "SYSTEM",
                    "action", action
            ));
        } catch (Exception e) {
            return "{}";
        }
    }
}
