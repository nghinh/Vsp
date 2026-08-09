package vnpt.vsp.module.course.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /courses/{courseId}/versions/{versionId}/publish.
 *
 * <p>The publish note is required and has a floor on its length because it is
 * what the audit trail carries: "why was this version published" has to be
 * answerable years later from the audit record alone. {@code PublishService}
 * enforces the same minimum, so this is the client-facing half of a rule that
 * already existed.</p>
 *
 * @param publishNote  the administrator's reason for publishing
 * @param forcePublish publish despite non-blocking warnings; blocking errors
 *                     still refuse regardless
 */
public record PublishVersionRequest(
        @NotBlank(message = "publishNote is required")
        @Size(min = 10, message = "publishNote must be at least 10 characters")
        String publishNote,

        boolean forcePublish) {
}
