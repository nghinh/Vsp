package vnpt.vsp.module.tournament.dto;

import java.util.Map;

/**
 * Request DTO for updating a tournament policy.
 * Per tournament_policy.yaml TournamentPolicyUpdate contract.
 *
 * Only includes fields that the caller wants to change.
 * Null fields are ignored (no change).
 */
public class TournamentPolicyUpdateRequest {

    private String name;
    private Boolean windAdjustmentEnabled;
    private Boolean playsLikeEnabled;
    private Boolean elevationEnabled;
    private Boolean clubRecommendationEnabled;
    private Boolean contoursEnabled;
    private Boolean puttingHelpEnabled;
    private Boolean aiFeaturesEnabled;
    private String reason; // Optional reason for audit trail

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

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    /**
     * Returns only the non-null feature flag changes as a map.
     * Used for applying changes to the entity.
     */
    public Map<String, Boolean> getFeatureChanges() {
        java.util.Map<String, Boolean> changes = new java.util.HashMap<>();
        if (windAdjustmentEnabled != null) changes.put("windAdjustmentEnabled", windAdjustmentEnabled);
        if (playsLikeEnabled != null) changes.put("playsLikeEnabled", playsLikeEnabled);
        if (elevationEnabled != null) changes.put("elevationEnabled", elevationEnabled);
        if (clubRecommendationEnabled != null) changes.put("clubRecommendationEnabled", clubRecommendationEnabled);
        if (contoursEnabled != null) changes.put("contoursEnabled", contoursEnabled);
        if (puttingHelpEnabled != null) changes.put("puttingHelpEnabled", puttingHelpEnabled);
        if (aiFeaturesEnabled != null) changes.put("aiFeaturesEnabled", aiFeaturesEnabled);
        return changes;
    }
}
