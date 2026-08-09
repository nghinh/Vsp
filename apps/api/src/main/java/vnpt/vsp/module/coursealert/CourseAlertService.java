package vnpt.vsp.module.coursealert;

import vnpt.vsp.module.coursealert.dto.CourseAlertCreateRequest;
import vnpt.vsp.module.coursealert.dto.CourseAlertUpdateRequest;
import vnpt.vsp.module.coursealert.entity.AlertTargetType;
import vnpt.vsp.module.coursealert.entity.AlertType;
import vnpt.vsp.module.coursealert.entity.CourseAlert;
import vnpt.vsp.module.coursealert.entity.DeliveryStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Course alert module public service interface.
 * Exposes alert CRUD, send, acknowledge, and audit operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 * Per Story 8.6: AC-1 targeting, AC-2 visual distinction, AC-3 delivery/expiry/acknowledge/audit.
 */
public interface CourseAlertService {

    /**
     * Create and send a new course alert.
     * Validates at least one targeting field is set, sets effectiveAt (default: now),
     * and dispatches to NotificationService for push delivery.
     *
     * @param request the alert create request
     * @param createdBy account ID of the operator creating the alert
     * @return the saved alert with deliveryStatus=PENDING
     */
    CourseAlert sendAlert(CourseAlertCreateRequest request, String createdBy);

    /**
     * Get an alert by ID.
     *
     * @param alertId the alert ID
     * @return the alert
     */
    CourseAlert getAlert(Long alertId);

    /**
     * List alerts with optional filtering.
     * Per Story 8.6 AC-1: targeting filter via targetType + targetId.
     *
     * @param alertType filter by alert type (optional)
     * @param targetType filter by target scope (optional)
     * @param targetId filter by target ID (optional). A string, because the
     *                 scopes do not share a key space: facility, course and
     *                 hole are BIGSERIAL ids, flight and group are UUIDs.
     *                 It is parsed against whichever the scope uses.
     * @param deliveryStatus filter by delivery status (optional)
     * @param from filter effectiveAt >= from (optional)
     * @param to filter effectiveAt <= to (optional)
     * @return list of matching alerts ordered by effectiveAt desc
     */
    List<CourseAlert> listAlerts(AlertType alertType, AlertTargetType targetType, String targetId,
                                  DeliveryStatus deliveryStatus, OffsetDateTime from, OffsetDateTime to);

    /**
     * Update an alert before its effectiveAt.
     * Per Story 8.6 AC-3: updates only allowed before effective — audit tracked via version.
     *
     * @param alertId the alert ID
     * @param request the update request
     * @return the updated alert
     */
    CourseAlert updateAlert(Long alertId, CourseAlertUpdateRequest request);

    /**
     * Cancel an alert — marks it as expired immediately.
     * Per Story 8.6 AC-3: cancellation audit.
     *
     * @param alertId the alert ID
     * @param cancelledBy account ID of the operator cancelling
     */
    void cancelAlert(Long alertId, String cancelledBy);

    /**
     * Acknowledge an alert on behalf of a golfer.
     * Per Story 8.6 AC-3: acknowledgment tracking.
     *
     * @param alertId the alert ID
     * @param acknowledgedBy golfer account ID
     */
    void acknowledgeAlert(Long alertId, String acknowledgedBy);

    /**
     * Get active alerts for a specific target scope.
     * Active = effectiveAt <= now AND (expiresAt IS NULL OR expiresAt > now) AND deliveryStatus != EXPIRED.
     *
     * @param targetType the target scope
     * @param targetId the target ID, as a string — see listAlerts
     * @return list of active alerts for this target
     */
    List<CourseAlert> getActiveAlertsForTarget(AlertTargetType targetType, String targetId);
}
