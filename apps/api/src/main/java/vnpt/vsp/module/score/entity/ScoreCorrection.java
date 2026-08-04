package vnpt.vsp.module.score.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Score correction audit entry.
 * Records every correction made to a score entry, including actor, timestamp, field, old/new values.
 * Per Story 5.5 AC-3: corrections are append-only with full audit trail.
 */
@Entity
@Table(name = "score_corrections")
public class ScoreCorrection {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "round_id", nullable = false)
    private UUID roundId;

    @Column(name = "player_id", nullable = false)
    private Long playerId;

    @Column(name = "score_entry_id")
    private UUID scoreEntryId;

    @Column(name = "hole_number")
    private Integer holeNumber;

    @Column(name = "field_name", length = 50, nullable = false)
    private String fieldName;

    @Column(name = "old_value", columnDefinition = "TEXT")
    private String oldValue;

    @Column(name = "new_value", columnDefinition = "TEXT")
    private String newValue;

    @Column(name = "corrected_at", nullable = false)
    private Instant correctedAt;

    @Column(name = "corrected_by", nullable = false)
    private Long correctedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        if (correctedAt == null) {
            correctedAt = Instant.now();
        }
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getRoundId() {
        return roundId;
    }

    public void setRoundId(UUID roundId) {
        this.roundId = roundId;
    }

    public Long getPlayerId() {
        return playerId;
    }

    public void setPlayerId(Long playerId) {
        this.playerId = playerId;
    }

    public UUID getScoreEntryId() {
        return scoreEntryId;
    }

    public void setScoreEntryId(UUID scoreEntryId) {
        this.scoreEntryId = scoreEntryId;
    }

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public String getFieldName() {
        return fieldName;
    }

    public void setFieldName(String fieldName) {
        this.fieldName = fieldName;
    }

    public String getOldValue() {
        return oldValue;
    }

    public void setOldValue(String oldValue) {
        this.oldValue = oldValue;
    }

    public String getNewValue() {
        return newValue;
    }

    public void setNewValue(String newValue) {
        this.newValue = newValue;
    }

    public Instant getCorrectedAt() {
        return correctedAt;
    }

    public void setCorrectedAt(Instant correctedAt) {
        this.correctedAt = correctedAt;
    }

    public Long getCorrectedBy() {
        return correctedBy;
    }

    public void setCorrectedBy(Long correctedBy) {
        this.correctedBy = correctedBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
