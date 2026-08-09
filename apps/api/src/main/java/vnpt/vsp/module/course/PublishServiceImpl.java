package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.dto.PublishResponse;
import vnpt.vsp.module.course.dto.ValidationResponse;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.correction.entity.CourseCorrection;
import vnpt.vsp.module.correction.repository.CourseCorrectionRepository;
import vnpt.vsp.module.pkg.PackageService;

import java.util.UUID;

/**
 * Implementation of {@link PublishService}.
 * Per Story 8.3 AC-1, AC-2, AC-3.
 *
 * <p>Orchestrates: validate → create immutable snapshot → audit log → queue PackageBuildJob.
 */
@Service
@CourseModule
@Transactional
public class PublishServiceImpl implements PublishService {

    private static final Logger log = LoggerFactory.getLogger(PublishServiceImpl.class);

    private final DataVersionRepository dataVersionRepository;
    private final ValidationService validationService;
    private final VersionDiffService versionDiffService;
    private final AuditService auditService;
    private final PackageService packageService;
    private final CourseCorrectionRepository correctionRepository;

    public PublishServiceImpl(
            DataVersionRepository dataVersionRepository,
            ValidationService validationService,
            VersionDiffService versionDiffService,
            AuditService auditService,
            PackageService packageService,
            CourseCorrectionRepository correctionRepository) {
        this.dataVersionRepository = dataVersionRepository;
        this.validationService = validationService;
        this.versionDiffService = versionDiffService;
        this.auditService = auditService;
        this.packageService = packageService;
        this.correctionRepository = correctionRepository;
    }

    @Override
    public PublishResponse publishVersion(Long versionId, String publishNote, String publishedBy) {
        // 1. Load and validate the draft version
        DataVersion version = dataVersionRepository.findById(versionId).orElseThrow(
                () -> new IllegalArgumentException("DataVersion not found: " + versionId));

        if (version.getStatus() != DataVersionStatus.DRAFT) {
            throw new IllegalArgumentException(
                    "Only DRAFT versions can be published, found status: " + version.getStatus());
        }

        // 2. Pre-publish validation — blocks if errors found
        ValidationResponse validationResult = validationService.validateForPublish(versionId);
        if (validationResult.getResult() != ValidationResponse.Result.VALID &&
                validationResult.getResult() != ValidationResponse.Result.SOURCE_MISSING) {
            // SOURCE_MISSING is a warning-level issue, allow publish
            // Blocking errors: GEOMETRY_INVALID, METADATA_MISSING, LICENSE_MISSING,
            // QUALITY_INSUFFICIENT, VALIDATION_ERROR
            throw new PublishValidationException(validationResult);
        }

        // 3. Generate diff for the response (non-blocking audit context)
        // The diff is generated here so it can be included in audit metadata
        var diff = versionDiffService.generateDiff(versionId);
        String diffSummary = String.format(
                "added=%d, removed=%d, changed=%d",
                diff.getAdded().size(),
                diff.getRemoved().size(),
                diff.getChanged().size());

        // 4. Transition DRAFT → PUBLISHED
        version.publish(publishedBy, publishNote);
        dataVersionRepository.save(version);

        // 5. Audit log — COURSE_VERSION_PUBLISHED
        String metadataJson = String.format(
                "{\"courseId\":%d,\"versionNumber\":%d,\"publishNote\":\"%s\",\"diff\":{%s}}",
                version.getCourse().getId(),
                version.getVersionNumber(),
                escapeJson(publishNote),
                diffSummary);
        auditService.log(
                AuditAction.COURSE_VERSION_PUBLISHED,
                "DataVersion",
                versionId.toString(),
                null, // beforeJson — not captured for MVP
                null, // afterJson — full snapshot deferred to async
                metadataJson);

        // 6. Queue async package build (idempotent per course+version)
        UUID buildJobId = null;
        try {
            var buildJob = packageService.queueBuildForCourse(
                    version.getCourse().getId(),
                    versionId,
                    publishedBy);
            buildJobId = buildJob.getId();
        } catch (Exception e) {
            // Build job creation failure must not fail the publish transaction
            log.warn("Failed to queue PackageBuildJob for DataVersion {}: {}",
                    versionId, e.getMessage());
        }

        return new PublishResponse(
                version.getId(),
                version.getVersionNumber(),
                DataVersionStatus.PUBLISHED.name(),
                null, // auditId — AuditService is async, ID not available synchronously
                buildJobId,
                version.getPublishedAt());
    }

