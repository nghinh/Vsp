package vnpt.vsp.module.notification;

import java.util.Map;

/**
 * Notification module public service interface.
 * Exposes async notification dispatch operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 *
 * <p>Push dispatch (FCM/APNs) is deferred — this interface defines the contract.
 * Actual mobile push integration will be implemented in a later epic.
 */
public interface NotificationService {

    /**
     * Send a push notification to mobile clients.
     * Contract only — actual FCM/APNs integration deferred to later epic.
     *
     * @param pushPayload the push notification payload (alertId, alertType, title, body,
     *                    targetType, targetId, priority, effectiveAt, expiresAt, acknowledgmentRequired)
     * @return delivery token or correlation ID (future use — currently returns null for stub)
     */
    default String sendPushNotification(Map<String, Object> pushPayload) {
        // Stub: actual push dispatch (FCM/APNs) is deferred.
        // Implementors should override and log.debug the payload.
        return null;
    }
}
