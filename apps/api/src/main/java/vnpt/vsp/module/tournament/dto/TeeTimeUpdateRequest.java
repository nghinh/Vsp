package vnpt.vsp.module.tournament.dto;

import java.util.UUID;

/**
 * Request DTO for updating a tee time.
 */
public class TeeTimeUpdateRequest {

    private UUID flightId;
    private Long startingTeeBoxId;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }

    public Long getStartingTeeBoxId() { return startingTeeBoxId; }
    public void setStartingTeeBoxId(Long startingTeeBoxId) { this.startingTeeBoxId = startingTeeBoxId; }
}
