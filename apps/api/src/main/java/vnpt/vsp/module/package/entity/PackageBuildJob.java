package vnpt.vsp.module.pkg.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;

/**
 * JPA entity for an async package build job.
 *
 * Tracks the lifecycle of a course package build from QUEUED through
 * COMPLETED or FAILED. Each job is scoped to a (courseId, dataVersionId)
 * pair and carries the resulting manifestVersion on success.
 *
 * Idempotent trigger: triggerPackageBuild() checks for existing non-terminal
 * jobs for the same course before enqueueing a duplicate.
 *
 * Per Story 4.2 AC-1 (queues build), AC-2 (actionable failures visible in portal).
 */
@Entity
@Table(name = "package_build_job",
    indexes = {
        @Index(name = "idx_job_course_created", columnList = "courseId, createdAt"),
        @Index(name = "idx_job_status", columnList = "status")
    })
public class PackageBuildJob {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @NotNull
    @Column(nullable = false)
    private Long courseId;

    @NotNull
    @Column(nullable = false)
    private Long dataVersionId;

    /**
     * The semver version assigned to this package build.
     * Format: {dataVersionMajor}.{dataVersionMinor}.{buildNumber}
     * e.g. "1.3.0", "1.3.1". Set when the job reaches COMPLETED.
     */
    private String manifestVersion;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PackageBuildStatus status;

    @NotNull
    @Column(nullable = false)
    private Instant createdAt;

    /** When the worker picked up the job (null if still QUEUED) */
    private Instant startedAt;

    /** When the job reached a terminal state (COMPLETED or FAILED) */
    private Instant completedAt;

    /** Machine-readable error code from the predefined set (null unless FAILED) */
    private String errorCode;

    /** Human-readable error summary (null unless FAILED) */
    private String errorMessage;

    /**
     * Actionable fix hint or full stack trace for operators (null unless FAILED).
     * Examples:
     *   - "Geometry incomplete — complete all hole geometry before publishing"
     *   - "ST_AsMVT tile generation failed for hole 5: invalid polygon ring"
     */
    private String errorDetail;

    /** Username of the operator who triggered this build */
    @NotBlank
    @Column(nullable = false)
    private String triggeredBy;

    /** Total elapsed time in milliseconds (null until COMPLETED or FAILED) */
    private Long buildDurationMs;

    // JPA-required no-arg constructor
    protected PackageBuildJob() {}

    public PackageBuildJob(Long courseId, Long dataVersionId, String triggeredBy) {
        this.courseId = courseId;
        this.dataVersionId = dataVersionId;
        this.triggeredBy = triggeredBy;
        this.status = PackageBuildStatus.QUEUED;
        this.createdAt = Instant.now();
    }

    // Getters
    public UUID getId() { return id; }
    public Long getCourseId() { return courseId; }
    public Long getDataVersionId() { return dataVersionId; }
    public String getManifestVersion() { return manifestVersion; }
    public PackageBuildStatus getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getCompletedAt() { return completedAt; }
    public String getErrorCode() { return errorCode; }
    public String getErrorMessage() { return errorMessage; }
    public String getErrorDetail() { return errorDetail; }
    public String getTriggeredBy() { return triggeredBy; }
    public Long getBuildDurationMs() { return buildDurationMs; }

    // State-transition helpers
    public void markStarted() {
        this.status = PackageBuildStatus.VALIDATING;
        this.startedAt = Instant.now();
    }

    public void setStatus(PackageBuildStatus status) {
        this.status = status;
    }

    public void markCompleted(String manifestVersion) {
        this.status = PackageBuildStatus.COMPLETED;
        this.completedAt = Instant.now();
        this.manifestVersion = manifestVersion;
        if (this.startedAt != null) {
            this.buildDurationMs = java.time.Duration.between(this.startedAt, this.completedAt).toMillis();
        }
    }

    public void markFailed(String errorCode, String errorMessage, String errorDetail) {
        this.status = PackageBuildStatus.FAILED;
        this.completedAt = Instant.now();
        this.errorCode = errorCode;
        this.errorMessage = errorMessage;
        this.errorDetail = errorDetail;
        if (this.startedAt != null) {
            this.buildDurationMs = java.time.Duration.between(this.startedAt, this.completedAt).toMillis();
        }
    }

    /** True if this job is in a non-terminal state */
    public boolean isInProgress() {
        return status != PackageBuildStatus.COMPLETED && status != PackageBuildStatus.FAILED;
    }
}
