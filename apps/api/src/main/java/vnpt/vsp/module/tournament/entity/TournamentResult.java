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

    public Instant getPublishedAt() { return publishedAt; }
    public void setPublishedAt(Instant publishedAt) { this.publishedAt = publishedAt; }
}
