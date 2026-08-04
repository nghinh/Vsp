package vnpt.vsp.module.weather;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;
import vnpt.vsp.module.weather.cache.WeatherCacheService;
import vnpt.vsp.module.weather.dto.WeatherSnapshotDto;
import vnpt.vsp.module.weather.provider.WeatherProvider;
import vnpt.vsp.module.weather.provider.WeatherProviderException;

import java.util.List;
import java.util.Optional;

/**
 * Implementation of {@link WeatherService}.
 * Orchestrates cache + provider with circuit breaker.
 * Records telemetry: provider call latency, cache hit/miss.
 * Per Story 7.1 Wave 1: Service + Repository.
 */
@Service
@WeatherModule
public class WeatherServiceImpl implements WeatherService {

    private static final Logger log = LoggerFactory.getLogger(WeatherServiceImpl.class);

    private final List<WeatherProvider> providers;
    private final WeatherCacheService cacheService;
    private final Counter cacheHitCounter;
    private final Counter cacheMissCounter;
    private final Counter providerFailureCounter;
    private final Timer providerLatencyTimer;

    public WeatherServiceImpl(List<WeatherProvider> providers,
                              WeatherCacheService cacheService,
                              MeterRegistry meterRegistry) {
        this.providers = providers;
        this.cacheService = cacheService;

        this.cacheHitCounter = Counter.builder("weather.cache.hits")
                .description("Weather cache hits")
                .register(meterRegistry);
        this.cacheMissCounter = Counter.builder("weather.cache.misses")
                .description("Weather cache misses")
                .register(meterRegistry);
        this.providerFailureCounter = Counter.builder("weather.provider.failures")
                .description("Weather provider failures")
                .register(meterRegistry);
        this.providerLatencyTimer = Timer.builder("weather.provider.latency")
                .description("Weather provider call latency")
                .publishPercentiles(0.5, 0.90, 0.95, 0.99)
                .register(meterRegistry);
    }

    @Override
    public WeatherSnapshotDto getWeather(double lat, double lng) {
        // 1. Check cache first
        Optional<WeatherCacheService.CachedWeather> cached = cacheService.get(lat, lng);
        if (cached.isPresent()) {
            WeatherCacheService.CachedWeather cachedWeather = cached.get();
            cacheHitCounter.increment();
            WeatherSnapshotDto dto = cachedWeather.snapshot();
            dto.setStale(cachedWeather.stale());
            log.debug("Cache hit for lat={}, lng={}, stale={}", lat, lng, cachedWeather.stale());
            return dto;
        }

        cacheMissCounter.increment();

        // 2. Cache miss — call provider with circuit breaker
        WeatherProvider provider = selectProvider();
        String providerName = provider.name();

        try {
            WeatherSnapshotDto result = cacheService.fetchWithCircuitBreaker(
                    providerName,
                    () -> cacheService.getStaleCache(lat, lng),
                    () -> fetchFromProvider(provider, lat, lng)
            );

            // 3. Store in cache
            cacheService.put(result);

            // 4. Set response metadata
            result.setResponseSource(providerName);
            result.setCachedAt(null); // fresh from provider
            result.setFreshUntil(result.getExpiresAt());
            result.setStale(false);

            log.info("Fetched fresh weather from provider={}, lat={}, lng={}", providerName, lat, lng);
            return result;

        } catch (WeatherCacheService.WeatherProviderCircuitOpenException e) {
            // Circuit open and no stale cache — return what we can
            providerFailureCounter.increment();
            log.error("Circuit breaker open for provider={}, lat={}, lng={}", providerName, lat, lng);
            Optional<WeatherSnapshotDto> stale = cacheService.getStaleCache(lat, lng);
            if (stale.isPresent()) {
                WeatherSnapshotDto dto = stale.get();
                dto.setStale(true);
                dto.setResponseSource(providerName + " (stale)");
                return dto;
            }
            throw new VspApiException(VspErrorCode.WEATHER_004);
        } catch (WeatherProviderException e) {
            providerFailureCounter.increment();
            log.error("Provider {} failed for lat={}, lng={}", providerName, lat, lng, e);
            // Try stale cache
            Optional<WeatherSnapshotDto> stale = cacheService.getStaleCache(lat, lng);
            if (stale.isPresent()) {
                WeatherSnapshotDto dto = stale.get();
                dto.setStale(true);
                dto.setResponseSource(providerName + " (stale)");
                return dto;
            }
            throw new VspApiException(VspErrorCode.WEATHER_001);
        }
    }

    private WeatherSnapshotDto fetchFromProvider(WeatherProvider provider, double lat, double lng) {
        return providerLatencyTimer.record(() -> {
            try {
                return provider.fetch(lat, lng);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        });
    }

    /**
     * Select the first available provider.
     * Could be extended to support provider fallback chains.
     */
    private WeatherProvider selectProvider() {
        if (providers.isEmpty()) {
            throw new VspApiException(VspErrorCode.INTERNAL_001, "No weather provider configured");
        }
        return providers.get(0);
    }
}
