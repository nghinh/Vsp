package vnpt.vsp.module.weather.dto;

/**
 * Wind data DTO.
 * Per Story 7.1 AC-1 and PRD §8.9.
 */
public class WindDataDto {

    private Double speed;
    private String unit;          // kmh, mph, ms, knots
    private String direction;     // N, NE, E, SE, S, SW, W, NW
    private Integer degrees;      // 0-360
    private Double gusts;

    public WindDataDto() {}

    public WindDataDto(Double speed, String unit, String direction, Integer degrees, Double gusts) {
        this.speed = speed;
        this.unit = unit;
        this.direction = direction;
        this.degrees = degrees;
        this.gusts = gusts;
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Double getSpeed() {
        return speed;
    }

    public void setSpeed(Double speed) {
        this.speed = speed;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public String getDirection() {
        return direction;
    }

    public void setDirection(String direction) {
        this.direction = direction;
    }

    public Integer getDegrees() {
        return degrees;
    }

    public void setDegrees(Integer degrees) {
        this.degrees = degrees;
    }

    public Double getGusts() {
        return gusts;
    }

    public void setGusts(Double gusts) {
        this.gusts = gusts;
    }
}
