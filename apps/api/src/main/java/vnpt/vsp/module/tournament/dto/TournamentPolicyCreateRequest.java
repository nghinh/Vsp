package vnpt.vsp.module.tournament.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request DTO for creating a new tournament policy.
 * Per tournament_policy.yaml TournamentPolicyCreate contract.
 */
public class TournamentPolicyCreateRequest {

    @NotBlank(message = "name is required")
    private String name;

    private Boolean windAdjustmentEnabled = true;
    private Boolean playsLikeEnabled = true;
    private Boolean elevationEnabled = true;
    private Boolean clubRecommendationEnabled = true;
    private Boolean contoursEnabled = true;
    private Boolean puttingHelpEnabled = true;
    private Boolean aiFeaturesEnabled = true;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Boolean getWindAdjustmentEnabled() { return windAdjustmentEnabled; }
    public void setWindAdjustmentEnabled(Boolean windAdjustmentEnabled) { this.windAdjustmentEnabled = windAdjustmentEnabled; }

    public Boolean getPlaysLikeEnabled() { return playsLikeEnabled; }
    public void setPlaysLikeEnabled(Boolean playsLikeEnabled) { this.playsLikeEnabled = playsLikeEnabled; }

    public Boolean getElevationEnabled() { return elevationEnabled; }
    public void setElevationEnabled(Boolean elevationEnabled) { this.elevationEnabled = elevationEnabled; }

    public Boolean getClubRecommendationEnabled() { return clubRecommendationEnabled; }
    public void setClubRecommendationEnabled(Boolean clubRecommendationEnabled) { this.clubRecommendationEnabled = clubRecommendationEnabled; }

    public Boolean getContoursEnabled() { return contoursEnabled; }
    public void setContoursEnabled(Boolean contoursEnabled) { this.contoursEnabled = contoursEnabled; }

    public Boolean getPuttingHelpEnabled() { return puttingHelpEnabled; }
    public void setPuttingHelpEnabled(Boolean puttingHelpEnabled) { this.puttingHelpEnabled = puttingHelpEnabled; }

    public Boolean getAiFeaturesEnabled() { return aiFeaturesEnabled; }
    public void setAiFeaturesEnabled(Boolean aiFeaturesEnabled) { this.aiFeaturesEnabled = aiFeaturesEnabled; }
}
