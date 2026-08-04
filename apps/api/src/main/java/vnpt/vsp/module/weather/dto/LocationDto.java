package vnpt.vsp.module.weather.dto;

import java.math.BigDecimal;

/**
 * Location DTO for weather requests.
 * Per Story 7.1 and Architecture §6.1.
 */
public class LocationDto {

    private BigDecimal latitude;
    private BigDecimal longitude;

    public LocationDto() {}

    public LocationDto(BigDecimal latitude, BigDecimal longitude) {
        this.latitude = latitude;
        this.longitude = longitude;
    }

    public BigDecimal getLatitude() {
        return latitude;
    }

    public void setLatitude(BigDecimal latitude) {
        this.latitude = latitude;
    }

    public BigDecimal getLongitude() {
        return longitude;
    }

    public void setLongitude(BigDecimal longitude) {
        this.longitude = longitude;
    }

    /**
     * Rounded cache key: 3 decimal places ≈ 100m grid.
     */
    public String toCacheKey() {
        return String.format("%.3f:%.3f", latitude, longitude);
    }
}
