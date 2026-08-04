package vnpt.vsp.module.operations.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

/**
 * Request DTO for creating a new pin position.
 * Per Story 8.5 AC-1: place/schedule pins with effective + expiration times.
 * Per AC-3: effectiveFrom and expiresAt are required.
 */
public class PinPositionCreateRequest {

    @NotNull(message = "position is required")
    private String position; // WKT POINT string (SRID 4326)

    private String pinPositionType; // CURRENT, TOURNAMENT, PRACTICE

    @NotNull(message = "effectiveFrom is required")
    private java.time.Instant effectiveFrom;

    @NotNull(message = "expiresAt is required for pins (per AC-3)")
    private java.time.Instant expiresAt;

    private BigDecimal confidence; // 0.0-1.0

    // Getters / Setters

    public String getPosition() {
        return position;
    }

    public void setPosition(String position) {
        this.position = position;
    }

    public String getPinPositionType() {
        return pinPositionType;
    }

    public void setPinPositionType(String pinPositionType) {
        this.pinPositionType = pinPositionType;
    }

    public java.time.Instant getEffectiveFrom() {
        return effectiveFrom;
    }

    public void setEffectiveFrom(java.time.Instant effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public java.time.Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(java.time.Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public BigDecimal getConfidence() {
        return confidence;
    }

    public void setConfidence(BigDecimal confidence) {
        this.confidence = confidence;
    }
}
