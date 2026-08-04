package vnpt.vsp.module.tournament.dto;

import vnpt.vsp.module.tournament.entity.Tournament;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for tournament.
 */
public class TournamentResponse {

    private UUID id;
    private String name;
    private String format;
    private String status;
    private Long courseId;
    private Instant startDate;
    private Instant endDate;
    private UUID tournamentPolicyId;
    private Instant registrationDeadline;
    private Integer maxPlayers;
    private String description;
    private long leaderboardVersion;
    private Instant createdAt;
    private Long createdBy;
    private int version;

    public static TournamentResponse fromEntity(Tournament entity) {
        TournamentResponse response = new TournamentResponse();
        response.setId(entity.getId());
        response.setName(entity.getName());
        response.setFormat(entity.getFormat().name());
        response.setStatus(entity.getStatus().name());
        response.setCourseId(entity.getCourseId());
        response.setStartDate(entity.getStartDate());
        response.setEndDate(entity.getEndDate());
        response.setTournamentPolicyId(entity.getTournamentPolicyId());
        response.setRegistrationDeadline(entity.getRegistrationDeadline());
        response.setMaxPlayers(entity.getMaxPlayers());
        response.setDescription(entity.getDescription());
        response.setLeaderboardVersion(entity.getLeaderboardVersion());
        response.setCreatedAt(entity.getCreatedAt());
        response.setCreatedBy(entity.getCreatedBy());
        response.setVersion(entity.getVersion());
        return response;
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getFormat() { return format; }
    public void setFormat(String format) { this.format = format; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

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

    public long getLeaderboardVersion() { return leaderboardVersion; }
    public void setLeaderboardVersion(long leaderboardVersion) { this.leaderboardVersion = leaderboardVersion; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }

    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }
}
