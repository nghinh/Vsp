package vnpt.vsp.module.tournament.dto;

import java.util.UUID;

/**
 * Response DTO for a single leaderboard entry.
 */
public class LeaderboardEntryResponse {

    private int rank;
    private Long playerId;
    private String playerName;
    private Integer score;
    private Integer scoreToPar;
    private Integer thru;
    private String status;
    private UUID flightId;
    private boolean isTied;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public int getRank() { return rank; }
    public void setRank(int rank) { this.rank = rank; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public String getPlayerName() { return playerName; }
    public void setPlayerName(String playerName) { this.playerName = playerName; }

    public Integer getScore() { return score; }
    public void setScore(Integer score) { this.score = score; }

    public Integer getScoreToPar() { return scoreToPar; }
    public void setScoreToPar(Integer scoreToPar) { this.scoreToPar = scoreToPar; }

    public Integer getThru() { return thru; }
    public void setThru(Integer thru) { this.thru = thru; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }

    public boolean isTied() { return isTied; }
    public void setTied(boolean tied) { isTied = tied; }
}
