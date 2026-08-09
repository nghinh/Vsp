package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.TournamentPlayer;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for tournament player.
 */
public class TournamentPlayerResponse {

    private UUID id;
    private UUID tournamentId;
    private Long playerId;
    private Double handicap;
    private UUID flightId;
    private Instant registrationTime;
    private String status;

    // ─── Outing roster (V36) ────────────────────────────────────────────────
    private String displayName;
    private String vgaCode;
    private String divisionCode;
    private Integer playingHandicap;
    private Integer flightNumber;
    private Integer grossTotal;
    private Integer[] holeScores;
    private Integer birdieCount;
    private Integer eagleCount;
    /** True once anything has been typed for this player — drives the "still out" state. */
    private boolean hasScore;

    public static TournamentPlayerResponse fromEntity(TournamentPlayer entity) {
        TournamentPlayerResponse response = new TournamentPlayerResponse();
        response.setId(entity.getId());
        response.setTournamentId(entity.getTournament().getId());
        response.setPlayerId(entity.getPlayerId());
        response.setHandicap(entity.getHandicap());
        response.setFlightId(entity.getFlight() != null ? entity.getFlight().getId() : null);
        response.setRegistrationTime(entity.getRegistrationTime());
        response.setStatus(entity.getStatus().name());
        response.setDisplayName(entity.getDisplayName());
        response.setVgaCode(entity.getVgaCode());
        response.setDivisionCode(entity.getDivisionCode());
        response.setPlayingHandicap(entity.getPlayingHandicap());
        response.setFlightNumber(entity.getFlight() != null ? entity.getFlight().getFlightNumber() : null);
        response.setGrossTotal(entity.getGrossTotal());
        response.setHoleScores(entity.getHoleScores());
        response.setBirdieCount(entity.getBirdieCount());
        response.setEagleCount(entity.getEagleCount());
        response.setHasScore(entity.getGrossTotal() != null || anyHoleEntered(entity.getHoleScores()));
        return response;
    }

    private static boolean anyHoleEntered(Integer[] holes) {
        if (holes == null) return false;
        for (Integer h : holes) {
            if (h != null && h > 0) return true;
        }
        return false;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public Double getHandicap() { return handicap; }
    public void setHandicap(Double handicap) { this.handicap = handicap; }

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }

    public Instant getRegistrationTime() { return registrationTime; }
    public void setRegistrationTime(Instant registrationTime) { this.registrationTime = registrationTime; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public String getVgaCode() { return vgaCode; }
    public void setVgaCode(String vgaCode) { this.vgaCode = vgaCode; }

    public String getDivisionCode() { return divisionCode; }
    public void setDivisionCode(String divisionCode) { this.divisionCode = divisionCode; }

    public Integer getPlayingHandicap() { return playingHandicap; }
    public void setPlayingHandicap(Integer playingHandicap) { this.playingHandicap = playingHandicap; }

    public Integer getFlightNumber() { return flightNumber; }
    public void setFlightNumber(Integer flightNumber) { this.flightNumber = flightNumber; }

    public Integer getGrossTotal() { return grossTotal; }
    public void setGrossTotal(Integer grossTotal) { this.grossTotal = grossTotal; }

    public Integer[] getHoleScores() { return holeScores; }
    public void setHoleScores(Integer[] holeScores) { this.holeScores = holeScores; }

    public boolean isHasScore() { return hasScore; }
    public void setHasScore(boolean hasScore) { this.hasScore = hasScore; }

    public Integer getBirdieCount() { return birdieCount; }
    public void setBirdieCount(Integer birdieCount) { this.birdieCount = birdieCount; }

    public Integer getEagleCount() { return eagleCount; }
    public void setEagleCount(Integer eagleCount) { this.eagleCount = eagleCount; }
}
