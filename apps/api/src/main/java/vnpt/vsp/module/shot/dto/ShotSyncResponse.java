package vnpt.vsp.module.shot.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for shot sync confirmation.
 * Per Story 10.3 Slice 1.
 */
public record ShotSyncResponse(
        ShotDto.SyncStatus status,
        UUID eventId,
        Instant syncedAt,
        String error
) {
    public static ShotSyncResponse synced(UUID eventId) {
        return new ShotSyncResponse(ShotDto.SyncStatus.synced, eventId, Instant.now(), null);
    }

    public static ShotSyncResponse failed(UUID eventId, String error) {
        return new ShotSyncResponse(ShotDto.SyncStatus.failed, eventId, Instant.now(), error);
    }
}
