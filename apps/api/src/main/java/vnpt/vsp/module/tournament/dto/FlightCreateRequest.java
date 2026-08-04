package vnpt.vsp.module.tournament.dto;

import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.tournament.entity.StartingTee;

/**
 * Request DTO for creating a flight.
 */
public class FlightCreateRequest {

    @NotNull(message = "Flight number is required")
    private Integer flightNumber;

    @NotNull(message = "Starting tee is required")
    private StartingTee startingTee;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Integer getFlightNumber() { return flightNumber; }
    public void setFlightNumber(Integer flightNumber) { this.flightNumber = flightNumber; }

    public StartingTee getStartingTee() { return startingTee; }
    public void setStartingTee(StartingTee startingTee) { this.startingTee = startingTee; }
}
