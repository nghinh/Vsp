package vnpt.vsp.module.course.dto;

import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;

import java.time.Instant;

/**
 * DTO for course version information returned by the version API.
 * Per Story 8.4 AC-1: authorized user can view version metadata.
 *
 * @param id version ID
 * @param versionNumber monotonically increasing version number
 * @param status DRAFT | PUBLISHED | ARCHIVED
 * @param publishedAt when this version was published (null if never published)
 * @param publishedBy who published this version
 * @param publishNote optional note recorded at publish time
 * @param rollbackNote optional note recorded when this version was re-activated via rollback
 * @param createdAt when this version record was created
 */
public record CourseVersionDto(
        Long id,
        Integer versionNumber,
        DataVersionStatus status,
        Instant publishedAt,
        String publishedBy,
        String publishNote,
        String rollbackNote,
        Instant createdAt
) {
    /**
     * Factory method to create a DTO from a DataVersion entity.
     */
    public static CourseVersionDto fromEntity(DataVersion dv) {
        return new CourseVersionDto(
                dv.getId(),
                dv.getVersionNumber(),
                dv.getStatus(),
                dv.getPublishedAt(),
                dv.getPublishedBy(),
                dv.getPublishNote(),
                dv.getRollbackNote(),
                dv.getMetadata() != null ? dv.getMetadata().getCreatedAt() : null
        );
    }
}
