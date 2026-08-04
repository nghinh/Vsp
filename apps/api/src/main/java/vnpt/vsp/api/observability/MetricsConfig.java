package vnpt.vsp.api.observability;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * Micrometer custom meters for VSP API observability.
 *
 * <p>Registers the following custom meters aligned with the observability architecture
 * (§13) and slice plan OBS-1:
 * <ul>
 *   <li>{@code vsp_api.sync.queue.depth} — current depth of the sync event queue</li>
 *   <li>{@code vsp_api.api.latency} — timer for API endpoint latency</li>
 *   <li>{@code vsp_api.gps.quality} — counter for GPS accuracy quality buckets (good/warn/critical)</li>
 *   <li>{@code vsp_api.package.download.count} — counter for package download outcomes (success/failure)</li>
 * </ul>
 *
 * <p>All meters carry the tag {@code application=${spring.application.name}} set in
 * {@code application.yml} so prometheus scraping can filter by environment.
 */
@Configuration
public class MetricsConfig {

    // --- Sync queue depth (gauge backed by AtomicInteger) ---

    private final AtomicInteger syncQueueDepth = new AtomicInteger(0);

    @Bean
    public AtomicInteger syncQueueDepthHolder() {
        return syncQueueDepth;
    }

    @Bean
    public Gauge syncQueueDepthGauge(MeterRegistry registry) {
        return Gauge.builder("vsp_api.sync.queue.depth", syncQueueDepth, AtomicInteger::get)
                .description("Current depth of the sync event queue")
                .register(registry);
    }

    // --- API latency timer (used as a static convenience reference) ---

    @Bean
    public Timer apiLatencyTimer(MeterRegistry registry) {
        return Timer.builder("vsp_api.api.latency")
                .description("API endpoint round-trip latency")
                .publishPercentiles(0.5, 0.90, 0.95, 0.99)
                .publishPercentileHistogram()
                .register(registry);
    }

    // --- GPS quality counters (good / warn / critical accuracy buckets) ---

    @Bean
    public Counter gpsQualityGood(MeterRegistry registry) {
        return Counter.builder("vsp_api.gps.quality")
                .tag("bucket", "good")
                .description("GPS accuracy within acceptable threshold")
                .register(registry);
    }

    @Bean
    public Counter gpsQualityWarn(MeterRegistry registry) {
        return Counter.builder("vsp_api.gps.quality")
                .tag("bucket", "warn")
                .description("GPS accuracy degraded but usable")
                .register(registry);
    }

    @Bean
    public Counter gpsQualityCritical(MeterRegistry registry) {
        return Counter.builder("vsp_api.gps.quality")
                .tag("bucket", "critical")
                .description("GPS accuracy insufficient — distance values unreliable")
                .register(registry);
    }

    // --- Package download counters ---

    @Bean
    public Counter packageDownloadSuccess(MeterRegistry registry) {
        return Counter.builder("vsp_api.package.download.count")
                .tag("outcome", "success")
                .description("Successful course package downloads")
                .register(registry);
    }

    @Bean
    public Counter packageDownloadFailure(MeterRegistry registry) {
        return Counter.builder("vsp_api.package.download.count")
                .tag("outcome", "failure")
                .description("Failed course package downloads")
                .register(registry);
    }

}
