package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.TeeTime;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for tee time.
 */
public class TeeTimeResponse {

    private UUID id;
    private UUID tournamentId;
    private Instant teeTime;
    private Long courseId;
    private Long startingTeeBoxId;
    private UUID flightId;

    public static TeeTimeResponse fromEntity(TeeTime entity) {
        TeeTimeResponse response = new TeeTimeResponse();
        response.setId(entity.getId());
        response.setTournamentId(entity.getTournament().getId());
        response.setTeeTime(entity.getTeeTime());
        response.setCourseId(entity.getCourseId());
        response.setStartingTeeBoxId(entity.getStartingTeeBoxId());
        response.setFlightId(entity.getFlight() != null ? entity.getFlight().getId() : null);
        return response;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public Instant getTeeTime() { return teeTime; }
    public void setTeeTime(Instant teeTime) { this.teeTime = teeTime; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getStartingTeeBoxId() { return startingTeeBoxId; }
    public void setStartingTeeBoxId(Long startingTeeBoxId) { this.startingTeeBoxId = startingTeeBoxId; }

    public UUID getFlightId() { return flightId; }
    public void setFlightId(UUID flightId) { this.flightId = flightId; }
}
