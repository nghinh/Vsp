package vnpt.vsp.module.profile.dto;

import jakarta.validation.constraints.*;

/**
 * Request DTO for updating a golfer's profile via PUT /profiles/me.
 * Per Story 2.3 AC-1: all golf preference fields are optional for partial update.
 * Per Story 2.3 AC-2: driverDistance is accepted as canonical meters only.
 */
public class UpdateGolferProfileRequest {

    @DecimalMin(value = "-5.0", message = "Handicap must be at least -5")
    @DecimalMax(value = "54.0", message = "Handicap must be at most 54")
    private Double handicap;

    @Size(max = 255, message = "Home club must be at most 255 characters")
    private String homeClub;

    @Pattern(regexp = "^(METERS|YARDS)?$", message = "Distance unit must be METERS or YARDS")
    private String distanceUnit;

    @Pattern(regexp = "^(LEFT|RIGHT)?$", message = "Dominant hand must be LEFT or RIGHT")
    private String dominantHand;

    @Pattern(regexp = "^(BEGINNER|INTERMEDIATE|ADVANCED|PRO)?$", message = "Skill level must be BEGINNER, INTERMEDIATE, ADVANCED, or PRO")
    private String skillLevel;

    @Min(value = 18, message = "Target score must be at least 18")
    @Max(value = 180, message = "Target score must be at most 180")
    private Integer targetScore;

    @Min(value = 1, message = "Driver distance must be positive")
    private Integer driverDistance; // canonical meters

    @Min(value = 20, message = "Swing speed must be at least 20 mph")
    @Max(value = 200, message = "Swing speed must be at most 200 mph")
    private Integer swingSpeed;

    @Pattern(regexp = "^(MALE|FEMALE|OTHER)?$", message = "Gender must be MALE, FEMALE, or OTHER")
    private String gender;

    @Min(value = 1900, message = "Birth year must be at least 1900")
    @Max(value = 2010, message = "Birth year must be at most 2010")
    private Integer birthYear;

    @Size(max = 100, message = "Country must be at most 100 characters")
    private String country;

    @Size(max = 512, message = "Image URL must be at most 512 characters")
    private String imageUrl;

    public UpdateGolferProfileRequest() {
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Double getHandicap() {
        return handicap;
    }

    public void setHandicap(Double handicap) {
        this.handicap = handicap;
    }

    public String getHomeClub() {
        return homeClub;
    }

    public void setHomeClub(String homeClub) {
        this.homeClub = homeClub;
    }

    public String getDistanceUnit() {
        return distanceUnit;
    }

    public void setDistanceUnit(String distanceUnit) {
        this.distanceUnit = distanceUnit;
    }

    public String getDominantHand() {
        return dominantHand;
    }

    public void setDominantHand(String dominantHand) {
        this.dominantHand = dominantHand;
    }

    public String getSkillLevel() {
        return skillLevel;
    }

    public void setSkillLevel(String skillLevel) {
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

    public String getGender() {
        return gender;
    }

    public void setGender(String gender) {
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
}
