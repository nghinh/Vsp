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

    @Column(name = "player_id", nullable = false)
    private Long playerId;

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
}
