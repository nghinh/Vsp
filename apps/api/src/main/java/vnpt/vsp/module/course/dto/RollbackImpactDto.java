package vnpt.vsp.module.course.dto;

import vnpt.vsp.module.course.entity.DataVersion;
import vnpt.vsp.module.course.entity.DataVersionStatus;

/**
 * DTO describing the impact of a rollback operation — what would change.
 * Per Story 8.4 AC-1: shows which version would be rolled back to and
 * which version is currently published (the one being replaced).
 *
 * @param currentVersion the currently published version (to be archived), or null if none
 * @param targetVersion the archived version that would be re-activated
 * @param changesSummary human-readable summary of what changes on rollback
 */
public record RollbackImpactDto(
        CourseVersionDto currentVersion,
        CourseVersionDto targetVersion,
        String changesSummary
) {
    /**
     * Factory to build impact DTO from two DataVersion entities.
     */
    public static RollbackImpactDto fromEntities(DataVersion current, DataVersion target) {
        String summary;
        if (current == null) {
            summary = String.format(
                    "No currently published version. Rolling back to v%d (%s) will make it the published version.",
                    target.getVersionNumber(),
                    target.getStatus()
            );
        } else {
            summary = String.format(
                    "Current published version v%d (%s) will be archived. Version v%d (%s) will be re-activated as published.",
                    current.getVersionNumber(), current.getStatus(),
                    target.getVersionNumber(), target.getStatus()
            );
        }
        return new RollbackImpactDto(
                current != null ? CourseVersionDto.fromEntity(current) : null,
                CourseVersionDto.fromEntity(target),
                summary
        );
    }
}
