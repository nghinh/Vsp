package vnpt.vsp.module.operations.dto;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Request DTO for updating an existing green condition.
 * Per Story 8.5 AC-2: update green speed, firmness, moisture.
 */
public class GreenConditionUpdateRequest {

    private BigDecimal stimpmeter; // Range 6-14 per validation
    private String firmness;  // SOFT, MEDIUM, FIRM, HARD
    private String moisture;  // DRY, NORMAL, WET, SATURATED
    private Instant effectiveFrom;
    private Instant expiresAt;

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
