package vnpt.vsp.module.tournament.dto;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;

/**
 * Request DTO for creating a tee time.
 */
public class TeeTimeCreateRequest {

    @NotNull(message = "Tee time is required")
    private Instant teeTime;

    @NotNull(message = "Course ID is required")
    private Long courseId;

    private Long startingTeeBoxId;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public Instant getTeeTime() { return teeTime; }
    public void setTeeTime(Instant teeTime) { this.teeTime = teeTime; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Long getStartingTeeBoxId() { return startingTeeBoxId; }
    public void setStartingTeeBoxId(Long startingTeeBoxId) { this.startingTeeBoxId = startingTeeBoxId; }
}
