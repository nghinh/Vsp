package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * TournamentResult entity — final published result for a player.
 * Per Story 12.1: rank, score, scoreToPar, prize, tieBreakApplied, publishedAt.
 */
@Entity
@Table(name = "tournament_results")
public class TournamentResult {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_id", nullable = false)
    private Tournament tournament;

    /** The golfer account, when the player has one. Null for a guest — see V36. */
    @Column(name = "player_id")
    private Long playerId;

    /** The roster entry this result belongs to. The reliable key for a guest. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tournament_player_id")
    private TournamentPlayer tournamentPlayer;

    @Column(name = "division_code", length = 8)
    private String divisionCode;

    /** The prize won, in the division's own words, or null for no prize. */
    @Column(name = "prize_title", length = 120)
    private String prizeTitle;

    @Column(name = "playing_handicap")
    private Integer playingHandicap;

    @Column(name = "net_score")
    private Integer netScore;

    /**
     * Net against par after the outing's floor — the number the prize was
     * actually decided on. Frozen here so a published result can be re-read
     * without re-running the rules that produced it, which may since have
     * changed.
     */
    @Column(name = "judging_score")
    private Integer judgingScore;

    @Column(name = "daily_cap_adjustment")
    private Integer dailyCapAdjustment;

    @Column(name = "eagle_count")
    private Integer eagleCount;

    /** Every configured tie-break came out level; the organisers had to choose. */
    @Column(name = "tied_unresolved", nullable = false)
    private boolean tiedUnresolved = false;

    @Column(name = "rank", nullable = false)
    private int rank;

    @Column(name = "score", nullable = false)
    private int score;

    @Column(name = "score_to_par")
    private Integer scoreToPar;

    @Column(name = "prize")
    private Double prize;

    @Column(name = "tie_break_applied", nullable = false)
    private boolean tieBreakApplied = false;

    /**
     * Number of birdies (or better) recorded across the tournament. Optional —
     * populated from scorecard aggregation; used by the {@code MOST_BIRDIES}
     * tie-break rule. Null when scorecard detail is unavailable.
     */
    @Column(name = "birdie_count")
    private Integer birdieCount;

    /**
     * The player's lowest single-round gross score across the tournament.
     * Optional — used by the {@code LOWEST_ROUND} tie-break rule. Null when
     * per-round detail is unavailable.
     */
    @Column(name = "best_round_score")
    private Integer bestRoundScore;

    /**
     * Comma-separated hole-by-hole gross scores in hole order (hole 1 first),
     * e.g. {@code "4,5,3,4,..."}. Optional — used by the {@code SCORECARD_PLAYOFF}
     * (countback) tie-break rule. Null when hole detail is unavailable.
     */
    @Column(name = "hole_scores", length = 200)
    private String holeScores;

    @Column(name = "published_at")
    private Instant publishedAt;

    // ─── Getters / Setters ───────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public Tournament getTournament() { return tournament; }
    public void setTournament(Tournament tournament) { this.tournament = tournament; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public int getRank() { return rank; }
    public void setRank(int rank) { this.rank = rank; }

    public int getScore() { return score; }
    public void setScore(int score) { this.score = score; }

    public Integer getScoreToPar() { return scoreToPar; }
    public void setScoreToPar(Integer scoreToPar) { this.scoreToPar = scoreToPar; }

    public Double getPrize() { return prize; }
    public void setPrize(Double prize) { this.prize = prize; }

    public boolean isTieBreakApplied() { return tieBreakApplied; }
    public void setTieBreakApplied(boolean tieBreakApplied) { this.tieBreakApplied = tieBreakApplied; }

    public Integer getBirdieCount() { return birdieCount; }
    public void setBirdieCount(Integer birdieCount) { this.birdieCount = birdieCount; }

    public Integer getBestRoundScore() { return bestRoundScore; }
    public void setBestRoundScore(Integer bestRoundScore) { this.bestRoundScore = bestRoundScore; }

    public String getHoleScores() { return holeScores; }
    public void setHoleScores(String holeScores) { this.holeScores = holeScores; }

    public Instant getPublishedAt() { return publishedAt; }
    public void setPublishedAt(Instant publishedAt) { this.publishedAt = publishedAt; }

    public TournamentPlayer getTournamentPlayer() { return tournamentPlayer; }
    public void setTournamentPlayer(TournamentPlayer tournamentPlayer) { this.tournamentPlayer = tournamentPlayer; }

    public String getDivisionCode() { return divisionCode; }
    public void setDivisionCode(String divisionCode) { this.divisionCode = divisionCode; }

    public String getPrizeTitle() { return prizeTitle; }
    public void setPrizeTitle(String prizeTitle) { this.prizeTitle = prizeTitle; }

    public Integer getPlayingHandicap() { return playingHandicap; }
    public void setPlayingHandicap(Integer playingHandicap) { this.playingHandicap = playingHandicap; }

    public Integer getNetScore() { return netScore; }
    public void setNetScore(Integer netScore) { this.netScore = netScore; }

    public Integer getJudgingScore() { return judgingScore; }
    public void setJudgingScore(Integer judgingScore) { this.judgingScore = judgingScore; }

    public Integer getDailyCapAdjustment() { return dailyCapAdjustment; }
    public void setDailyCapAdjustment(Integer dailyCapAdjustment) { this.dailyCapAdjustment = dailyCapAdjustment; }

    public Integer getEagleCount() { return eagleCount; }
    public void setEagleCount(Integer eagleCount) { this.eagleCount = eagleCount; }

    public boolean isTiedUnresolved() { return tiedUnresolved; }
    public void setTiedUnresolved(boolean tiedUnresolved) { this.tiedUnresolved = tiedUnresolved; }
}
