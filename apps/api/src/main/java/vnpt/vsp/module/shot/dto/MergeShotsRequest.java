package vnpt.vsp.module.shot.dto;

import java.util.UUID;

/**
 * Request DTO for merging two shots.
 * Per Story 10.3 Slice 1.
 */
public record MergeShotsRequest(
        UUID sourceShotId,
        UUID targetShotId
) {}
