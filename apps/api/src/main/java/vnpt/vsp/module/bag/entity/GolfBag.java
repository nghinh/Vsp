package vnpt.vsp.module.bag.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Golf bag entity representing a golfer's golf bag with optional active flag.
 * Per Story 2.4 AC-1: bags can be created, edited, deleted.
 * Per Story 2.4 AC-2: exactly one bag is active at a time — enforced at service layer.
 * Per PRD Section 9.1: GolfBag listed as core entity.
 */
@Entity
@Table(name = "golf_bags")
public class GolfBag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "golfer_account_id", nullable = false)
    private Long golferAccountId;

    @Column(nullable = false)
    private String name = "My Bag";

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = false;

    @OneToMany(mappedBy = "golfBag", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<Club> clubs = new ArrayList<>();

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

    public List<Club> getClubs() {
        return clubs;
    }

    public void setClubs(List<Club> clubs) {
        this.clubs = clubs;
    }

    public void addClub(Club club) {
        clubs.add(club);
        club.setGolfBag(this);
    }

    public void removeClub(Club club) {
        clubs.remove(club);
        club.setGolfBag(null);
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
