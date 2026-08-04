package vnpt.vsp.api.weather;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.weather.WeatherService;
import vnpt.vsp.module.weather.dto.*;

import java.math.BigDecimal;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link WeatherController}.
 * Tests: valid request, response headers, stale response, invalid coordinates.
 * Per Story 7.1 Wave 1: handler tests.
 */
@ExtendWith(MockitoExtension.class)
class WeatherControllerTest {

    @Mock
    private WeatherService weatherService;

    private WeatherController controller;

    @BeforeEach
    void setUp() {
        controller = new WeatherController(weatherService);
    }

    // ─── Happy path ───────────────────────────────────────────────────────────

    @Test
    void getWeather_validCoords_returns200WithHeaders() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto snapshot = createSnapshot(lat, lng);
        snapshot.setResponseSource("mock");
        snapshot.setCachedAt(Instant.now());
        snapshot.setFreshUntil(Instant.now().plusSeconds(1800));
        snapshot.setStale(false);
        when(weatherService.getWeather(lat, lng)).thenReturn(snapshot);

        // When
        ResponseEntity<WeatherSnapshotDto> response = controller.getWeather(lat, lng);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals("mock", response.getBody().getProvider());

        HttpHeaders headers = response.getHeaders();
        assertEquals("mock", headers.getFirst("X-Weather-Source"));
        assertEquals("false", headers.getFirst("X-Weather-Stale"));
        assertNotNull(headers.getFirst("X-Weather-Cached-At"));
        assertNotNull(headers.getFirst("X-Weather-Fresh-Until"));
        assertTrue(headers.getFirst("Cache-Control").contains("max-age=1800"));
    }

    @Test
    void getWeather_freshResponse_noCachedAtHeader() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto snapshot = createSnapshot(lat, lng);
        snapshot.setResponseSource("mock");
        snapshot.setCachedAt(null); // fresh from provider
        snapshot.setFreshUntil(Instant.now().plusSeconds(1800));
        snapshot.setStale(false);
        when(weatherService.getWeather(lat, lng)).thenReturn(snapshot);

        // When
        ResponseEntity<WeatherSnapshotDto> response = controller.getWeather(lat, lng);

        // Then
        HttpHeaders headers = response.getHeaders();
        assertNull(headers.getFirst("X-Weather-Cached-At")); // not set when fresh
        assertEquals("false", headers.getFirst("X-Weather-Stale"));
    }

    @Test
    void getWeather_staleCache_returnsStaleHeader() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto snapshot = createSnapshot(lat, lng);
        snapshot.setResponseSource("mock (stale)");
        snapshot.setCachedAt(Instant.now().minusSeconds(3600));
        snapshot.setFreshUntil(Instant.now().minusSeconds(60));
        snapshot.setStale(true);
        when(weatherService.getWeather(lat, lng)).thenReturn(snapshot);

        // When
        ResponseEntity<WeatherSnapshotDto> response = controller.getWeather(lat, lng);

        // Then
        assertEquals(200, response.getStatusCode().value());
        assertTrue(response.getHeaders().getFirst("X-Weather-Stale").equals("true"));
    }

    // ─── Error handling ───────────────────────────────────────────────────────

    @Test
    void getWeather_nullLat_throwsValidationException() {
        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getWeather(null, 106.629));
        assertEquals(VspErrorCode.VALIDATION_002, ex.getErrorCode());
        assertEquals("lat or lng", ex.getField());
    }

    @Test
    void getWeather_serviceThrowsException_propagatesUp() {
        // Given
        when(weatherService.getWeather(anyDouble(), anyDouble()))
                .thenThrow(new VspApiException(VspErrorCode.WEATHER_001));

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> controller.getWeather(10.823, 106.629));
        assertEquals(VspErrorCode.WEATHER_001, ex.getErrorCode());
    }

    // ─── Response source fallback ─────────────────────────────────────────────

    @Test
    void getWeather_noResponseSource_usesProviderName() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto snapshot = createSnapshot(lat, lng);
        snapshot.setResponseSource(null); // not set
        snapshot.setProvider("mock");
        snapshot.setStale(false);
        when(weatherService.getWeather(lat, lng)).thenReturn(snapshot);

        // When
        ResponseEntity<WeatherSnapshotDto> response = controller.getWeather(lat, lng);

        // Then
        assertEquals("mock", response.getHeaders().getFirst("X-Weather-Source"));
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private WeatherSnapshotDto createSnapshot(double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();
        dto.setId("mock:" + lat + ":" + lng + ":test");
        dto.setProvider("mock");
        dto.setLocation(new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng)));
        dto.setCapturedAt(Instant.now());
        dto.setExpiresAt(Instant.now().plusSeconds(1800));
        dto.setCondition("sunny");
        dto.setTemperature(new TemperatureDto(28.5, "C"));
        dto.setHumidity(75);
        dto.setWind(new WindDataDto(15.0, "kmh", "SE", 135, 22.0));
        dto.setSourceName("Mock Provider");
        dto.setAccuracyClass("C");
        dto.setConfidence(0.7);
        dto.setVerificationStatus("estimated");
        return dto;
    }
}
