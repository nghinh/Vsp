package vnpt.vsp.module.round.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Round entity representing a golf round.
 * Per PRD: supports in_progress, completed, abandoned, cancelled statuses.
 */
@Entity
@Table(name = "rounds")
public class Round {

    public enum RoundStatus {
        IN_PROGRESS,
        COMPLETED,
        ABANDONED,
        CANCELLED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * The course this round is played on.
     * TODO ( Slice D gap): V13 migration does not include course_id column.
     * A follow-up migration V14 should add: ALTER TABLE rounds ADD COLUMN course_id BIGINT REFERENCES courses(id)
     */
    @Column(name = "course_id")
    private Long courseId;

    /**
     * The second nine, where the round is composed of two.
     *
     * <p>Long Biên is đường A, B and C at nine holes each, so an eighteen there
     * is two of them. A round could name one course, which left holes 10 to 18
     * belonging to nothing: the map had no survey for them, advice answered
     * 404, and the pars and yardages this project had already loaded were
     * unreachable.
     *
     * <p>Null where the round is one eighteen-hole layout, which is most of
     * them — {@link #courseId} then means the whole course, exactly as before.
     */
    @Column(name = "back_nine_course_id")
    private Long backNineCourseId;

    @Column(name = "golfer_account_id", nullable = false)
    private Long golferAccountId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    private RoundStatus status = RoundStatus.IN_PROGRESS;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    /**
     * Tournament policy ID for tournament-format rounds.
     * Required when format is TOURNAMENT; null for casual and practice rounds.
     */
    @Column(name = "tournament_policy_id")
    private UUID tournamentPolicyId;

    /**
     * Tournament ID — links the round to a tournament event.
     * When set, the round is a tournament round and submits scores to the tournament.
     * Per Story 12.1 Slice F.
     */
    @Column(name = "tournament_id")
    private UUID tournamentId;

    /**
     * Version of the tournament policy at round creation time.
     * Used to detect mid-round policy changes — mobile shows update banner
     * when server policy version differs from this value.
     * Per Story 12.1 Slice F.
     */
    @Column(name = "tournament_policy_version")
    private Integer tournamentPolicyVersion;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public Long getCourseId() {
        return courseId;
    }

    public void setCourseId(Long courseId) {
        this.courseId = courseId;
    }

    public Long getBackNineCourseId() {
        return backNineCourseId;
    }

    public void setBackNineCourseId(Long backNineCourseId) {
        this.backNineCourseId = backNineCourseId;
    }

    /**
     * Which course a hole of this round belongs to, and its number there.
     *
     * <p>Hole 10 of a round composed of two nines is hole 1 of the back nine.
     * Everything that asks about a hole — the map, the scorecard, the advice —
     * has to ask the course that actually holds it, and this is the one place
     * that translation lives.
     *
     * @return [courseId, holeNumberOnThatCourse]
     */
    public long[] resolveHole(int holeNumber) {
        if (backNineCourseId == null || holeNumber <= 9) {
            return new long[]{courseId == null ? 0L : courseId, holeNumber};
        }
        return new long[]{backNineCourseId, holeNumber - 9};
    }

    public Long getGolferAccountId() {
        return golferAccountId;
    }

    public void setGolferAccountId(Long golferAccountId) {
        this.golferAccountId = golferAccountId;
    }

    public RoundStatus getStatus() {
        return status;
    }

    public void setStatus(RoundStatus status) {
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

    public Instant getDeletedAt() {
        return deletedAt;
    }

    public void setDeletedAt(Instant deletedAt) {
        this.deletedAt = deletedAt;
    }

    public UUID getTournamentPolicyId() { return tournamentPolicyId; }
    public void setTournamentPolicyId(UUID tournamentPolicyId) { this.tournamentPolicyId = tournamentPolicyId; }

    public UUID getTournamentId() { return tournamentId; }
    public void setTournamentId(UUID tournamentId) { this.tournamentId = tournamentId; }

    public Integer getTournamentPolicyVersion() { return tournamentPolicyVersion; }
    public void setTournamentPolicyVersion(Integer tournamentPolicyVersion) { this.tournamentPolicyVersion = tournamentPolicyVersion; }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
