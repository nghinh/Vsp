package vnpt.vsp.module.operations.dto;

import java.time.Instant;

/**
 * Request DTO for updating an existing pin position.
 * Per Story 8.5 AC-1: update pin position with temporal scheduling.
 */
public class PinPositionUpdateRequest {

    private String position; // WKT POINT string (SRID 4326)
    private Instant effectiveFrom;
    private Instant expiresAt;

    // Getters / Setters

    public String getPosition() {
        return position;
    }

    public void setPosition(String position) {
        this.position = position;
    }

    public Instant getEffectiveFrom() {
        return effectiveFrom;
    }

    public void setEffectiveFrom(Instant effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }
}
