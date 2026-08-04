package vnpt.vsp.module.course;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.audit.AuditAction;
import vnpt.vsp.module.audit.AuditService;
import vnpt.vsp.module.course.dto.CourseVersionDto;
import vnpt.vsp.module.course.dto.PageResponse;
import vnpt.vsp.module.course.dto.RollbackImpactDto;
import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;
import vnpt.vsp.module.course.repository.DataVersionRepository;
import vnpt.vsp.module.pkg.PackageService;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static net.logstash.logback.marker.Markers.append;

/**
 * Implementation of {@link CourseVersionService}.
 * Per Story 8.4: rollback creates a new published version rather than deleting history.
 */
@Service
@CourseModule
public class CourseVersionServiceImpl implements CourseVersionService {

    private static final Logger log = LoggerFactory.getLogger(CourseVersionServiceImpl.class);

    private final DataVersionRepository dataVersionRepository;
    private final PackageService packageService;
    private final AuditService auditService;

    public CourseVersionServiceImpl(
            DataVersionRepository dataVersionRepository,
            PackageService packageService,
            AuditService auditService) {
        this.dataVersionRepository = dataVersionRepository;
        this.packageService = packageService;
        this.auditService = auditService;
    }

    @Override
    public PageResponse<CourseVersionDto> listVersions(Long courseId, int page, int size) {
        List<DataVersion> allVersions = dataVersionRepository.findByCourseIdOrderByVersionNumberDesc(courseId);
        int totalElements = allVersions.size();
        int totalPages = (int) Math.ceil((double) totalElements / size);

        int start = page * size;
        int end = Math.min(start + size, totalElements);
        List<CourseVersionDto> pageContent = start < totalElements
                ? allVersions.subList(start, end).stream()
                        .map(CourseVersionDto::fromEntity)
                        .toList()
                : List.of();

        return new PageResponse<>(pageContent, page, size, totalElements, totalPages);
    }

    @Override
    public CourseVersionDto getVersion(Long courseId, Long versionId) {
        DataVersion dv = dataVersionRepository.findById(versionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.DATA_VERSION_001));

        if (!dv.getCourse().getId().equals(courseId)) {
            throw new VspApiException(VspErrorCode.DATA_VERSION_001);
        }

        return CourseVersionDto.fromEntity(dv);
    }

    @Override
    public RollbackImpactDto getRollbackImpact(Long courseId, Long targetVersionId) {
        DataVersion targetVersion = dataVersionRepository.findById(targetVersionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.DATA_VERSION_001));

        if (!targetVersion.getCourse().getId().equals(courseId)) {
            throw new VspApiException(VspErrorCode.DATA_VERSION_001);
        }

        DataVersion currentPublished = dataVersionRepository.findLatestPublishedByCourseId(courseId).orElse(null);

        return RollbackImpactDto.fromEntities(currentPublished, targetVersion);
    }

    @Override
    @Transactional
    public DataVersion rollbackToVersion(Long courseId, Long targetVersionId, String actor, String rollbackNote) {
        log.debug(append("action", "ROLLBACK_VERSION"),
                "Rollback requested: courseId={}, targetVersionId={}, actor={}",
                courseId, targetVersionId, actor);

        // 1. Find and validate target version
        DataVersion targetVersion = dataVersionRepository.findById(targetVersionId)
                .orElseThrow(() -> new VspApiException(VspErrorCode.DATA_VERSION_001));

        // Validate target belongs to the correct course
        if (!targetVersion.getCourse().getId().equals(courseId)) {
            throw new VspApiException(VspErrorCode.DATA_VERSION_001);
        }

        // Validate target is in ARCHIVED status
        if (targetVersion.getStatus() != DataVersionStatus.ARCHIVED) {
            log.warn(append("action", "ROLLBACK_REJECTED"),
                    "Rollback rejected: version {} is {}, not ARCHIVED",
                    targetVersionId, targetVersion.getStatus());
            throw new VspApiException(VspErrorCode.DATA_VERSION_002);
        }

        // 2. Find current published version (if any)
        DataVersion currentPublished = dataVersionRepository.findLatestPublishedByCourseId(courseId).orElse(null);

        // 3. Build before/after audit JSON
        String beforeJson = serializeVersionToJson(targetVersion);

        // 4. Archive current published version if it exists
        if (currentPublished != null) {
            currentPublished.archive();
            dataVersionRepository.save(currentPublished);
            log.debug(append("action", "ARCHIVE_VERSION"),
                    "Archived current published version: id={}, versionNumber={}",
                    currentPublished.getId(), currentPublished.getVersionNumber());
        }

        // 5. Re-activate target version as PUBLISHED
        targetVersion.rollbackTo(actor, rollbackNote);
        DataVersion reActivated = dataVersionRepository.save(targetVersion);

        String afterJson = serializeVersionToJson(reActivated);

        // 6. Trigger async package build
        UUID buildJobId = packageService.triggerPackageBuild(courseId, reActivated.getId(), actor);
        log.info(append("action", "PACKAGE_BUILD_TRIGGERED"),
                "Package build triggered: courseId={}, versionId={}, jobId={}",
                courseId, reActivated.getId(), buildJobId);

        // 7. Write audit record
        auditService.log(
                AuditAction.COURSE_ROLLBACK,
                "DataVersion",
                String.valueOf(reActivated.getId()),
                beforeJson,
                afterJson,
                buildMetadataJson(actor, rollbackNote, currentPublished != null ? currentPublished.getId() : null, buildJobId)
        );

        log.info(append("action", "ROLLBACK_COMPLETE"),
                "Rollback complete: courseId={}, newPublishedVersionId={}, previousVersionId={}",
                courseId, reActivated.getId(),
                currentPublished != null ? currentPublished.getId() : "none");

        return reActivated;
    }

    @Override
    public UUID triggerPackageBuild(Long courseId, Long dataVersionId, String triggeredBy) {
        return packageService.triggerPackageBuild(courseId, dataVersionId, triggeredBy);
    }

    // ─── Private helpers ───────────────────────────────────────────────────

    private String serializeVersionToJson(DataVersion dv) {
        return "{\"id\":" + dv.getId() +
                ",\"versionNumber\":" + dv.getVersionNumber() +
                ",\"status\":\"" + dv.getStatus() + "\"" +
                ",\"publishedAt\":" + (dv.getPublishedAt() != null ? "\"" + dv.getPublishedAt() + "\"" : "null") +
                ",\"publishedBy\":\"" + nullSafe(dv.getPublishedBy()) + "\"" +
                ",\"publishNote\":" + (dv.getPublishNote() != null ? "\"" + nullSafe(dv.getPublishNote()) + "\"" : "null") +
                ",\"rollbackNote\":" + (dv.getRollbackNote() != null ? "\"" + nullSafe(dv.getRollbackNote()) + "\"" : "null") +
                "}";
    }

    private String buildMetadataJson(String actor, String rollbackNote, Long archivedVersionId, UUID buildJobId) {
        return "{\"actor\":\"" + nullSafe(actor) + "\"" +
                ",\"rollbackNote\":" + (rollbackNote != null ? "\"" + nullSafe(rollbackNote) + "\"" : "null") +
                ",\"archivedVersionId\":" + (archivedVersionId != null ? archivedVersionId.toString() : "null") +
                ",\"buildJobId\":" + (buildJobId != null ? "\"" + buildJobId.toString() + "\"" : "null") +
                ",\"rolledBackAt\":\"" + Instant.now() + "\"" +
                "}";
    }

    private String nullSafe(String value) {
        return value == null ? "" : value.replace("\"", "\\\"");
    }
}
