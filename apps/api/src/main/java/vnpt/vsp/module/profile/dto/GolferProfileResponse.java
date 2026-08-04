package vnpt.vsp.module.profile.dto;

import vnpt.vsp.module.profile.entity.GolferProfile;

/**
 * Response DTO for the /profiles/me endpoint.
 * Per Story 2.3 AC-1: includes all golf preference fields.
 * Per Story 2.3 AC-2: canonical meters storage — unit field is display preference only.
 */
public class GolferProfileResponse {

    private Long id;
    private Long golferAccountId;
    private Double handicap;
    private String homeClub;
    private String distanceUnit;       // display preference: METERS or YARDS
    private String dominantHand;      // LEFT or RIGHT
    private String skillLevel;        // BEGINNER, INTERMEDIATE, ADVANCED, PRO
    private Integer targetScore;
    private Integer driverDistance;    // canonical: meters
    private Integer swingSpeed;
    private String gender;            // MALE, FEMALE, OTHER
    private Integer birthYear;
    private String country;
    private String imageUrl;
    private String createdAt;
    private String updatedAt;

    public GolferProfileResponse() {
    }

    public static Builder builder() {
        return new Builder();
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

    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    public String getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }

    /**
     * Maps a {@link GolferProfile} entity to this response DTO.
     */
    public static GolferProfileResponse fromEntity(GolferProfile profile) {
        return builder()
                .id(profile.getId())
                .golferAccountId(profile.getGolferAccountId())
                .handicap(profile.getHandicap() != null ? profile.getHandicap().doubleValue() : null)
                .homeClub(profile.getHomeClub())
                .distanceUnit(profile.getDistanceUnit() != null ? profile.getDistanceUnit().name() : null)
                .dominantHand(profile.getDominantHand() != null ? profile.getDominantHand().name() : null)
                .skillLevel(profile.getSkillLevel() != null ? profile.getSkillLevel().name() : null)
                .targetScore(profile.getTargetScore())
                .driverDistance(profile.getDriverDistance())
                .swingSpeed(profile.getSwingSpeed())
                .gender(profile.getGender() != null ? profile.getGender().name() : null)
                .birthYear(profile.getBirthYear())
                .country(profile.getCountry())
                .imageUrl(profile.getImageUrl())
                .createdAt(profile.getCreatedAt() != null ? profile.getCreatedAt().toString() : null)
                .updatedAt(profile.getUpdatedAt() != null ? profile.getUpdatedAt().toString() : null)
                .build();
    }

    public static class Builder {
        private final GolferProfileResponse response = new GolferProfileResponse();

        public Builder id(Long id) {
            response.id = id;
            return this;
        }

        public Builder golferAccountId(Long golferAccountId) {
            response.golferAccountId = golferAccountId;
            return this;
        }

        public Builder handicap(Double handicap) {
            response.handicap = handicap;
            return this;
        }

        public Builder homeClub(String homeClub) {
            response.homeClub = homeClub;
            return this;
        }

        public Builder distanceUnit(String distanceUnit) {
            response.distanceUnit = distanceUnit;
            return this;
        }

        public Builder dominantHand(String dominantHand) {
            response.dominantHand = dominantHand;
            return this;
        }

        public Builder skillLevel(String skillLevel) {
            response.skillLevel = skillLevel;
            return this;
        }

        public Builder targetScore(Integer targetScore) {
            response.targetScore = targetScore;
            return this;
        }

        public Builder driverDistance(Integer driverDistance) {
            response.driverDistance = driverDistance;
            return this;
        }

        public Builder swingSpeed(Integer swingSpeed) {
            response.swingSpeed = swingSpeed;
            return this;
        }

        public Builder gender(String gender) {
            response.gender = gender;
            return this;
        }

        public Builder birthYear(Integer birthYear) {
            response.birthYear = birthYear;
            return this;
        }

        public Builder country(String country) {
            response.country = country;
            return this;
        }

        public Builder imageUrl(String imageUrl) {
            response.imageUrl = imageUrl;
            return this;
        }

        public Builder createdAt(String createdAt) {
            response.createdAt = createdAt;
            return this;
        }

        public Builder updatedAt(String updatedAt) {
            response.updatedAt = updatedAt;
            return this;
        }

        public GolferProfileResponse build() {
            return response;
        }
    }
}
