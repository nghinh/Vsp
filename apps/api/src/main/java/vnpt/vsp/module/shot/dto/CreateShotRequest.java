package vnpt.vsp.module.shot.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Request DTO for creating (starting) a new shot.
 * Per Story 10.3 Slice 1.
 */
public record CreateShotRequest(
        Integer holeNumber,
        Integer shotNumber,
        UUID playerId,
        Long clubId,
        Instant startedAt,
        GeoJSONPointDto startLocation,
        ConditionsDto conditions
) {}
