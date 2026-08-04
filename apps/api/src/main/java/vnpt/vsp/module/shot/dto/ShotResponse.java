package vnpt.vsp.module.shot.dto;

import java.util.UUID;

/**
 * Response DTO for a single shot mutation (create/update/delete/merge).
 * Per Story 10.3 Slice 1.
 */
public record ShotResponse(
        ShotDto shot,
        UUID eventId,
        java.time.Instant syncedAt
) {
    public static ShotResponse of(ShotDto shot, UUID eventId) {
        return new ShotResponse(shot, eventId, java.time.Instant.now());
    }
}
