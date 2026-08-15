package vnpt.vsp.module.shot.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Shot entity — represents a single golf shot within a round.
 *
 * <p>Per Story 10.3: Track Shots Manually.
 * 22 canonical fields covering start/end location, club, lie, distance,
 * conditions, result, source, confidence, and sync metadata.
 *
 * <p>Stores WGS84 (SRID 4326) GeoJSON Point as JSON column for startLocation
 * and endLocation. Distance is stored in both yards and meters.
 *
 * <p>Soft-delete: rows with deletedAt != null are considered deleted.
 */
@Entity
@Table(name = "shots")
public class Shot {

    // ─── Enums ─────────────────────────────────────────────────────────────────

    public enum Lie {
        tee_box, fairway, rough, bunker, water, penalty, green, putt,
        out_of_bounds, cart_path, native_rough, primary_rough,
        secondary_rough, waste_bunker, desert, other
    }

    public enum Result {
        fairway_hit, green_hit, in_bunker, in_water, out_of_bounds,
        penalty, mulligan, provisional, scramble_save, chip_in, hole_out,
        in_the_hole, hit_L, hit_slice, hit_pull, hit_push, hit_hook,
        hit_thin, hit_heavy, whiff, unknown
    }

    public enum Source {
        manual, detected, corrected
    }

    public enum SyncStatus {
        pending, synced, failed
    }

    // ─── Primary Key ───────────────────────────────────────────────────────────

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // ─── Foreign Keys ───────────────────────────────────────────────────────────

    @Column(name = "round_id", nullable = false)
    private UUID roundId;

    @Column(name = "flight_id", nullable = false)
    private UUID flightId;

    @Column(name = "player_id", nullable = false)
    private Long playerId;

    // ─── Shot Identity ──────────────────────────────────────────────────────────

    @Column(name = "hole_number", nullable = false)
    private Integer holeNumber;

    @Column(name = "shot_number", nullable = false)
    private Integer shotNumber;

    @Column(name = "club_id")
    private Long clubId;

    // ─── Temporal ──────────────────────────────────────────────────────────────

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    // ─── Spatial (GeoJSON Point as JSON String — SRID 4326) ───────────────────

    /**
     * Start location as GeoJSON Point string: {"type":"Point","coordinates":[lon,lat,elev?]}.
     * SRID 4326 (WGS84). Elevation is optional.
     */
    @Column(name = "start_location", columnDefinition = "TEXT")
    private String startLocation;

    /**
     * End location as GeoJSON Point string: {"type":"Point","coordinates":[lon,lat,elev?]}.
     * SRID 4326 (WGS84). Elevation is optional.
     */
    @Column(name = "end_location", columnDefinition = "TEXT")
    private String endLocation;

    // ─── Lie / Distance ───────────────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "lie", length = 20)
    private Lie lie;

    @Column(name = "distance_yards", precision = 10, scale = 2)
    private BigDecimal distanceYards;

    @Column(name = "distance_meters", precision = 10, scale = 2)
    private BigDecimal distanceMeters;

    /**
     * Conditions snapshot at shot time — JSON string with wind, temp, humidity, altitude.
     */
    @Column(name = "conditions", columnDefinition = "TEXT")
    private String conditions;

    // ─── Result ────────────────────────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "result", length = 30)
    private Result result;

    @Column(name = "is_penalty", nullable = false)
    private Boolean isPenalty = false;

    @Column(name = "is_provisional", nullable = false)
    private Boolean isProvisional = false;

    @Column(name = "is_mulligan", nullable = false)
    private Boolean isMulligan = false;

    /**
     * If non-null, this shot was merged into the referenced shot.
     * Used for audit trail of merge operations.
     */
    @Column(name = "merged_into_shot_id")
    private UUID mergedIntoShotId;

    // ─── Source / Quality ─────────────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 15, nullable = false)
    private Source source = Source.manual;

    /**
     * Confidence in shot detection quality. 0.0–1.0.
     * Null for manual shots; populated for detected shots.
     */
    @Column(name = "confidence", precision = 3, scale = 2)
    private BigDecimal confidence;

    // ─── Sync Metadata ────────────────────────────────────────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "sync_status", length = 10, nullable = false)
    private SyncStatus syncStatus = SyncStatus.pending;

    @Column(name = "idempotency_key", length = 60, nullable = false, unique = true)
    private String idempotencyKey;

    // ─── Audit ────────────────────────────────────────────────────────────────

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    // ─── Lifecycle Callbacks ───────────────────────────────────────────────────

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ─────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getRoundId() { return roundId; }
    public void setRoundId(UUID roundId) { this.roundId = roundId; }

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public Integer getHoleNumber() { return holeNumber; }
    public void setHoleNumber(Integer holeNumber) { this.holeNumber = holeNumber; }

    public Integer getShotNumber() { return shotNumber; }
    public void setShotNumber(Integer shotNumber) { this.shotNumber = shotNumber; }

    public Long getClubId() { return clubId; }
    public void setClubId(Long clubId) { this.clubId = clubId; }

    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }

    public Instant getEndedAt() { return endedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }

    public String getStartLocation() { return startLocation; }
    public void setStartLocation(String startLocation) { this.startLocation = startLocation; }

    public String getEndLocation() { return endLocation; }
    public void setEndLocation(String endLocation) { this.endLocation = endLocation; }

    public Lie getLie() { return lie; }
    public void setLie(Lie lie) { this.lie = lie; }

    public BigDecimal getDistanceYards() { return distanceYards; }
    public void setDistanceYards(BigDecimal distanceYards) { this.distanceYards = distanceYards; }

    public BigDecimal getDistanceMeters() { return distanceMeters; }
    public void setDistanceMeters(BigDecimal distanceMeters) { this.distanceMeters = distanceMeters; }

    public String getConditions() { return conditions; }
    public void setConditions(String conditions) { this.conditions = conditions; }

    public Result getResult() { return result; }
    public void setResult(Result result) { this.result = result; }

    public Boolean getIsPenalty() { return isPenalty; }
    public void setIsPenalty(Boolean isPenalty) { this.isPenalty = isPenalty; }

    public Boolean getIsProvisional() { return isProvisional; }
    public void setIsProvisional(Boolean isProvisional) { this.isProvisional = isProvisional; }

    public Boolean getIsMulligan() { return isMulligan; }
    public void setIsMulligan(Boolean isMulligan) { this.isMulligan = isMulligan; }

    public UUID getMergedIntoShotId() { return mergedIntoShotId; }
    public void setMergedIntoShotId(UUID mergedIntoShotId) { this.mergedIntoShotId = mergedIntoShotId; }

    public Source getSource() { return source; }
    public void setSource(Source source) { this.source = source; }

    public BigDecimal getConfidence() { return confidence; }
    public void setConfidence(BigDecimal confidence) { this.confidence = confidence; }

    public SyncStatus getSyncStatus() { return syncStatus; }
    public void setSyncStatus(SyncStatus syncStatus) { this.syncStatus = syncStatus; }

    public String getIdempotencyKey() { return idempotencyKey; }
    public void setIdempotencyKey(String idempotencyKey) { this.idempotencyKey = idempotencyKey; }

    public Instant getDeletedAt() { return deletedAt; }
    public void setDeletedAt(Instant deletedAt) { this.deletedAt = deletedAt; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
