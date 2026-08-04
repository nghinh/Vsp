package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Request body for POST /admin/courses/{courseId}/versions/{versionId}/publish.
 * Per Story 8.3 AC-2 and AC-3.
 *
 * @param publishNote required reason/note for publishing (min 10 chars)
 * @param forcePublish if true, bypasses validation warnings (not validation errors); defaults to false
 */
public record PublishRequest(
        @NotBlank(message = "publishNote is required")
        @Size(min = 10, message = "publishNote must be at least 10 characters")
        String publishNote,

        boolean forcePublish
) {}
