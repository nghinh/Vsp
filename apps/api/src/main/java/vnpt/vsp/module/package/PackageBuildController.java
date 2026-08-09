package vnpt.vsp.module.pkg;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vnpt.vsp.module.pkg.entity.PackageBuildJob;
import java.util.List;
import java.util.UUID;

/**
 * REST controller for package build job management.
 *
 * Exposes:
 * - POST /courses/{courseId}/packages/build — trigger a build (idempotent)
 * - GET  /courses/{courseId}/packages/build/jobs — list job history
 * - GET  /courses/{courseId}/packages/build/jobs/{jobId} — get specific job status
 *
 * All endpoints require COURSE_ADMIN or higher RBAC.
 *
 * <p>That sentence was in this comment from the first commit and was not true:
 * there were no {@code @PreAuthorize} annotations, and this controller sits
 * outside {@code /admin/**}, which is the only path the security chain gates by
 * URL. Any signed-in golfer could trigger a build — verified against a freshly
 * registered account, which got HTTP 200 and a job id. Each build runs the whole
 * pipeline and publishes a new manifest version, so every device holding that
 * course is then told an update is available and re-downloads it. A comment
 * describing a control nobody implemented is worse than no comment: it is what
 * stops the next reader from checking.</p>
 *
 * Per Story 4.2 PKG-PUBLISH-3 AC-1 (API to trigger build), AC-2 (API for portal polling).
 */
@RestController
@RequestMapping("/courses/{courseId}/packages/build")
public class PackageBuildController {

    private final PackageService packageService;

    public PackageBuildController(PackageService packageService) {
        this.packageService = packageService;
    }

    /**
     * Trigger a package build for a course.
     * Idempotent — returns existing job ID if a non-terminal job is already in progress.
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN')")
    public ResponseEntity<TriggerBuildResponse> triggerBuild(
            @PathVariable Long courseId,
            @jakarta.validation.Valid @RequestBody TriggerBuildRequest request) {

        UUID jobId = packageService.triggerPackageBuild(
                courseId,
                request.getDataVersionId(),
                request.getTriggeredBy()
        );

        return ResponseEntity.ok(new TriggerBuildResponse(jobId.toString()));
    }

    /**
     * List all build jobs for a course (newest first).
     */
    @GetMapping("/jobs")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN', 'AUDITOR')")
    public ResponseEntity<PackageBuildJobListResponse> listBuildJobs(
            @PathVariable Long courseId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        List<PackageBuildJob> allJobs = packageService.getBuildHistory(courseId);

        int start = page * pageSize;
        int end = Math.min(start + pageSize, allJobs.size());
        List<PackageBuildJob> pageJobs = start < allJobs.size()
                ? allJobs.subList(start, end)
                : List.of();

        var response = new PackageBuildJobListResponse(
                pageJobs.stream().map(this::toDto).toList(),
                allJobs.size(),
                page,
                pageSize
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Get a specific build job by ID.
     */
    @GetMapping("/jobs/{jobId}")
    @PreAuthorize("hasAnyRole('COURSE_ADMIN', 'SUPER_ADMIN', 'AUDITOR')")
    public ResponseEntity<PackageBuildJobDto> getBuildJob(
            @PathVariable Long courseId,
            @PathVariable UUID jobId) {

        return packageService.getBuildJob(jobId)
                .filter(job -> job.getCourseId().equals(courseId))
                .map(job -> ResponseEntity.ok(toDto(job)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    private PackageBuildJobDto toDto(PackageBuildJob job) {
        return new PackageBuildJobDto(
                job.getId().toString(),
                job.getCourseId(),
                job.getDataVersionId(),
                job.getManifestVersion(),
                job.getStatus().name(),
                job.getCreatedAt(),
                job.getStartedAt(),
                job.getCompletedAt(),
                job.getErrorCode(),
                job.getErrorMessage(),
                job.getErrorDetail(),
                job.getTriggeredBy(),
                job.getBuildDurationMs()
        );
    }

    // ─── Request/Response DTOs (inner static classes) ────────────────────────

    public static class TriggerBuildRequest {
        /**
         * Which published version to package. Required.
         *
         * package_build_job.data_version_id is NOT NULL, so omitting this used
         * to reach the insert and come back as a 500 "contact support with the
         * correlation ID" — for a request that was simply missing a field. The
         * caller can act on "dataVersionId is required"; they can do nothing
         * with a correlation ID.
         */
        @jakarta.validation.constraints.NotNull(message = "dataVersionId is required")
        private Long dataVersionId;

        @jakarta.validation.constraints.NotBlank(message = "triggeredBy is required")
        private String triggeredBy;

        public Long getDataVersionId() { return dataVersionId; }
        public void setDataVersionId(Long dataVersionId) { this.dataVersionId = dataVersionId; }
        public String getTriggeredBy() { return triggeredBy; }
        public void setTriggeredBy(String triggeredBy) { this.triggeredBy = triggeredBy; }
    }

    public static class TriggerBuildResponse {
        private final String jobId;
        public TriggerBuildResponse(String jobId) { this.jobId = jobId; }
        public String getJobId() { return jobId; }
    }

    public static class PackageBuildJobListResponse {
        private List<PackageBuildJobDto> jobs;
        private long total;
        private int page;
        private int pageSize;

        public PackageBuildJobListResponse(List<PackageBuildJobDto> jobs, long total, int page, int pageSize) {
            this.jobs = jobs;
            this.total = total;
            this.page = page;
            this.pageSize = pageSize;
        }

        public List<PackageBuildJobDto> getJobs() { return jobs; }
        public long getTotal() { return total; }
        public int getPage() { return page; }
        public int getPageSize() { return pageSize; }
    }

    public static class PackageBuildJobDto {
        private String jobId;
        private Long courseId;
        private Long dataVersionId;
        private String manifestVersion;
        private String status;
        private java.time.Instant createdAt;
        private java.time.Instant startedAt;
        private java.time.Instant completedAt;
        private String errorCode;
        private String errorMessage;
        private String errorDetail;
        private String triggeredBy;
        private Long buildDurationMs;

        public PackageBuildJobDto(String jobId, Long courseId, Long dataVersionId,
                String manifestVersion, String status,
                java.time.Instant createdAt, java.time.Instant startedAt,
                java.time.Instant completedAt,
                String errorCode, String errorMessage, String errorDetail,
                String triggeredBy, Long buildDurationMs) {
            this.jobId = jobId;
            this.courseId = courseId;
            this.dataVersionId = dataVersionId;
            this.manifestVersion = manifestVersion;
            this.status = status;
            this.createdAt = createdAt;
            this.startedAt = startedAt;
            this.completedAt = completedAt;
            this.errorCode = errorCode;
            this.errorMessage = errorMessage;
            this.errorDetail = errorDetail;
            this.triggeredBy = triggeredBy;
            this.buildDurationMs = buildDurationMs;
        }

        public String getJobId() { return jobId; }
        public Long getCourseId() { return courseId; }
        public Long getDataVersionId() { return dataVersionId; }
        public String getManifestVersion() { return manifestVersion; }
        public String getStatus() { return status; }
        public java.time.Instant getCreatedAt() { return createdAt; }
        public java.time.Instant getStartedAt() { return startedAt; }
        public java.time.Instant getCompletedAt() { return completedAt; }
        public String getErrorCode() { return errorCode; }
        public String getErrorMessage() { return errorMessage; }
        public String getErrorDetail() { return errorDetail; }
        public String getTriggeredBy() { return triggeredBy; }
        public Long getBuildDurationMs() { return buildDurationMs; }
    }
}
