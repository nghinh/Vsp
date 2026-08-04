package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.Flight;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Response DTO for flight.
 */
public class FlightResponse {

    private UUID id;
    private UUID tournamentId;
    private int flightNumber;
    private List<Long> playerIds;
    private UUID teeTimeId;
    private String startingTee;
    private Instant confirmedAt;
    private Long confirmedBy;

    public static FlightResponse fromEntity(Flight entity) {
        FlightResponse response = new FlightResponse();
        response.setId(entity.getId());
        response.setTournamentId(entity.getTournament().getId());
        response.setFlightNumber(entity.getFlightNumber());
        response.setPlayerIds(entity.getPlayers().stream()
                .map(p -> p.getPlayerId())
                .toList());
        response.setTeeTimeId(entity.getTeeTime() != null ? entity.getTeeTime().getId() : null);
        response.setStartingTee(entity.getStartingTee().name());
        response.setConfirmedAt(entity.getConfirmedAt());
        response.setConfirmedBy(entity.getConfirmedBy());
        return response;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public int getFlightNumber() { return flightNumber; }
    public void setFlightNumber(int flightNumber) { this.flightNumber = flightNumber; }

    public List<Long> getPlayerIds() { return playerIds; }
    public void setPlayerIds(List<Long> playerIds) { this.playerIds = playerIds; }

    public UUID getTeeTimeId() { return teeTimeId; }
    public void setTeeTimeId(UUID teeTimeId) { this.teeTimeId = teeTimeId; }

    public String getStartingTee() { return startingTee; }
    public void setStartingTee(String startingTee) { this.startingTee = startingTee; }

    public Instant getConfirmedAt() { return confirmedAt; }
    public void setConfirmedAt(Instant confirmedAt) { this.confirmedAt = confirmedAt; }

    public Long getConfirmedBy() { return confirmedBy; }
    public void setConfirmedBy(Long confirmedBy) { this.confirmedBy = confirmedBy; }
}
