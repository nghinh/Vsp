package vnpt.vsp.module.weather;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.weather.cache.WeatherCacheService;
import vnpt.vsp.module.weather.dto.*;
import vnpt.vsp.module.weather.provider.MockWeatherProvider;
import vnpt.vsp.module.weather.provider.WeatherProviderException;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link WeatherServiceImpl}.
 * Tests: cache hit, cache miss, provider failure with stale fallback,
 * provider failure without stale cache, circuit breaker behavior.
 * Per Story 7.1 Wave 1: Unit tests for provider interface, cache, TTL logic.
 */
@ExtendWith(MockitoExtension.class)
class WeatherServiceImplTest {

    @Mock
    private WeatherCacheService cacheService;

    private MeterRegistry meterRegistry;
    private WeatherServiceImpl weatherService;
    private MockWeatherProvider mockProvider;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        mockProvider = new MockWeatherProvider();
        weatherService = new WeatherServiceImpl(List.of(mockProvider), cacheService, meterRegistry);
    }

    // ─── Cache hit tests ───────────────────────────────────────────────────────

    @Test
    void getWeather_returnsCachedSnapshot_whenCacheHit() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto cached = createMockSnapshot(lat, lng);
        cached.setCachedAt(Instant.now());
        cached.setFreshUntil(Instant.now().plusSeconds(1800));
        when(cacheService.get(lat, lng))
                .thenReturn(Optional.of(new WeatherCacheService.CachedWeather(cached, Instant.now(), false)));

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then
        assertNotNull(result);
        assertFalse(result.isStale());
        verify(cacheService, never()).fetchWithCircuitBreaker(any(), any(), any());
        // Verify cache hit counter incremented
        Counter cacheHitCounter = meterRegistry.find("weather.cache.hits").counter();
        assertNotNull(cacheHitCounter);
        assertEquals(1.0, cacheHitCounter.count());
    }

    @Test
    void getWeather_marksSnapshotStale_whenCacheIsExpired() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto cached = createMockSnapshot(lat, lng);
        cached.setCachedAt(Instant.now().minusSeconds(3600)); // 1 hour ago
        cached.setFreshUntil(Instant.now().minusSeconds(60)); // expired 1 min ago
        when(cacheService.get(lat, lng))
                .thenReturn(Optional.of(new WeatherCacheService.CachedWeather(cached, cached.getCachedAt(), true)));

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then
        assertNotNull(result);
        assertTrue(result.isStale());
    }

    // ─── Cache miss tests ─────────────────────────────────────────────────────

    @Test
    void getWeather_fetchesFromProvider_whenCacheMiss() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(cacheService.get(lat, lng)).thenReturn(Optional.empty());
        when(cacheService.fetchWithCircuitBreaker(any(), any(), any()))
                .thenAnswer(invocation -> {
                    var fetch = invocation.getArgument(2, java.util.function.Supplier.class);
                    return fetch.get();
                });
        doNothing().when(cacheService).put(any());

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then
        assertNotNull(result);
        assertEquals("mock", result.getProvider());
        assertNotNull(result.getWind());
        assertNotNull(result.getTemperature());
        verify(cacheService).put(any(WeatherSnapshotDto.class));
        // Verify cache miss counter incremented
        Counter cacheMissCounter = meterRegistry.find("weather.cache.misses").counter();
        assertNotNull(cacheMissCounter);
        assertEquals(1.0, cacheMissCounter.count());
    }

    @Test
    void getWeather_setsResponseSource_whenFreshFetch() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(cacheService.get(lat, lng)).thenReturn(Optional.empty());
        when(cacheService.fetchWithCircuitBreaker(any(), any(), any()))
                .thenAnswer(invocation -> {
                    var fetch = invocation.getArgument(2, java.util.function.Supplier.class);
                    return fetch.get();
                });

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then
        assertEquals("mock", result.getResponseSource());
        assertFalse(result.isStale());
    }

    // ─── Provider failure with stale cache ─────────────────────────────────────

    @Test
    void getWeather_returnsStaleCache_whenProviderFails_andStaleCacheExists() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(cacheService.get(lat, lng)).thenReturn(Optional.empty());
        when(cacheService.fetchWithCircuitBreaker(any(), any(), any()))
                .thenThrow(new WeatherProviderException("mock", "Provider failed"));
        WeatherSnapshotDto staleSnapshot = createMockSnapshot(lat, lng);
        when(cacheService.getStaleCache(lat, lng)).thenReturn(Optional.of(staleSnapshot));

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then
        assertNotNull(result);
        assertTrue(result.isStale());
        assertTrue(result.getResponseSource().contains("stale"));
        Counter failureCounter = meterRegistry.find("weather.provider.failures").counter();
        assertNotNull(failureCounter);
        assertEquals(1.0, failureCounter.count());
    }

    @Test
    void getWeather_throwsException_whenProviderFails_andNoStaleCache() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(cacheService.get(lat, lng)).thenReturn(Optional.empty());
        when(cacheService.fetchWithCircuitBreaker(any(), any(), any()))
                .thenThrow(new WeatherProviderException("mock", "Provider failed"));
        when(cacheService.getStaleCache(lat, lng)).thenReturn(Optional.empty());

        // When / Then
        VspApiException ex = assertThrows(VspApiException.class,
                () -> weatherService.getWeather(lat, lng));
        assertEquals(VspErrorCode.WEATHER_001, ex.getErrorCode());
    }

    // ─── Circuit breaker open with stale cache ───────────────────────────────

    @Test
    void getWeather_returnsStaleCache_whenCircuitBreakerOpen() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(cacheService.get(lat, lng)).thenReturn(Optional.empty());
        when(cacheService.fetchWithCircuitBreaker(any(), any(), any()))
                .thenThrow(new WeatherCacheService.WeatherProviderCircuitOpenException("mock", "Circuit open"));
        WeatherSnapshotDto staleSnapshot = createMockSnapshot(lat, lng);
        when(cacheService.getStaleCache(lat, lng)).thenReturn(Optional.of(staleSnapshot));

        // When
        WeatherSnapshotDto result = weatherService.getWeather(lat, lng);

        // Then — circuit open + stale cache present ⇒ return the stale snapshot
        // (no exception; WEATHER_004 is only thrown when there is no cache to fall back to).
        assertNotNull(result);
        assertTrue(result.isStale());
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private WeatherSnapshotDto createMockSnapshot(double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();
        dto.setId("mock:" + lat + ":" + lng + ":test");
        dto.setProvider("mock");
        dto.setLocation(new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng)));
        dto.setCapturedAt(Instant.now());
        dto.setExpiresAt(Instant.now().plus(Duration.ofMinutes(30)));
        dto.setForecast(false);
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
