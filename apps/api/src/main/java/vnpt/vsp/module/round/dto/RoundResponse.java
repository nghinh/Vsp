package vnpt.vsp.module.round.dto;

import vnpt.vsp.module.round.entity.Round;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for round creation and retrieval.
 * Per Story 5.1 Slice D and round.yaml Round contract.
 *
 * Note: courseId uses Long to match Course entity ID type (backend convention).
 * The round.yaml contract uses UUID format for courseId in the external API;
 * conversion happens at the API boundary.
 */
public class RoundResponse {

    private UUID id;
    private Long courseId;

    /**
     * The second nine, where the round pairs two of them.
     *
     * Long Biên has three đường of nine holes and a round there is a pairing
     * chosen on the day. The round has always carried this — it is a column on
     * the entity and the resolver uses it — and it was never sent to the app,
     * so a resumed round had holes 10 to 18 belonging to no course at all. The
     * map asked the front nine for its hole 10, which does not exist, and drew
     * nothing.
     */
    private Long backNineCourseId;
    private String courseName;
    private Round.RoundStatus status;
    private Instant startedAt;
    private Instant endedAt;
    private Instant createdAt;
    private UUID tournamentPolicyId;
    private UUID tournamentId;
    private Integer tournamentPolicyVersion;

    public RoundResponse() {}

    public RoundResponse(UUID id, Long courseId, String courseName, Round.RoundStatus status,
                         Instant startedAt, Instant endedAt, Instant createdAt,
                         UUID tournamentPolicyId, UUID tournamentId, Integer tournamentPolicyVersion) {
        this.id = id;
        this.courseId = courseId;
        this.courseName = courseName;
        this.status = status;
        this.startedAt = startedAt;
        this.endedAt = endedAt;
        this.createdAt = createdAt;
        this.tournamentPolicyId = tournamentPolicyId;
        this.tournamentId = tournamentId;
        this.tournamentPolicyVersion = tournamentPolicyVersion;
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public Long getBackNineCourseId() {
        return backNineCourseId;
    }

    public void setBackNineCourseId(Long backNineCourseId) {
        this.backNineCourseId = backNineCourseId;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public String getCourseName() {
        return courseName;
    }

    public void setCourseName(String courseName) {
        this.courseName = courseName;
    }

    public Round.RoundStatus getStatus() {
        return status;
    }

    public void setStatus(Round.RoundStatus status) {
        this.status = status;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public void setStartedAt(Instant startedAt) {
        this.startedAt = startedAt;
    }

    public Instant getEndedAt() {
        return endedAt;
    }

    public void setEndedAt(Instant endedAt) {
        this.endedAt = endedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public UUID getTournamentPolicyId() { return tournamentPolicyId; }
    public void setTournamentPolicyId(UUID tournamentPolicyId) { this.tournamentPolicyId = tournamentPolicyId; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public Integer getTournamentPolicyVersion() { return tournamentPolicyVersion; }
    public void setTournamentPolicyVersion(Integer tournamentPolicyVersion) { this.tournamentPolicyVersion = tournamentPolicyVersion; }
}
