package vnpt.vsp.module.weather.provider;

import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;

/**
 * Interface for weather data providers.
 * Configured implementations: OpenWeatherMap, Tomorrow.io, MockWeatherProvider.
 * Per Story 7.1 Wave 1: WeatherProvider interface.
 */
public interface WeatherProvider {

    /**
     * Returns the provider's unique name identifier.
     */
    String name();

    /**
     * Fetches a weather snapshot for the given coordinates.
     *
     * @param lat latitude (WGS84)
     * @param lng longitude (WGS84)
     * @return WeatherSnapshotDto with all fields populated
     * @throws WeatherProviderException if the provider fails
     */
    WeatherSnapshotDto fetch(double lat, double lng) throws WeatherProviderException;
}
