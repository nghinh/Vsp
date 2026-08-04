package vnpt.vsp.module.weather.dto;

/**
 * Temperature DTO with unit.
 */
public class TemperatureDto {

    private Double value;
    private String unit; // C or F

    public TemperatureDto() {}

    public TemperatureDto(Double value, String unit) {
        this.value = value;
        this.unit = unit;
    }

    public Double getValue() {
        return value;
    }

    public void setValue(Double value) {
        this.value = value;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }
}
