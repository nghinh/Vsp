package vnpt.vsp.module.weather;

import org.junit.jupiter.api.Test;
import vnpt.vsp.module.weather.dto.LocationDto;
import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;
import vnpt.vsp.module.weather.provider.MockWeatherProvider;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for {@link MockWeatherProvider}.
 * Tests: provider name, data fields are populated, cache key format.
 * Per Story 7.1 Wave 1: unit tests for mock provider.
 */
class MockWeatherProviderTest {

    private final MockWeatherProvider provider = new MockWeatherProvider();

    @Test
    void name_returnsMock() {
        assertEquals("mock", provider.name());
    }

    @Test
    void fetch_returnsValidSnapshot() {
        // Given
        double lat = 10.823;
        double lng = 106.629;

        // When
        WeatherSnapshotDto snapshot = provider.fetch(lat, lng);

        // Then
        assertNotNull(snapshot);
        assertEquals("mock", snapshot.getProvider());
        assertNotNull(snapshot.getId());
        assertTrue(snapshot.getId().startsWith("mock:"));

        // Location
        assertNotNull(snapshot.getLocation());
        assertEquals(BigDecimal.valueOf(lat), snapshot.getLocation().getLatitude());
        assertEquals(BigDecimal.valueOf(lng), snapshot.getLocation().getLongitude());

        // Timestamps
        assertNotNull(snapshot.getCapturedAt());
        assertNotNull(snapshot.getExpiresAt());
        assertTrue(snapshot.getExpiresAt().isAfter(snapshot.getCapturedAt()));

        // Temperature
        assertNotNull(snapshot.getTemperature());
        assertEquals("C", snapshot.getTemperature().getUnit());
        assertNotNull(snapshot.getTemperature().getValue());

        // Humidity
        assertNotNull(snapshot.getHumidity());
        assertTrue(snapshot.getHumidity() >= 0 && snapshot.getHumidity() <= 100);

        // Wind
        assertNotNull(snapshot.getWind());
        assertNotNull(snapshot.getWind().getSpeed());
        assertNotNull(snapshot.getWind().getDirection());
        assertNotNull(snapshot.getWind().getDegrees());
        assertTrue(snapshot.getWind().getDegrees() >= 0 && snapshot.getWind().getDegrees() <= 360);

        // Condition
        assertNotNull(snapshot.getCondition());

        // Source metadata
        assertNotNull(snapshot.getSourceName());
        assertNotNull(snapshot.getAccuracyClass());
        assertNotNull(snapshot.getConfidence());
        assertTrue(snapshot.getConfidence() >= 0.0 && snapshot.getConfidence() <= 1.0);
        assertNotNull(snapshot.getVerificationStatus());

        // Not a forecast
        assertFalse(snapshot.isForecast());
    }

    @Test
    void fetch_returnsConsistentLocationCacheKey() {
        // Given
        double lat = 10.823;
        double lng = 106.629;

        // When
        WeatherSnapshotDto snapshot = provider.fetch(lat, lng);

        // Then
        LocationDto location = snapshot.getLocation();
        assertNotNull(location);
        String cacheKey = location.toCacheKey();
        assertTrue(cacheKey.startsWith("10.823:106.629"));
    }

    @Test
    void fetch_returnsDifferentIdsForDifferentCalls() throws InterruptedException {
        // Given
        double lat = 10.823;
        double lng = 106.629;

        // When
        WeatherSnapshotDto s1 = provider.fetch(lat, lng);
        Thread.sleep(10); // ensure a different millisecond timestamp
        WeatherSnapshotDto s2 = provider.fetch(lat, lng);

        // Then — IDs differ because they include a millisecond timestamp
        assertNotEquals(s1.getId(), s2.getId());
    }
}
