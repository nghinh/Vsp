package vnpt.vsp.module.weather.cache;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import vnpt.vsp.module.weather.dto.LocationDto;
import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.function.Supplier;

/**
 * Redis-based weather cache with TTL and circuit breaker.
 * Key pattern: weather:{lat_rounded}:{lng_rounded} (3 decimal places ≈ 100m grid).
 * TTL: 30 minutes default.
 * Circuit breaker: if provider fails 3x in 5min, return stale cached data.
 * Per Story 7.1 Wave 1: Redis Cache.
 */
@Service
public class WeatherCacheService {

    private static final Logger log = LoggerFactory.getLogger(WeatherCacheService.class);

    private static final String CACHE_KEY_PREFIX = "weather:";
    private static final Duration DEFAULT_TTL = Duration.ofMinutes(30);
    private static final Duration CIRCUIT_BREAKER_WINDOW = Duration.ofMinutes(5);
    private static final int CIRCUIT_BREAKER_FAILURE_THRESHOLD = 3;

    private final RedisTemplate<String, Object> redisTemplate;
    private final CircuitBreaker circuitBreaker;

    public WeatherCacheService(RedisTemplate<String, Object> redisTemplate,
                               CircuitBreakerRegistry circuitBreakerRegistry) {
        this.redisTemplate = redisTemplate;
        this.circuitBreaker = circuitBreakerRegistry.circuitBreaker("weather-provider");
    }

    /**
     * Get a cached weather snapshot.
     *
     * @param lat latitude
     * @param lng longitude
     * @return Optional containing the cached snapshot and cached-at timestamp, or empty
     */
    public Optional<CachedWeather> get(double lat, double lng) {
        String key = cacheKey(lat, lng);
        try {
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof WeatherSnapshotDto dto) {
                Instant cachedAt = dto.getCachedAt();
                Instant freshUntil = dto.getFreshUntil();
                boolean stale = cachedAt != null && freshUntil != null
                        && Instant.now().isAfter(freshUntil);
                log.debug("Cache hit for key={}, stale={}", key, stale);
                return Optional.of(new CachedWeather(dto, cachedAt, stale));
            }
        } catch (Exception e) {
            log.warn("Redis cache get failed for key={}: {}", key, e.getMessage());
        }
        log.debug("Cache miss for key={}", key);
        return Optional.empty();
    }

    /**
     * Store a weather snapshot in Redis with TTL.
     *
     * @param snapshot the snapshot to cache
     */
    public void put(WeatherSnapshotDto snapshot) {
        String key = cacheKey(snapshot.getLocation().getLatitude().doubleValue(),
                snapshot.getLocation().getLongitude().doubleValue());
        try {
            snapshot.setCachedAt(Instant.now());
            snapshot.setFreshUntil(Instant.now().plusSeconds(DEFAULT_TTL.toSeconds()));
            redisTemplate.opsForValue().set(key, snapshot, DEFAULT_TTL);
            log.debug("Cached weather snapshot at key={}, TTL={}", key, DEFAULT_TTL);
        } catch (Exception e) {
            log.warn("Redis cache put failed for key={}: {}", key, e.getMessage());
        }
    }

    /**
     * Get a stale cached snapshot when the provider is down (circuit breaker open).
     *
     * @param lat latitude
     * @param lng longitude
     * @return Optional stale snapshot
     */
    public Optional<WeatherSnapshotDto> getStaleCache(double lat, double lng) {
        String key = cacheKey(lat, lng);
        try {
            Object cached = redisTemplate.opsForValue().get(key);
            if (cached instanceof WeatherSnapshotDto dto) {
                log.debug("Returning stale cache for key={}", key);
                return Optional.of(dto);
            }
        } catch (Exception e) {
            log.warn("Redis stale cache get failed for key={}: {}", key, e.getMessage());
        }
        return Optional.empty();
    }

    /**
     * Execute a provider fetch with circuit breaker protection.
     * On failure, records the failure and rethrows.
     *
     * @param providerName name of the provider
     * @param fallback     fallback supplier for when circuit is open (returns stale cache)
     * @param fetch        the actual fetch operation
     * @return WeatherSnapshotDto
     */
    public WeatherSnapshotDto fetchWithCircuitBreaker(String providerName,
                                                      Supplier<Optional<WeatherSnapshotDto>> fallback,
                                                      Supplier<WeatherSnapshotDto> fetch) {
        CircuitBreaker.State state = circuitBreaker.getState();
        if (state == CircuitBreaker.State.OPEN || state == CircuitBreaker.State.FORCED_OPEN) {
            log.warn("Circuit breaker OPEN for provider={}, returning stale cache", providerName);
            return fallback.get()
                    .orElseThrow(() -> new WeatherProviderCircuitOpenException(providerName,
                            "Circuit breaker open and no stale cache available"));
        }

        try {
            return circuitBreaker.executeSupplier(fetch);
        } catch (Exception e) {
            log.error("Provider {} fetch failed, circuit breaker state={}", providerName, circuitBreaker.getState());
            throw e;
        }
    }

    /**
     * Generate cache key: rounded to 3 decimal places.
     */
    public String cacheKey(double lat, double lng) {
        return CACHE_KEY_PREFIX + String.format("%.3f:%.3f", lat, lng);
    }

    /**
     * Default TTL duration.
     */
    public Duration getDefaultTtl() {
        return DEFAULT_TTL;
    }

    /**
     * Cached weather record with metadata.
     */
    public record CachedWeather(WeatherSnapshotDto snapshot, Instant cachedAt, boolean stale) {}

    /**
     * Exception thrown when circuit breaker is open and no stale cache is available.
     */
    public static class WeatherProviderCircuitOpenException extends RuntimeException {
        private final String providerName;

        public WeatherProviderCircuitOpenException(String providerName, String message) {
            super(message);
            this.providerName = providerName;
        }

        public String getProviderName() {
            return providerName;
        }
    }
}
