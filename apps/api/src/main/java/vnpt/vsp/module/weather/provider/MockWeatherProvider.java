package vnpt.vsp.module.weather.provider;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import vnpt.vsp.module.weather.dto.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Mock weather provider for local development and testing.
 * Returns synthetic but realistic weather data based on coordinates.
 */
@Component
@ConditionalOnProperty(name = "weather.provider", havingValue = "mock", matchIfMissing = true)
public class MockWeatherProvider implements WeatherProvider {

    @Override
    public String name() {
        return "mock";
    }

    @Override
    public WeatherSnapshotDto fetch(double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();
        dto.setId(generateId(lat, lng));
        dto.setProvider("mock");
        dto.setLocation(new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng)));
        dto.setCapturedAt(Instant.now());
        dto.setExpiresAt(Instant.now().plusSeconds(1800)); // 30 min TTL
        dto.setForecast(false);

        // Synthetic temperature based on latitude (simple model: hotter near equator)
        double baseTemp = 30.0 - Math.abs(lat - 10) * 0.5;
        double temp = baseTemp + ThreadLocalRandom.current().nextDouble(-3, 3);
        dto.setTemperature(new TemperatureDto(Math.round(temp * 10) / 10.0, "C"));

        // Synthetic humidity
        dto.setHumidity(ThreadLocalRandom.current().nextInt(50, 90));

        // Synthetic condition
        String[] conditions = {"sunny", "partly_cloudy", "cloudy", "windy"};
        dto.setCondition(conditions[ThreadLocalRandom.current().nextInt(conditions.length)]);

        // Synthetic wind
        WindDataDto wind = new WindDataDto();
        wind.setSpeed(ThreadLocalRandom.current().nextDouble(5, 25));
        wind.setUnit("kmh");
        String[] directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"};
        wind.setDirection(directions[ThreadLocalRandom.current().nextInt(directions.length)]);
        wind.setDegrees(ThreadLocalRandom.current().nextInt(0, 360));
        wind.setGusts(ThreadLocalRandom.current().nextDouble(10, 35));
        dto.setWind(wind);

        dto.setVisibility(new VisibilityDto(10.0, "km"));
        dto.setPressure(new PressureDto(1013.25, "hPa"));
        dto.setFeelsLike(temp + 2);
        dto.setPrecipitationProbability(ThreadLocalRandom.current().nextInt(0, 40));
        dto.setUvIndex(ThreadLocalRandom.current().nextInt(0, 11));

        // Source metadata
        dto.setSourceName("Mock Provider");
        dto.setSourceTimestamp(Instant.now().toString());
        dto.setAccuracyClass("C");
        dto.setConfidence(0.7);
        dto.setVerificationStatus("estimated");

        return dto;
    }

    private String generateId(double lat, double lng) {
        // Millisecond-resolution timestamp so each fetch yields a distinct snapshot id
        // (the cache layer handles time-bucketing separately via WeatherCacheService).
        return String.format("mock:%.3f:%.3f:%d", lat, lng, System.currentTimeMillis());
    }
}
