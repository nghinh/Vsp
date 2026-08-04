package vnpt.vsp.module.weather;

import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;

/**
 * Weather module public service interface.
 * Exposes weather snapshots and provider integration operations.
 * Per Story 7.1 Wave 1: orchestrates cache + provider.
 * No module may directly @Autowired an Impl from another module — only this interface.
 */
public interface WeatherService {

    /**
     * Get a weather snapshot for the given coordinates.
     * Checks cache first; on miss, calls the configured provider.
     * On provider failure with circuit breaker open, returns stale cached data if available.
     *
     * @param lat latitude (WGS84)
     * @param lng longitude (WGS84)
     * @return WeatherSnapshotDto with cache metadata in transient fields
     */
    WeatherSnapshotDto getWeather(double lat, double lng);
}
