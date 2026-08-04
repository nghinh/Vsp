package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.TournamentPolicy;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for tournament policy.
 * Per tournament_policy.yaml TournamentPolicy contract.
 */
public class TournamentPolicyResponse {

    private UUID id;
    private String name;
    private boolean windAdjustmentEnabled;
    private boolean playsLikeEnabled;
    private boolean elevationEnabled;
    private boolean clubRecommendationEnabled;
    private boolean contoursEnabled;
    private boolean puttingHelpEnabled;
    private boolean aiFeaturesEnabled;
    private boolean isLocked;
    private Instant createdAt;
    private Long createdBy;
    private int version;

    // ─── From entity ─────────────────────────────────────────────────────────

    public static TournamentPolicyResponse fromEntity(TournamentPolicy entity) {
        TournamentPolicyResponse response = new TournamentPolicyResponse();
        response.setId(entity.getId());
        response.setName(entity.getName());
        response.setWindAdjustmentEnabled(entity.isWindAdjustment());
        response.setPlaysLikeEnabled(entity.isPlaysLike());
        response.setElevationEnabled(entity.isElevation());
        response.setClubRecommendationEnabled(entity.isClubRecommendation());
        response.setContoursEnabled(entity.isContours());
        response.setPuttingHelpEnabled(entity.isPuttingHelp());
        response.setAiFeaturesEnabled(entity.isAiFeatures());
        response.setLocked(entity.isLocked());
        response.setCreatedAt(entity.getCreatedAt());
        response.setCreatedBy(entity.getCreatedBy());
        response.setVersion(entity.getVersion());
        return response;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public boolean isWindAdjustmentEnabled() { return windAdjustmentEnabled; }
    public void setWindAdjustmentEnabled(boolean windAdjustmentEnabled) { this.windAdjustmentEnabled = windAdjustmentEnabled; }

    public boolean isPlaysLikeEnabled() { return playsLikeEnabled; }
    public void setPlaysLikeEnabled(boolean playsLikeEnabled) { this.playsLikeEnabled = playsLikeEnabled; }

    public boolean isElevationEnabled() { return elevationEnabled; }
    public void setElevationEnabled(boolean elevationEnabled) { this.elevationEnabled = elevationEnabled; }

    public boolean isClubRecommendationEnabled() { return clubRecommendationEnabled; }
    public void setClubRecommendationEnabled(boolean clubRecommendationEnabled) { this.clubRecommendationEnabled = clubRecommendationEnabled; }

    public boolean isContoursEnabled() { return contoursEnabled; }
    public void setContoursEnabled(boolean contoursEnabled) { this.contoursEnabled = contoursEnabled; }

    public boolean isPuttingHelpEnabled() { return puttingHelpEnabled; }
    public void setPuttingHelpEnabled(boolean puttingHelpEnabled) { this.puttingHelpEnabled = puttingHelpEnabled; }

    public boolean isAiFeaturesEnabled() { return aiFeaturesEnabled; }
    public void setAiFeaturesEnabled(boolean aiFeaturesEnabled) { this.aiFeaturesEnabled = aiFeaturesEnabled; }

    public boolean isLocked() { return isLocked; }
    public void setLocked(boolean locked) { isLocked = locked; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }

    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }
}
