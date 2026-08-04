package vnpt.vsp.module.profile.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * Golfer profile entity representing a golfer's golf-specific preferences.
 * Per PRD Section 8.1: supports handicap, home club, distance unit, dominant hand,
 *   target handicap, skill level, driver distance, swing speed, gender, birth year, country.
 * Per PRD Section 8.7: canonical unit storage is meters; display conversion is UI responsibility.
 * Per Story 2.3 AC-1: profile supports all required fields.
 * Per Story 2.3 AC-2: canonical meters storage — unit changes do not corrupt canonical values.
 */
@Entity
@Table(name = "golfer_profiles")
public class GolferProfile {

    public enum DistanceUnit {
        METERS, YARDS
    }

    public enum DominantHand {
        LEFT, RIGHT
    }

    public enum SkillLevel {
        BEGINNER, INTERMEDIATE, ADVANCED, PRO
    }

    public enum Gender {
        MALE, FEMALE, OTHER
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "golfer_account_id", nullable = false, unique = true)
    private Long golferAccountId;

    @Column(precision = 4, scale = 1)
    private BigDecimal handicap;

    @Column(name = "home_club", length = 255)
    private String homeClub;

    @Enumerated(EnumType.STRING)
    @Column(name = "distance_unit", length = 10, nullable = false)
    private DistanceUnit distanceUnit = DistanceUnit.METERS;

    @Enumerated(EnumType.STRING)
    @Column(name = "dominant_hand", length = 10, nullable = false)
    private DominantHand dominantHand = DominantHand.RIGHT;

    @Enumerated(EnumType.STRING)
    @Column(name = "skill_level", length = 20, nullable = false)
    private SkillLevel skillLevel = SkillLevel.INTERMEDIATE;

    @Column(name = "target_score")
    private Integer targetScore;

    @Column(name = "driver_distance")
    private Integer driverDistance; // canonical: meters

    @Column(name = "swing_speed")
    private Integer swingSpeed;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender", length = 10)
    private Gender gender;

    @Column(name = "birth_year")
    private Integer birthYear;

    @Column(length = 100)
    private String country;

    @Column(name = "image_url", length = 512)
    private String imageUrl;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getGolferAccountId() {
        return golferAccountId;
    }

    public void setGolferAccountId(Long golferAccountId) {
        this.golferAccountId = golferAccountId;
    }

    public BigDecimal getHandicap() {
        return handicap;
    }

    public void setHandicap(BigDecimal handicap) {
        this.handicap = handicap;
    }

    public String getHomeClub() {
        return homeClub;
    }

    public void setHomeClub(String homeClub) {
        this.homeClub = homeClub;
    }

    public DistanceUnit getDistanceUnit() {
        return distanceUnit;
    }

    public void setDistanceUnit(DistanceUnit distanceUnit) {
        this.distanceUnit = distanceUnit;
    }

    public DominantHand getDominantHand() {
        return dominantHand;
    }

    public void setDominantHand(DominantHand dominantHand) {
        this.dominantHand = dominantHand;
    }

    public SkillLevel getSkillLevel() {
        return skillLevel;
    }

    public void setSkillLevel(SkillLevel skillLevel) {
        this.skillLevel = skillLevel;
    }

    public Integer getTargetScore() {
        return targetScore;
    }

    public void setTargetScore(Integer targetScore) {
        this.targetScore = targetScore;
    }

    public Integer getDriverDistance() {
        return driverDistance;
    }

    public void setDriverDistance(Integer driverDistance) {
        this.driverDistance = driverDistance;
    }

    public Integer getSwingSpeed() {
        return swingSpeed;
    }

    public void setSwingSpeed(Integer swingSpeed) {
        this.swingSpeed = swingSpeed;
    }

    public Gender getGender() {
        return gender;
    }

    public void setGender(Gender gender) {
        this.gender = gender;
    }

    public Integer getBirthYear() {
        return birthYear;
    }

    public void setBirthYear(Integer birthYear) {
        this.birthYear = birthYear;
    }

    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        this.country = country;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    // Setters for test mocking (timestamps are normally set by @PrePersist/@PreUpdate)
    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
