package vnpt.vsp.module.weather.provider;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import vnpt.vsp.module.weather.dto.*;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * OpenWeatherMap API provider implementation.
 * API docs: https://openweathermap.org/api
 */
@Component
@ConditionalOnProperty(name = "weather.provider", havingValue = "openweathermap")
public class OpenWeatherMapProvider implements WeatherProvider {

    private static final Logger log = LoggerFactory.getLogger(OpenWeatherMapProvider.class);

    private final RestTemplate restTemplate;
    private final String apiKey;
    private final String baseUrl;

    public OpenWeatherMapProvider(
            RestTemplate restTemplate,
            @Value("${weather.openweathermap.api-key:}") String apiKey,
            @Value("${weather.openweathermap.base-url:https://api.openweathermap.org/data/2.5}") String baseUrl) {
        this.restTemplate = restTemplate;
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
    }

    @Override
    public String name() {
        return "openweathermap";
    }

    @Override
    public WeatherSnapshotDto fetch(double lat, double lng) throws WeatherProviderException {
        try {
            String url = String.format("%s/weather?lat=%f&lon=%f&appid=%s&units=metric", baseUrl, lat, lng, apiKey);
            log.debug("Fetching weather from OpenWeatherMap: {}", url.replace(apiKey, "***"));

            JsonNode root = restTemplate.getForObject(url, JsonNode.class);
            if (root == null) {
                throw new WeatherProviderException(name(), "Empty response from OpenWeatherMap");
            }

            return parseResponse(root, lat, lng);
        } catch (RestClientException e) {
            log.error("OpenWeatherMap fetch failed for lat={}, lng={}", lat, lng, e);
            throw new WeatherProviderException(name(), "OpenWeatherMap API call failed: " + e.getMessage(), e);
        }
    }

    private WeatherSnapshotDto parseResponse(JsonNode root, double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();
        dto.setId("openweathermap:" + lat + ":" + lng + ":" + root.path("dt").asText());
        dto.setProvider("openweathermap");

        LocationDto location = new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng));
        dto.setLocation(location);

        long dt = root.path("dt").asLong();
        Instant capturedAt = Instant.ofEpochSecond(dt);
        dto.setCapturedAt(capturedAt);
        dto.setExpiresAt(capturedAt.plusSeconds(1800)); // 30 min TTL
        dto.setForecast(false);

        // Main temp
        JsonNode main = root.path("main");
        if (!main.isMissingNode()) {
            double temp = main.path("temp").asDouble();
            dto.setTemperature(new TemperatureDto(Math.round(temp * 10) / 10.0, "C"));
            dto.setHumidity(main.path("humidity").asInt());
            dto.setFeelsLike(main.path("feels_like").asDouble());
            dto.setPressure(new PressureDto(main.path("pressure").asDouble(), "hPa"));
        }

        // Condition
        JsonNode weather = root.path("weather");
        if (weather.isArray() && !weather.isEmpty()) {
            dto.setCondition(normalizeCondition(weather.get(0).path("main").asText().toLowerCase()));
        }

        // Wind
        JsonNode windNode = root.path("wind");
        if (!windNode.isMissingNode()) {
            WindDataDto wind = new WindDataDto();
            wind.setSpeed(windNode.path("speed").asDouble());
            wind.setUnit("ms"); // OpenWeatherMap default m/s
            int degrees = windNode.path("deg").asInt(0);
            wind.setDegrees(degrees);
            wind.setDirection(degreesToCompass(degrees));
            wind.setGusts(windNode.path("gust").asDouble(Double.NaN));
            dto.setWind(wind);
        }

        // Visibility
        int visibility = root.path("visibility").asInt(10000);
        dto.setVisibility(new VisibilityDto(visibility / 1000.0, "km"));

        // Source metadata
        dto.setSourceName("OpenWeatherMap");
        dto.setSourceTimestamp(capturedAt.toString());
        dto.setAccuracyClass("B");
        dto.setConfidence(0.85);
        dto.setVerificationStatus("official");

        return dto;
    }

    private String normalizeCondition(String owmCondition) {
        // Map OpenWeatherMap conditions to our enum
        return switch (owmCondition) {
            case "clear" -> "sunny";
            case "clouds", "few clouds", "scattered clouds", "broken clouds" -> "cloudy";
            case "drizzle", "light intensity drizzle" -> "light_rain";
            case "rain", "moderate rain" -> "rain";
            case "heavy intensity rain", "heavy rain" -> "heavy_rain";
            case "thunderstorm" -> "thunderstorm";
            case "mist", "haze", "smoke", "fog" -> "fog";
            default -> "partly_cloudy";
        };
    }

    private String degreesToCompass(int degrees) {
        String[] directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"};
        int index = (int) Math.round(degrees / 45.0) % 8;
        return directions[index];
    }
}
