package vnpt.vsp.module.shot.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Request DTO for updating (editing) a shot.
 * Partial update — only non-null fields are applied.
 * Per Story 10.3 Slice 1.
 */
public record UpdateShotRequest(
        Long clubId,
        Instant endedAt,
        GeoJSONPointDto endLocation,
        ShotDto.Lie lie,
        BigDecimal distanceYards,
        BigDecimal distanceMeters,
        ConditionsDto conditions,
        ShotDto.Result result,
        Boolean isPenalty,
        Boolean isProvisional,
        Boolean isMulligan,
        BigDecimal confidence
) {}
