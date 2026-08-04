package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * TournamentPolicy entity — feature restriction policy for tournament rounds.
 *
 * Per PRD §8.12: "Tournament Mode may lock after round start."
 * Per Architecture §14 QG-8: "Basic Tournament Mode restrictions are
 * represented in config and UI."
 *
 * A null policy means no restrictions (casual/practice modes).
 * A non-null policy activates feature gates on the mobile app.
 */
@Entity
@Table(name = "tournament_policies")
public class TournamentPolicy {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "wind_adjustment", nullable = false)
    private boolean windAdjustment = true;

    @Column(name = "plays_like", nullable = false)
    private boolean playsLike = true;

    @Column(name = "elevation", nullable = false)
    private boolean elevation = true;

    @Column(name = "club_recommendation", nullable = false)
    private boolean clubRecommendation = true;

    @Column(name = "contours", nullable = false)
    private boolean contours = true;

    @Column(name = "putting_help", nullable = false)
    private boolean puttingHelp = true;

    @Column(name = "ai_features", nullable = false)
    private boolean aiFeatures = true;

    @Column(name = "is_locked", nullable = false)
    private boolean isLocked = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Version
    @Column(name = "version", nullable = false)
    private int version = 1;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }

    // ─── Feature query ────────────────────────────────────────────────────────

    /**
     * Returns true if the named feature flag is enabled.
     *
     * @param flagName one of: windAdjustmentEnabled, playsLikeEnabled,
     *     elevationEnabled, clubRecommendationEnabled, contoursEnabled,
     *     puttingHelpEnabled, aiFeaturesEnabled
     */
    public boolean isFeatureEnabled(String flagName) {
        return switch (flagName) {
            case "windAdjustmentEnabled" -> windAdjustment;
            case "playsLikeEnabled" -> playsLike;
            case "elevationEnabled" -> elevation;
            case "clubRecommendationEnabled" -> clubRecommendation;
            case "contoursEnabled" -> contours;
            case "puttingHelpEnabled" -> puttingHelp;
            case "aiFeaturesEnabled" -> aiFeatures;
            default -> true;
        };
    }

    // ─── Lock ────────────────────────────────────────────────────────────────

    /**
     * Locks this policy, preventing feature flag changes without TournamentDirector role.
     * Idempotent: no-op if already locked.
     */
    public void lock() {
        this.isLocked = true;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public boolean isWindAdjustment() { return windAdjustment; }
    public void setWindAdjustment(boolean windAdjustment) { this.windAdjustment = windAdjustment; }

    public boolean isPlaysLike() { return playsLike; }
    public void setPlaysLike(boolean playsLike) { this.playsLike = playsLike; }

    public boolean isElevation() { return elevation; }
    public void setElevation(boolean elevation) { this.elevation = elevation; }

    public boolean isClubRecommendation() { return clubRecommendation; }
    public void setClubRecommendation(boolean clubRecommendation) { this.clubRecommendation = clubRecommendation; }

    public boolean isContours() { return contours; }
    public void setContours(boolean contours) { this.contours = contours; }

    public boolean isPuttingHelp() { return puttingHelp; }
    public void setPuttingHelp(boolean puttingHelp) { this.puttingHelp = puttingHelp; }

    public boolean isAiFeatures() { return aiFeatures; }
    public void setAiFeatures(boolean aiFeatures) { this.aiFeatures = aiFeatures; }

    public boolean isLocked() { return isLocked; }
    public void setLocked(boolean locked) { isLocked = locked; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }

    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }
}
