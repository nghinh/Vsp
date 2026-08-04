package vnpt.vsp.module.tournament.dto;

import java.util.List;
import java.util.UUID;

/**
 * Request DTO for updating a flight.
 */
public class FlightUpdateRequest {

    private List<Long> playerIds;
    private UUID teeTimeId;
    private String startingTee;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public List<Long> getPlayerIds() { return playerIds; }
    public void setPlayerIds(List<Long> playerIds) { this.playerIds = playerIds; }

    public UUID getTeeTimeId() { return teeTimeId; }
    public void setTeeTimeId(UUID teeTimeId) { this.teeTimeId = teeTimeId; }

    public String getStartingTee() { return startingTee; }
    public void setStartingTee(String startingTee) { this.startingTee = startingTee; }
}
