package vnpt.vsp.module.shot.dto;

/**
 * A single detection signal contributing to a shot-detection confidence score.
 *
 * <p>Per Story 10.4: detection combines sensor, GPS, movement, time, and hole
 * context signals. Signals are computed on-device; the API stores them as
 * provenance for the resulting detected shot.
 *
 * @param signalType one of {@code gps}, {@code accelerometer}, {@code gyroscope},
 *                   {@code time}, {@code holeContext}
 * @param value      normalized signal value in [0.0, 1.0]
 * @param weight     weight applied to this signal in the fusion, in [0.0, 1.0]
 */
public record ShotSignalDto(
        String signalType,
        Double value,
        Double weight
) {}
