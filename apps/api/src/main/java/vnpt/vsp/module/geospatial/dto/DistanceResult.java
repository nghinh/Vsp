package vnpt.vsp.module.geospatial.dto;

import java.math.BigDecimal;

/**
 * Result of a distance calculation between two geometries.
 */
public class DistanceResult {

    private final BigDecimal value;
    private final String unit;
    private final boolean valid;

    public DistanceResult(BigDecimal value, String unit, boolean valid) {
        this.value = value;
        this.unit = unit;
        this.valid = valid;
    }

    public static DistanceResult invalid() {
        return new DistanceResult(null, null, false);
    }

    public static DistanceResult of(BigDecimal value, String unit) {
        return new DistanceResult(value, unit, true);
    }

    public BigDecimal getValue() {
        return value;
    }

    public String getUnit() {
        return unit;
    }

    public boolean isValid() {
        return valid;
    }
}