    // ─── publishVersion with correction lineage (Story 9.3 Wave 4) ──────────────

    @Override
    public PublishResponse publishVersion(
            Long versionId,
            Long correctionId,
            String publishNote,
            String publishedBy) {

        log.info("Publishing version with correction lineage: versionId={}, correctionId={}, publishedBy={}",
                versionId, correctionId, publishedBy);

        // 1. Load and validate the draft version
        DataVersion version = dataVersionRepository.findById(versionId).orElseThrow(
                () -> new IllegalArgumentException("DataVersion not found: " + versionId));

        if (version.getStatus() != DataVersionStatus.DRAFT) {
            throw new IllegalArgumentException(
                    "Only DRAFT versions can be published, found status: " + version.getStatus());
        }

        // 2. Pre-publish validation — blocks if errors found
        ValidationResponse validationResult = validationService.validateForPublish(versionId);
        if (validationResult.getResult() != ValidationResponse.Result.VALID &&
                validationResult.getResult() != ValidationResponse.Result.SOURCE_MISSING) {
            throw new PublishValidationException(validationResult);
        }

        // 3. Link correction to this draft version
        version.setCorrectionId(correctionId);

        // 4. Generate diff for audit metadata
        var diff = versionDiffService.generateDiff(versionId);
        String diffSummary = String.format(
                "added=%d, removed=%d, changed=%d",
                diff.getAdded().size(),
                diff.getRemoved().size(),
                diff.getChanged().size());

        // 5. Transition DRAFT → PUBLISHED
        version.publish(publishedBy, publishNote);
        dataVersionRepository.save(version);

        // 6. Back-link Correction.resultingVersionId = publishedVersion.id
        if (correctionId != null) {
            try {
                correctionRepository.findById(correctionId).ifPresent(correction -> {
                    correction.linkToPublishedVersion(version.getId());
                    correctionRepository.save(correction);
                });
            } catch (Exception e) {
                // Back-link failure must not fail the publish transaction
                log.warn("Failed to back-link correction {} to published version {}: {}",
                        correctionId, versionId, e.getMessage());
            }
        }

        // 7. Audit log — COURSE_VERSION_PUBLISHED
        String metadataJson = String.format(
                "{\"courseId\":%d,\"versionNumber\":%d,\"publishNote\":\"%s\",\"diff\":{%s},\"correctionId\":%s}",
                version.getCourse().getId(),
                version.getVersionNumber(),
                escapeJson(publishNote),
                diffSummary,
                correctionId != null ? correctionId.toString() : "null");
        auditService.log(
                AuditAction.COURSE_VERSION_PUBLISHED,
                "DataVersion",
                versionId.toString(),
                null,
                null,
                metadataJson);

        // 8. Queue async package build (idempotent per course+version)
        UUID buildJobId = null;
        try {
            var buildJob = packageService.queueBuildForCourse(
                    version.getCourse().getId(),
                    versionId,
                    publishedBy);
            buildJobId = buildJob.getId();
        } catch (Exception e) {
            // Deliberately not rethrown: the version is published and audited
            // by this point, and unpublishing it because a downstream job could
            // not be queued would be worse than publishing without a package.
            //
            // But it is an error, not a warning. A published version with no
            // package is a course that shows a Download button and has nothing
            // behind it — and the response below carries a null buildJobId
            // precisely so the caller can say so instead of reporting success.
            log.error("Failed to queue PackageBuildJob for DataVersion {} — "
                    + "the version is published but no package will be built",
                    versionId, e);
        }

        return new PublishResponse(
                version.getId(),
                version.getVersionNumber(),
                DataVersionStatus.PUBLISHED.name(),
                null,
                buildJobId,
                version.getPublishedAt());
    }

    private static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
}
