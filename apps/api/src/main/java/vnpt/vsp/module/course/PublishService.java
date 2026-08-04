package vnpt.vsp.module.course;

import vnpt.vsp.module.course.dto.PublishResponse;

/**
 * Publish service for course data versions.
 *
 * Orchestrates pre-publish validation, immutable version creation, audit logging,
 * and async package build job dispatch.
 *
 * Per Story 8.3 AC-1, AC-2, AC-3.
 */
public interface PublishService {

    /**
     * Publish a draft DataVersion.
     *
     * Steps:
     * 1. Validate the version — blocks publish if validation fails with errors
     * 2. Transition DataVersion status DRAFT → PUBLISHED
     * 3. Write audit log entry (AuditAction.COURSE_VERSION_PUBLISHED)
     * 4. Queue async PackageBuildJob for the published version
     *
     * @param versionId    the DataVersion to publish
     * @param publishNote the administrator's publish note (required, min 10 chars)
     * @param publishedBy  the username of the publishing administrator
     * @return PublishResponse with new version metadata, audit ID, and build job ID
     * @throws vnpt.vsp.module.course.PublishService.PublishValidationException
     *         if validation fails with blocking errors
     */
    PublishResponse publishVersion(Long versionId, String publishNote, String publishedBy);

    /**
     * Publish a draft DataVersion that originated from an approved correction.
     * <p>
     * This overload extends the base {@link #publishVersion(Long, String, String)} with
     * correction lineage tracking. After the DRAFT → PUBLISHED transition, it back-links
     * the published version ID to the originating {@code CourseCorrection} via
     * {@code CourseCorrection.linkToPublishedVersion(Long)}.
     *
     * Steps:
     * <ol>
     *   <li>Validate the version — blocks publish if validation fails with errors</li>
     *   <li>Set {@code DataVersion.correctionId = correctionId}</li>
     *   <li>Transition DataVersion status DRAFT → PUBLISHED</li>
     *   <li>Write audit log entry (AuditAction.COURSE_VERSION_PUBLISHED)</li>
     *   <li>Back-link {@code Correction.resultingVersionId = version.id}</li>
     *   <li>Queue async PackageBuildJob for the published version</li>
     * </ol>
     *
     * @param versionId     the DataVersion to publish
     * @param correctionId the ID of the CourseCorrection that originated this draft
     * @param publishNote  the administrator's publish note (required, min 10 chars)
     * @param publishedBy  the username of the publishing administrator
     * @return PublishResponse with new version metadata, audit ID, and build job ID
     * @throws PublishValidationException if validation fails with blocking errors
     */
    PublishResponse publishVersion(Long versionId, Long correctionId, String publishNote, String publishedBy);

    /**
     * Thrown when validation fails with blocking errors and the version cannot be published.
     */
    class PublishValidationException extends RuntimeException {
        private final vnpt.vsp.module.course.dto.ValidationResponse validationResponse;

        public PublishValidationException(vnpt.vsp.module.course.dto.ValidationResponse validationResponse) {
            super("Validation failed: " + validationResponse.getResult());
            this.validationResponse = validationResponse;
        }

        public vnpt.vsp.module.course.dto.ValidationResponse getValidationResponse() {
            return validationResponse;
        }
    }
}
