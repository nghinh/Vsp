package vnpt.vsp.module.weather.dto;

/**
 * Pressure DTO with unit.
 */
public class PressureDto {

    private Double value;
    private String unit; // hPa

    public PressureDto() {}

    public PressureDto(Double value, String unit) {
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
