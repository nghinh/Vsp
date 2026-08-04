package vnpt.vsp.module.course.dto;

import vnpt.vsp.module.course.entity.DataVersion;

import java.util.UUID;

/**
 * Response after a successful rollback operation.
 * Per Story 8.4 AC-3: new package generation and audit record are triggered.
 *
 * @param newJobId UUID of the triggered package build job
 * @param versionId ID of the version that is now published
 * @param versionNumber version number of the version that is now published
 */
public record RollbackResponse(
        UUID newJobId,
        Long versionId,
        Integer versionNumber
) {
    /**
     * Factory method to build response from the re-activated DataVersion and build job ID.
     */
    public static RollbackResponse fromDataVersion(DataVersion dv, UUID newJobId) {
        return new RollbackResponse(newJobId, dv.getId(), dv.getVersionNumber());
    }
}
