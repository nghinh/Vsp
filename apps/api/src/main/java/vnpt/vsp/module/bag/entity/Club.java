package vnpt.vsp.module.bag.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

/**
 * Club entity representing a single golf club in a golf bag.
 * Per Story 2.4 AC-1: clubs have loft, carryDistance, totalDistance, dispersion, shaft, useDate.
 * Per PRD Phase 2: dispersion stored but NOT used in MVP recommendations.
 * Per PRD Section 8.7: distances stored in canonical meters; display conversion is UI responsibility.
 */
@Entity
@Table(name = "clubs")
public class Club {

    public enum ClubType {
        DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "golf_bag_id", nullable = false)
    private GolfBag golfBag;

    @Enumerated(EnumType.STRING)
    @Column(name = "club_type", nullable = false, length = 20)
    private ClubType clubType;

    @Column
    private Double loft; // degrees

    @Column(name = "carry_distance")
    private Double carryDistance; // canonical: meters

    @Column(name = "total_distance")
    private Double totalDistance; // canonical: meters

    /**
     * True while {@link #carryDistance} is the seeded standard rather than this
     * golfer's own measurement.
     *
     * <p>A bag starts filled with a standard fourteen so a golfer gets club
     * advice on their first round instead of typing fourteen numbers first.
     * Once written, a seeded 128 m looks exactly like a measured 128 m — and
     * the advice built on it is only as good as the number. This is what lets
     * the app say which is which, and it is cleared the moment the golfer edits
     * the carry, because from then on the number is theirs.
     */
    @Column(name = "carry_is_default", nullable = false)
    private boolean carryIsDefault = false;

    @Column
    private Double dispersion; // degrees — Phase 2 scope

    @Column(length = 100)
    private String shaft;

    @Column(name = "use_date")
    private LocalDate useDate;

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

    public GolfBag getGolfBag() {
        return golfBag;
    }

    public void setGolfBag(GolfBag golfBag) {
        this.golfBag = golfBag;
    }

    public boolean isCarryIsDefault() {
        return carryIsDefault;
    }

    public void setCarryIsDefault(boolean carryIsDefault) {
        this.carryIsDefault = carryIsDefault;
    }

    public ClubType getClubType() {
        return clubType;
    }

    public void setClubType(ClubType clubType) {
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
