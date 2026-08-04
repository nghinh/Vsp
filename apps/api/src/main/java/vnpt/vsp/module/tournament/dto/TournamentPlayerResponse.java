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

    public static TournamentPlayerResponse fromEntity(TournamentPlayer entity) {
        TournamentPlayerResponse response = new TournamentPlayerResponse();
        response.setId(entity.getId());
        response.setTournamentId(entity.getTournament().getId());
        response.setPlayerId(entity.getPlayerId());
        response.setHandicap(entity.getHandicap());
        response.setFlightId(entity.getFlight() != null ? entity.getFlight().getId() : null);
        response.setRegistrationTime(entity.getRegistrationTime());
        response.setStatus(entity.getStatus().name());
        return response;
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
}
