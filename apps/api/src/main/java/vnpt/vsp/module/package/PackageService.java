package vnpt.vsp.module.pkg;

/**
 * Package module public service interface.
 * Exposes course package manifest and generation operations.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface PackageService {

    /**
     * Validate a downloaded package manifest against client-provided checksums and version.
     *
     * Returns a validation result indicating whether the manifest is valid,
     * or the specific failure reason (checksum mismatch, version too old, missing file).
     * Story 4.1 AC-3: corrupt or incompatible packages are rejected without replacing
     * the last valid package.
     */
    ManifestValidationResult validateManifest(
        String checksum,
        java.util.List<String> filePaths,
        String minimumClientVersion,
        String clientVersion
    );

    /**
     * Get the currently active (effective) manifest for a course.
     *
     * Returns empty if no package exists or none is currently effective.
     */
    java.util.Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> getActiveManifest(Long courseId);

    /**
     * Get the version history for a course (all manifests, newest first).
     */
    java.util.List<vnpt.vsp.module.pkg.entity.CoursePackageManifest> getManifestHistory(Long courseId);

    /**
     * Trigger an async package build for a course.
     *
     * Idempotent: if a non-terminal job already exists for this course,
     * returns that job ID without creating a duplicate.
     *
     * AC-1: Publishing queues validation, build, upload, CDN publication.
     *
     * @return the ID of the enqueued (or existing) build job
     */
    java.util.UUID triggerPackageBuild(Long courseId, Long dataVersionId, String triggeredBy);

    /**
     * Queue (or return existing) an async package build for a course version.
     *
     * Idempotent per (courseId, dataVersionId) pair: if a non-terminal job already
     * exists for this course AND version, returns that job without creating a duplicate.
     * Different versions of the same course each get their own independent build job.
     *
     * Used by PublishService to hook published course versions into the build pipeline.
     *
     * @return the enqueued (or existing) build job
     */
    vnpt.vsp.module.pkg.entity.PackageBuildJob queueBuildForCourse(Long courseId, Long dataVersionId, String triggeredBy);

    /**
     * Get a specific build job by ID.
     * Returns empty if the job does not exist or belongs to a different course.
     *
     * AC-2: Build status visible in portal.
     */
    java.util.Optional<vnpt.vsp.module.pkg.entity.PackageBuildJob> getBuildJob(java.util.UUID jobId);

    /**
     * Get the build history for a course (all jobs, newest first).
     *
     * AC-2: Build status visible in portal.
     */
    java.util.List<vnpt.vsp.module.pkg.entity.PackageBuildJob> getBuildHistory(Long courseId);

    /**
     * Result of manifest validation — valid or specific failure reason.
     */
    enum ManifestValidationResult {
        VALID,
        CHECKSUM_MISMATCH,
        VERSION_TOO_OLD,
        MISSING_FILE
    }
}
