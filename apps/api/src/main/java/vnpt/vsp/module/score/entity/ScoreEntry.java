package vnpt.vsp.module.score.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * ScoreEntry entity representing a per-hole score record.
 * Per Story 5.5 Slice 1: stores strokes, putts, penalties, fairway, GIR, bunker, club, notes.
 */
@Entity
@Table(name = "score_entries")
public class ScoreEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "score_id", nullable = false)
    private UUID scoreId;

    @Column(name = "hole_number", nullable = false)
    private Integer holeNumber;

    @Column(name = "par", nullable = false)
    private Integer par;

    @Column(name = "strokes", nullable = false)
    private Integer strokes;

    @Column(name = "putts")
    private Integer putts = 0;

    @Column(name = "penalties")
    private Integer penalties = 0;

    @Column(name = "fairway_hit")
    private Boolean fairwayHit;

    @Column(name = "gir")
    private Boolean gir;

    @Column(name = "bunker")
    private Boolean bunker;

    @Column(name = "club", length = 50)
    private String club;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

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

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getScoreId() {
        return scoreId;
    }

    public void setScoreId(UUID scoreId) {
        this.scoreId = scoreId;
    }

    public Integer getHoleNumber() {
        return holeNumber;
    }

    public void setHoleNumber(Integer holeNumber) {
        this.holeNumber = holeNumber;
    }

    public Integer getPar() {
        return par;
    }

    public void setPar(Integer par) {
        this.par = par;
    }

    public Integer getStrokes() {
        return strokes;
    }

    public void setStrokes(Integer strokes) {
        this.strokes = strokes;
    }

    public Integer getPutts() {
        return putts;
    }

    public void setPutts(Integer putts) {
        this.putts = putts;
    }

    public Integer getPenalties() {
        return penalties;
    }

    public void setPenalties(Integer penalties) {
        this.penalties = penalties;
    }

    public Boolean getFairwayHit() {
        return fairwayHit;
    }

    public void setFairwayHit(Boolean fairwayHit) {
        this.fairwayHit = fairwayHit;
    }

    public Boolean getGir() {
        return gir;
    }

    public void setGir(Boolean gir) {
        this.gir = gir;
    }

    public Boolean getBunker() {
        return bunker;
    }

    public void setBunker(Boolean bunker) {
        this.bunker = bunker;
    }

    public String getClub() {
        return club;
    }

    public void setClub(String club) {
        this.club = club;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
