package vnpt.vsp.module.tournament.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import vnpt.vsp.module.tournament.entity.TournamentFormat;

import java.time.Instant;
import java.util.UUID;

/**
 * Request DTO for creating a tournament.
 */
public class TournamentCreateRequest {

    @NotBlank(message = "Tournament name is required")
    private String name;

    @NotNull(message = "Format is required")
    private TournamentFormat format;

    @NotNull(message = "Course ID is required")
    private Long courseId;

    @NotNull(message = "Start date is required")
    private Instant startDate;

    @NotNull(message = "End date is required")
    private Instant endDate;

    private UUID tournamentPolicyId;
    private Instant registrationDeadline;
    private Integer maxPlayers;
    private String description;

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public TournamentFormat getFormat() { return format; }
    public void setFormat(TournamentFormat format) { this.format = format; }

    public Long getCourseId() { return courseId; }
    public void setCourseId(Long courseId) { this.courseId = courseId; }

    public Instant getStartDate() { return startDate; }
    public void setStartDate(Instant startDate) { this.startDate = startDate; }

    public Instant getEndDate() { return endDate; }
    public void setEndDate(Instant endDate) { this.endDate = endDate; }

    public UUID getTournamentPolicyId() { return tournamentPolicyId; }
    public void setTournamentPolicyId(UUID tournamentPolicyId) { this.tournamentPolicyId = tournamentPolicyId; }

    public Instant getRegistrationDeadline() { return registrationDeadline; }
    public void setRegistrationDeadline(Instant registrationDeadline) { this.registrationDeadline = registrationDeadline; }

    public Integer getMaxPlayers() { return maxPlayers; }
    public void setMaxPlayers(Integer maxPlayers) { this.maxPlayers = maxPlayers; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}
