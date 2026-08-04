package vnpt.vsp.module.weather;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import vnpt.vsp.module.weather.cache.WeatherCacheService;
import vnpt.vsp.module.weather.dto.*;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link WeatherCacheService}.
 * Tests: cache key generation (3 decimal places), TTL behavior, stale cache retrieval.
 * Per Story 7.1 Wave 1: unit tests for cache key generation, TTL logic.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class WeatherCacheServiceTest {

    @Mock
    private RedisTemplate<String, Object> redisTemplate;

    @Mock
    private ValueOperations<String, Object> valueOperations;

    private WeatherCacheService cacheService;
    private CircuitBreakerRegistry circuitBreakerRegistry;

    @BeforeEach
    void setUp() {
        circuitBreakerRegistry = CircuitBreakerRegistry.ofDefaults();
        cacheService = new WeatherCacheService(redisTemplate, circuitBreakerRegistry);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
    }

    // ─── Cache key generation ─────────────────────────────────────────────────

    @Test
    void cacheKey_roundsTo3DecimalPlaces() {
        // Vietnam coordinates (e.g., Ho Chi Minh City area)
        assertEquals("weather:10.823:106.629", cacheService.cacheKey(10.8231, 106.6294));
        assertEquals("weather:10.824:106.630", cacheService.cacheKey(10.8235, 106.6299));
        assertEquals("weather:10.823:106.630", cacheService.cacheKey(10.8234, 106.62999));
        // Edge cases
        assertEquals("weather:-90.000:180.000", cacheService.cacheKey(-90.0, 180.0));
        assertEquals("weather:0.000:0.000", cacheService.cacheKey(0.0, 0.0));
    }

    @Test
    void cacheKey_handlesNegativeCoordinates() {
        assertEquals("weather:-33.869:-151.209", cacheService.cacheKey(-33.8689, -151.2093));
    }

    // ─── TTL ─────────────────────────────────────────────────────────────────

    @Test
    void getDefaultTtl_returns30Minutes() {
        assertEquals(Duration.ofMinutes(30), cacheService.getDefaultTtl());
    }

    // ─── Cache get ───────────────────────────────────────────────────────────

    @Test
    void get_returnsCachedWeather_whenCacheHit() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        String key = cacheService.cacheKey(lat, lng);
        WeatherSnapshotDto cached = createSnapshot(lat, lng);
        cached.setCachedAt(Instant.now());
        cached.setFreshUntil(Instant.now().plusSeconds(1800));
        when(valueOperations.get(key)).thenReturn(cached);

        // When
        var result = cacheService.get(lat, lng);

        // Then
        assertTrue(result.isPresent());
        assertFalse(result.get().stale());
        assertEquals(cached, result.get().snapshot());
    }

    @Test
    void get_returnsEmpty_whenCacheMiss() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        when(valueOperations.get(anyString())).thenReturn(null);

        // When
        var result = cacheService.get(lat, lng);

        // Then
        assertTrue(result.isEmpty());
    }

    @Test
    void get_marksStale_whenFreshUntilIsPast() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        String key = cacheService.cacheKey(lat, lng);
        WeatherSnapshotDto cached = createSnapshot(lat, lng);
        cached.setCachedAt(Instant.now().minusSeconds(3600));
        cached.setFreshUntil(Instant.now().minusSeconds(60)); // expired
        when(valueOperations.get(key)).thenReturn(cached);

        // When
        var result = cacheService.get(lat, lng);

        // Then
        assertTrue(result.isPresent());
        assertTrue(result.get().stale());
    }

    @Test
    void get_returnsEmpty_whenRedisThrows() {
        // Given
        when(valueOperations.get(anyString())).thenThrow(new RuntimeException("Redis down"));

        // When
        var result = cacheService.get(10.823, 106.629);

        // Then — graceful degradation, returns empty
        assertTrue(result.isEmpty());
    }

    // ─── Cache put ────────────────────────────────────────────────────────────

    @Test
    void put_storesSnapshotWithTTL() {
        // Given
        WeatherSnapshotDto snapshot = createSnapshot(10.823, 106.629);

        // When
        cacheService.put(snapshot);

        // Then
        verify(valueOperations).set(
                eq("weather:10.823:106.629"),
                eq(snapshot),
                eq(Duration.ofMinutes(30))
        );
    }

    @Test
    void put_setsCachedAtAndFreshUntil() {
        // Given
        WeatherSnapshotDto snapshot = createSnapshot(10.823, 106.629);
        assertNull(snapshot.getCachedAt()); // before put

        // When
        cacheService.put(snapshot);

        // Then
        assertNotNull(snapshot.getCachedAt());
        assertNotNull(snapshot.getFreshUntil());
        assertTrue(snapshot.getFreshUntil().isAfter(snapshot.getCachedAt()));
    }

    @Test
    void put_gracefullyHandlesRedisFailure() {
        // Given
        WeatherSnapshotDto snapshot = createSnapshot(10.823, 106.629);
        doThrow(new RuntimeException("Redis down"))
                .when(valueOperations).set(anyString(), any(), any(Duration.class));

        // When / Then — no exception thrown
        assertDoesNotThrow(() -> cacheService.put(snapshot));
    }

    // ─── Stale cache ─────────────────────────────────────────────────────────

    @Test
    void getStaleCache_returnsSnapshot_whenAvailable() {
        // Given
        double lat = 10.823;
        double lng = 106.629;
        WeatherSnapshotDto stale = createSnapshot(lat, lng);
        when(valueOperations.get(cacheService.cacheKey(lat, lng))).thenReturn(stale);

        // When
        var result = cacheService.getStaleCache(lat, lng);

        // Then
        assertTrue(result.isPresent());
        assertEquals(stale, result.get());
    }

    @Test
    void getStaleCache_returnsEmpty_whenNoStaleData() {
        // Given
        when(valueOperations.get(anyString())).thenReturn(null);

        // When
        var result = cacheService.getStaleCache(10.823, 106.629);

        // Then
        assertTrue(result.isEmpty());
    }

    // ─── Helper ──────────────────────────────────────────────────────────────

    private WeatherSnapshotDto createSnapshot(double lat, double lng) {
        WeatherSnapshotDto dto = new WeatherSnapshotDto();
        dto.setId("mock:" + lat + ":" + lng + ":test");
        dto.setProvider("mock");
        dto.setLocation(new LocationDto(BigDecimal.valueOf(lat), BigDecimal.valueOf(lng)));
        dto.setCapturedAt(Instant.now());
        dto.setExpiresAt(Instant.now().plus(Duration.ofMinutes(30)));
        dto.setCondition("sunny");
        dto.setTemperature(new TemperatureDto(28.5, "C"));
        return dto;
    }
}
