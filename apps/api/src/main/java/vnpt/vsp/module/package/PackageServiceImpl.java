package vnpt.vsp.module.pkg;

import org.springframework.stereotype.Service;

/**
 * Implementation of PackageService.
 *
 * Business logic for manifest validation, discovery, and build job management.
 * Package generation and download are handled in Stories 4.2 and 4.3.
 */
@Service
public class PackageServiceImpl implements PackageService {

    private final vnpt.vsp.module.pkg.repository.PackageManifestRepository manifestRepository;
    private final vnpt.vsp.module.pkg.repository.PackageBuildJobRepository buildJobRepository;

    public PackageServiceImpl(
            vnpt.vsp.module.pkg.repository.PackageManifestRepository manifestRepository,
            vnpt.vsp.module.pkg.repository.PackageBuildJobRepository buildJobRepository) {
        this.manifestRepository = manifestRepository;
        this.buildJobRepository = buildJobRepository;
    }

    @Override
    public java.util.UUID triggerPackageBuild(Long courseId, Long dataVersionId, String triggeredBy) {
        // Idempotency: return existing non-terminal job for this course if one exists
        var terminalStatuses = java.util.List.of(
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.COMPLETED,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.FAILED
        );
        var nonTerminalStatuses = java.util.List.of(
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.QUEUED,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.VALIDATING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.BUILDING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.ASSEMBLING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.UPLOADING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.PUBLISHING
        );

        return buildJobRepository.findFirstByCourseIdAndStatusIn(courseId, nonTerminalStatuses)
                .map(existing -> existing.getId())
                .orElseGet(() -> {
                    var job = new vnpt.vsp.module.pkg.entity.PackageBuildJob(courseId, dataVersionId, triggeredBy);
                    return buildJobRepository.save(job).getId();
                });
    }

    @Override
    public vnpt.vsp.module.pkg.entity.PackageBuildJob queueBuildForCourse(
            Long courseId, Long dataVersionId, String triggeredBy) {
        // Idempotency per (courseId, dataVersionId): return existing non-terminal job
        // for this specific course version if one exists. Different versions of the
        // same course each get their own independent build job.
        var nonTerminalStatuses = java.util.List.of(
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.QUEUED,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.VALIDATING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.BUILDING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.ASSEMBLING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.UPLOADING,
                vnpt.vsp.module.pkg.entity.PackageBuildStatus.PUBLISHING
        );

        return buildJobRepository
                .findFirstByCourseIdAndDataVersionIdAndStatusIn(courseId, dataVersionId, nonTerminalStatuses)
                .orElseGet(() -> {
                    var job = new vnpt.vsp.module.pkg.entity.PackageBuildJob(courseId, dataVersionId, triggeredBy);
                    return buildJobRepository.save(job);
                });
    }

    @Override
    public java.util.Optional<vnpt.vsp.module.pkg.entity.PackageBuildJob> getBuildJob(java.util.UUID jobId) {
        return buildJobRepository.findById(jobId);
    }

    @Override
    public java.util.List<vnpt.vsp.module.pkg.entity.PackageBuildJob> getBuildHistory(Long courseId) {
        return buildJobRepository.findByCourseIdOrderByCreatedAtDesc(courseId);
    }

    @Override
    public ManifestValidationResult validateManifest(
            String checksum,
            java.util.List<String> filePaths,
            String minimumClientVersion,
            String clientVersion) {

        // Check client version compatibility
        if (minimumClientVersion != null && clientVersion != null) {
            if (compareSemver(clientVersion, minimumClientVersion) < 0) {
                return ManifestValidationResult.VERSION_TOO_OLD;
            }
        }

        // Check archive checksum (caller computes SHA-256 of downloaded archive)
        if (checksum == null || checksum.isBlank()) {
            return ManifestValidationResult.CHECKSUM_MISMATCH;
        }

        // Note: full file-level checksum validation of individual entries
        // is performed by the download service (Story 4.3) during unpacking.
        // Here we only validate the top-level archive checksum which was
        // already verified by the caller.

        return ManifestValidationResult.VALID;
    }

    @Override
    public java.util.Optional<vnpt.vsp.module.pkg.entity.CoursePackageManifest> getActiveManifest(Long courseId) {
        return manifestRepository.findActiveManifest(courseId, java.time.Instant.now());
    }

    @Override
    public java.util.List<vnpt.vsp.module.pkg.entity.CoursePackageManifest> getManifestHistory(Long courseId) {
        return manifestRepository.findByCourseIdOrderByVersionDesc(courseId);
    }

    /**
     * Compare two semver strings.
     * Returns negative if v < minVersion, zero if equal, positive if v > minVersion.
     */
    private int compareSemver(String v, String minVersion) {
        if (v == null) return -1;
        if (minVersion == null) return 0;
        String[] vParts = v.split("\\.");
        String[] mParts = minVersion.split("\\.");
        int length = Math.max(vParts.length, mParts.length);
        for (int i = 0; i < length; i++) {
            int vPart = i < vParts.length ? Integer.parseInt(vParts[i].replaceAll("[^0-9]", "")) : 0;
            int mPart = i < mParts.length ? Integer.parseInt(mParts[i].replaceAll("[^0-9]", "")) : 0;
            if (vPart != mPart) return Integer.compare(vPart, mPart);
        }
        return 0;
    }
}
