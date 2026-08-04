package vnpt.vsp.module.coursealert.entity;

/**
 * Enumerates delivery status for an alert.
 * Per Story 8.6 AC-3: delivery, expiry, acknowledgment tracking.
 */
public enum DeliveryStatus {
    PENDING,
    DELIVERED,
    FAILED,
    EXPIRED
}
