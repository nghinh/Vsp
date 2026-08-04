package vnpt.vsp.module.bag.dto;

import jakarta.validation.constraints.*;

/**
 * Request DTO for creating a new club.
 * Per Story 2.4 AC-1: all club fields supported.
 * Per PRD Phase 2: dispersion stored but not used in MVP recommendations.
 */
public class CreateClubRequest {

    @NotBlank(message = "Club type is required")
    @Pattern(regexp = "DRIVER|WOOD|HYBRID|IRON|WEDGE|PUTTER", message = "Invalid club type")
    private String clubType;

    @DecimalMin(value = "0.0", message = "Loft must be at least 0 degrees")
    @DecimalMax(value = "90.0", message = "Loft must be at most 90 degrees")
    private Double loft;

    @Positive(message = "Carry distance must be positive")
    private Double carryDistance;

    @Positive(message = "Total distance must be positive")
    private Double totalDistance;

    @DecimalMin(value = "0.0", message = "Dispersion must be at least 0 degrees")
    private Double dispersion;

    @Size(max = 100, message = "Shaft must be at most 100 characters")
    private String shaft;

    private String useDate; // ISO date string e.g. "2026-01-15"

    public CreateClubRequest() {}

    public String getClubType() {
        return clubType;
    }

    public void setClubType(String clubType) {
        this.clubType = clubType;
    }

    public Double getLoft() {
        return loft;
    }

    public void setLoft(Double loft) {
        this.loft = loft;
    }

    public Double getCarryDistance() {
        return carryDistance;
    }

    public void setCarryDistance(Double carryDistance) {
        this.carryDistance = carryDistance;
    }

    public Double getTotalDistance() {
        return totalDistance;
    }

    public void setTotalDistance(Double totalDistance) {
        this.totalDistance = totalDistance;
    }

    public Double getDispersion() {
        return dispersion;
    }

    public void setDispersion(Double dispersion) {
        this.dispersion = dispersion;
    }

    public String getShaft() {
        return shaft;
    }

    public void setShaft(String shaft) {
        this.shaft = shaft;
    }

    public String getUseDate() {
        return useDate;
    }

    public void setUseDate(String useDate) {
        this.useDate = useDate;
    }
}
