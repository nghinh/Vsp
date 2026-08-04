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
 * Tomorrow.io API provider implementation.
 * API docs: https://docs.tomorrow.io/
 */
@Component
@ConditionalOnProperty(name = "weather.provider", havingValue = "tomorrow_io")
public class TomorrowIoProvider implements WeatherProvider {

    private static final Logger log = LoggerFactory.getLogger(TomorrowIoProvider.class);

    private final RestTemplate restTemplate;
    private final String apiKey;
    private final String baseUrl;

    public TomorrowIoProvider(
            RestTemplate restTemplate,
            @Value("${weather.tomorrow-io.api-key:}") String apiKey,
            @Value("${weather.tomorrow-io.base-url:https://api.tomorrow.io/v4}") String baseUrl) {
        this.restTemplate = restTemplate;
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
    }

    @Override
    public String name() {
        return "tomorrow_io";
    }

    @Override
    public WeatherSnapshotDto fetch(double lat, double lng) throws WeatherProviderException {
        try {
            String url = String.format("%s/timelines?location=%f,%f&apikey=%s", baseUrl, lat, lng, apiKey);
            log.debug("Fetching weather from Tomorrow.io: {}", url.replace(apiKey, "***"));

            JsonNode root = restTemplate.getForObject(url, JsonNode.class);
            if (root == null) {
                throw new WeatherProviderException(name(), "Empty response from Tomorrow.io");
            }

            return parseResponse(root, lat, lng);
        } catch (RestClientException e) {
            log.error("Tomorrow.io fetch failed for lat={}, lng={}", lat, lng, e);
            throw new WeatherProviderException(name(), "Tomorrow.io API call failed: " + e.getMessage(), e);
        }
    }

    private WeatherSnapshotDto parseResponse(JsonNode root, double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();

        JsonNode timelines = root.path("data").path("timelines");
        if (timelines.isArray() && !timelines.isEmpty()) {
            JsonNode interval = timelines.get(0).path("intervals").get(0);
            JsonNode values = interval.path("values");

            dto.setId("tomorrow_io:" + lat + ":" + lng + ":" + interval.path("startTime").asText());
            dto.setProvider("tomorrow_io");

            LocationDto location = new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng));
            dto.setLocation(location);

            Instant capturedAt = Instant.parse(interval.path("startTime").asText());
            dto.setCapturedAt(capturedAt);
            dto.setExpiresAt(capturedAt.plusSeconds(1800));
            dto.setForecast(false);

            // Temperature
            double temp = values.path("temperature").asDouble();
            dto.setTemperature(new TemperatureDto(Math.round(temp * 10) / 10.0, "C"));
            dto.setHumidity(values.path("humidity").asInt());
            dto.setFeelsLike(values.path("temperatureApparent").asDouble());

            // Pressure
            double pressure = values.path("pressureSurfaceLevel").asDouble();
            dto.setPressure(new PressureDto(pressure, "hPa"));

            // Condition
            dto.setCondition(normalizeCondition(values.path("weatherCode").asText()));

            // Wind
            WindDataDto wind = new WindDataDto();
            wind.setSpeed(values.path("windSpeed").asDouble());
            wind.setUnit("ms");
            int degrees = values.path("windDirection").asInt(0);
            wind.setDegrees(degrees);
            wind.setDirection(degreesToCompass(degrees));
            wind.setGusts(values.path("windGust").asDouble(Double.NaN));
            dto.setWind(wind);

            // Visibility
            double visibility = values.path("visibility").asDouble();
            dto.setVisibility(new VisibilityDto(visibility / 1000.0, "km"));

            // Precipitation
            dto.setPrecipitationProbability(values.path("precipitationProbability").asInt());

            // UV Index
            dto.setUvIndex(values.path("uvIndex").asInt());

            // Source metadata
            dto.setSourceName("Tomorrow.io");
            dto.setSourceTimestamp(capturedAt.toString());
            dto.setAccuracyClass("B");
            dto.setConfidence(0.9);
            dto.setVerificationStatus("official");
        } else {
            // Fallback minimal response
            dto.setId("tomorrow_io:" + lat + ":" + lng + ":fallback");
            dto.setProvider("tomorrow_io");
            dto.setLocation(new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng)));
            dto.setCapturedAt(Instant.now());
            dto.setExpiresAt(Instant.now().plusSeconds(1800));
            dto.setCondition("unknown");
        }

        return dto;
    }

    private String normalizeCondition(String code) {
        // Tomorrow.io weather codes: https://docs.tomorrow.io/docs/weather-codes
        return switch (code) {
            case "0" -> "sunny";
            case "1", "2", "3" -> "partly_cloudy";
            case "4", "5", "6", "7", "8" -> "cloudy";
            case "9", "10", "11" -> "overcast";
            case "12", "13", "14", "15", "16", "17", "18" -> "rain";
            case "19", "20", "21", "22", "23" -> "light_rain";
            case "24", "25", "26", "27", "28", "29", "30" -> "heavy_rain";
            case "31", "32", "33", "34", "35" -> "thunderstorm";
            case "36", "37", "38", "39", "40", "41", "42" -> "fog";
            default -> "partly_cloudy";
        };
    }

    private String degreesToCompass(int degrees) {
        String[] directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"};
        int index = (int) Math.round(degrees / 45.0) % 8;
        return directions[index];
    }
}
