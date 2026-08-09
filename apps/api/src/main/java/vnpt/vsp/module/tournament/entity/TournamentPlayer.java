package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * TournamentPlayer entity — registered player in a tournament.
 * Per Story 12.1: registered, confirmed, withdrawn, disqualified statuses.
 */
@Entity
@Table(name = "tournament_players")
public class TournamentPlayer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    /**
     * The golfer account, when the player has one.
     *
     * Null for a guest. Most of a club outing's field are names on a
     * spreadsheet who have never opened the app, and requiring an account here
     * meant the roster could not be imported at all — see V36.
     */
    @Column(name = "player_id")
    private Long playerId;

    /** The name on the flight sheet. Required when there is no account. */
    @Column(name = "display_name", length = 120)
    private String displayName;

    /** Mã VGA, as the club records it. Free text — not every player has one. */
    @Column(name = "vga_code", length = 32)
    private String vgaCode;

    /** Which prize group, per the outing's configured divisions. */
    @Column(name = "division_code", length = 8)
    private String divisionCode;

    /** The handicap the prize is judged off, after the outing's cap. */
    @Column(name = "playing_handicap")
    private Integer playingHandicap;

    /**
     * The round's gross, when only a total has been entered.
     *
     * The hole scores win where both are present: the eighteen numbers are the
     * scorecard and this is the shortcut that gets a leaderboard up first.
     */
    @Column(name = "gross_total")
    private Integer grossTotal;

    /** Strokes per hole in play order; 0 means not entered. */
    @Column(name = "hole_scores", columnDefinition = "integer[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private Integer[] holeScores;

    /**
     * Birdies as the flight reported them.
     *
     * Only consulted when the hole scores are absent — on the fast path a round
     * is a single number and there is nothing to count from.
     */
    @Column(name = "birdie_count")
    private Integer birdieCount;

    @Column(name = "eagle_count")
    private Integer eagleCount;

    @Column(name = "scores_entered_at")
    private Instant scoresEnteredAt;

    @Column(name = "scores_entered_by")
    private Long scoresEnteredBy;

    @Column(name = "handicap")
    private Double handicap;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "flight_id")
    private Flight flight;

    @Column(name = "registration_time", nullable = false)
    private Instant registrationTime;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private TournamentPlayerStatus status = TournamentPlayerStatus.REGISTERED;

    @PrePersist
    protected void onCreate() {
        if (registrationTime == null) {
            registrationTime = Instant.now();
        }
    }

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public String getVgaCode() { return vgaCode; }
    public void setVgaCode(String vgaCode) { this.vgaCode = vgaCode; }

    public String getDivisionCode() { return divisionCode; }
    public void setDivisionCode(String divisionCode) { this.divisionCode = divisionCode; }

    public Integer getPlayingHandicap() { return playingHandicap; }
    public void setPlayingHandicap(Integer playingHandicap) { this.playingHandicap = playingHandicap; }

    public Integer getGrossTotal() { return grossTotal; }
    public void setGrossTotal(Integer grossTotal) { this.grossTotal = grossTotal; }

    public Integer[] getHoleScores() { return holeScores; }
    public void setHoleScores(Integer[] holeScores) { this.holeScores = holeScores; }

    public Instant getScoresEnteredAt() { return scoresEnteredAt; }
    public void setScoresEnteredAt(Instant scoresEnteredAt) { this.scoresEnteredAt = scoresEnteredAt; }

    public Long getScoresEnteredBy() { return scoresEnteredBy; }
    public void setScoresEnteredBy(Long scoresEnteredBy) { this.scoresEnteredBy = scoresEnteredBy; }

    public Double getHandicap() { return handicap; }
    public void setHandicap(Double handicap) { this.handicap = handicap; }

    public Flight getFlight() { return flight; }
    public void setFlight(Flight flight) { this.flight = flight; }

    public Instant getRegistrationTime() { return registrationTime; }
    public void setRegistrationTime(Instant registrationTime) { this.registrationTime = registrationTime; }

    public TournamentPlayerStatus getStatus() { return status; }
    public void setStatus(TournamentPlayerStatus status) { this.status = status; }

    public Integer getBirdieCount() { return birdieCount; }
    public void setBirdieCount(Integer birdieCount) { this.birdieCount = birdieCount; }

    public Integer getEagleCount() { return eagleCount; }
    public void setEagleCount(Integer eagleCount) { this.eagleCount = eagleCount; }
}
