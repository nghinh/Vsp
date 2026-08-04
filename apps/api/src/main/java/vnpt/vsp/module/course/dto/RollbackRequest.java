package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request body for POST /courses/{courseId}/versions/{versionId}/rollback.
 * Per Story 8.4 AC-2: rollback creates a new version rather than deleting history.
 *
 * @param rollbackNote required reason for the rollback
 */
public record RollbackRequest(
        @NotBlank(message = "rollbackNote is required")
        String rollbackNote
) {}
