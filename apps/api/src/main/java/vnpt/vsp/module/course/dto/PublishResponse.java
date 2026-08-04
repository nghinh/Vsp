package vnpt.vsp.module.course.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Response after a successful publish operation.
 * Per Story 8.3 AC-3: immutable version, audit record, and package build job created.
 *
 * @param newVersionId ID of the now-published DataVersion
 * @param versionNumber version number (e.g. 3)
 * @param status PUBLISHED
 * @param auditId ID of the audit entry ( AuditAction.COURSE_VERSION_PUBLISHED)
 * @param buildJobId UUID of the triggered PackageBuildJob (may be null if async job creation failed)
 * @param publishedAt timestamp of publication
 */
public record PublishResponse(
        Long newVersionId,
        Integer versionNumber,
        String status,
        Long auditId,
        UUID buildJobId,
        Instant publishedAt
) {}
