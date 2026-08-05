package vnpt.vsp.module.shot.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Request DTO for an automatic shot-detection candidate.
 *
 * <p>Per Story 10.4: Detect Shots with Confidence. The mobile client runs the
 * multi-signal sensor fusion and posts the resulting candidate with its
 * confidence score; the API applies the threshold policy to decide the
 * disposition and, when appropriate, persists a {@code detected} shot.
 */
public record ShotDetectionRequest(
        @NotNull Integer holeNumber,
        @NotNull Integer shotNumber,
        UUID clubId,
        Instant detectedAt,
        GeoJSONPointDto location,
        ConditionsDto conditions,
        @NotNull
        @DecimalMin(value = "0.0", message = "confidence must be >= 0.0")
        @DecimalMax(value = "1.0", message = "confidence must be <= 1.0")
        BigDecimal confidence,
        List<ShotSignalDto> signals
) {}
