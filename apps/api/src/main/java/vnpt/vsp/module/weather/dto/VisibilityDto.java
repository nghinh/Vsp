package vnpt.vsp.module.weather.dto;

/**
 * Visibility DTO with unit.
 */
public class VisibilityDto {

    private Double value;
    private String unit; // km

    public VisibilityDto() {}

    public VisibilityDto(Double value, String unit) {
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
