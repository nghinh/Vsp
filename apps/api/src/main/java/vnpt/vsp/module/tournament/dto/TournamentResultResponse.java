package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.TournamentResult;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for tournament result.
 */
public class TournamentResultResponse {

    private UUID id;
    private UUID tournamentId;
    private Long playerId;
    private int rank;
    private int score;
    private Integer scoreToPar;
    private Double prize;
    private boolean tieBreakApplied;
    private Instant publishedAt;

    public static TournamentResultResponse fromEntity(TournamentResult entity) {
        TournamentResultResponse response = new TournamentResultResponse();
        response.setId(entity.getId());
        response.setTournamentId(entity.getTournament().getId());
        response.setPlayerId(entity.getPlayerId());
        response.setRank(entity.getRank());
        response.setScore(entity.getScore());
        response.setScoreToPar(entity.getScoreToPar());
        response.setPrize(entity.getPrize());
        response.setTieBreakApplied(entity.isTieBreakApplied());
        response.setPublishedAt(entity.getPublishedAt());
        return response;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

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
