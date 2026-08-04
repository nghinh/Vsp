package vnpt.vsp.module.shot.dto;

/**
 * Conditions snapshot DTO captured at shot time.
 */
public record ConditionsDto(
        Integer windDirection,
        Double windSpeed,
        Double temperature,
        Integer humidity,
        Double altitude
) {}
