package vnpt.vsp.module.bag.dto;

import vnpt.vsp.module.bag.entity.Club;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Response DTO for a Club.
 * Per Story 2.4 AC-1: all club fields returned.
 * Per PRD Phase 2: dispersion is stored and returned.
 */
public class ClubResponse {

    private Long id;
    private Long golfBagId;
    private String clubType;
    private Double loft;
    private Double carryDistance;
    private Double totalDistance;
    private Double dispersion;
    private String shaft;
    private LocalDate useDate;
    private Instant createdAt;
    private Instant updatedAt;

    public ClubResponse() {}

    public static ClubResponse fromEntity(Club club) {
        ClubResponse r = new ClubResponse();
        r.setId(club.getId());
        r.setGolfBagId(club.getGolfBag() != null ? club.getGolfBag().getId() : null);
        r.setClubType(club.getClubType() != null ? club.getClubType().name() : null);
        r.setLoft(club.getLoft());
        r.setCarryDistance(club.getCarryDistance());
        r.setTotalDistance(club.getTotalDistance());
        r.setDispersion(club.getDispersion());
        r.setShaft(club.getShaft());
        r.setUseDate(club.getUseDate());
        r.setCreatedAt(club.getCreatedAt());
        r.setUpdatedAt(club.getUpdatedAt());
        return r;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getGolfBagId() {
        return golfBagId;
    }

    public void setGolfBagId(Long golfBagId) {
        this.golfBagId = golfBagId;
    }

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

    public LocalDate getUseDate() {
        return useDate;
    }

    public void setUseDate(LocalDate useDate) {
        this.useDate = useDate;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
