package vnpt.vsp.module.operations.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

/**
 * Request DTO for creating a new green condition.
 * Per Story 8.5 AC-2: green speed (stimpmeter), firmness, moisture.
 * Per AC-3: effectiveFrom is required.
 */
public class GreenConditionCreateRequest {

    @NotNull(message = "stimpmeter is required")
    private BigDecimal stimpmeter; // Range 6-14 per validation

    private String firmness;  // SOFT, MEDIUM, FIRM, HARD
    private String moisture;  // DRY, NORMAL, WET, SATURATED

    @NotNull(message = "effectiveFrom is required")
    private java.time.Instant effectiveFrom;

    private java.time.Instant expiresAt;

    // Getters / Setters

    public BigDecimal getStimpmeter() {
        return stimpmeter;
    }

    public void setStimpmeter(BigDecimal stimpmeter) {
        this.stimpmeter = stimpmeter;
    }

    public String getFirmness() {
        return firmness;
    }

    public void setFirmness(String firmness) {
        this.firmness = firmness;
    }

    public String getMoisture() {
        return moisture;
    }

    public void setMoisture(String moisture) {
        this.moisture = moisture;
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
}
