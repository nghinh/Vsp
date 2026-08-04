package vnpt.vsp.module.bag.dto;

import vnpt.vsp.module.bag.entity.GolfBag;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Response DTO for a GolfBag with its clubs.
 */
public class GolfBagResponse {

    private Long id;
    private Long golferAccountId;
    private String name;
    private Boolean isActive;
    private List<ClubResponse> clubs;
    private Instant createdAt;
    private Instant updatedAt;

    public GolfBagResponse() {}

    public static GolfBagResponse fromEntity(GolfBag bag) {
        GolfBagResponse r = new GolfBagResponse();
        r.setId(bag.getId());
        r.setGolferAccountId(bag.getGolferAccountId());
        r.setName(bag.getName());
        r.setIsActive(bag.getIsActive());
        r.setClubs(bag.getClubs().stream()
                .map(ClubResponse::fromEntity)
                .collect(Collectors.toList()));
        r.setCreatedAt(bag.getCreatedAt());
        r.setUpdatedAt(bag.getUpdatedAt());
        return r;
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

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

    public List<ClubResponse> getClubs() {
        return clubs;
    }

    public void setClubs(List<ClubResponse> clubs) {
        this.clubs = clubs;
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
