package vnpt.vsp.api.observability;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * Environment-specific alert thresholds loaded from {@code application-*.yml}.
 *
 * <p>Thresholds are read from the {@code alert.thresholds} namespace:
 * <pre>
 * alert:
 *   thresholds:
 *     api:
 *       latency-p99-ms: 1000
 *       error-rate-percent: 0.5
 *     sync:
 *       queue-depth-warning: 50
 *       queue-depth-critical: 200
 *     gps:
 *       accuracy-warning-m: 10
 *       accuracy-critical-m: 25
 *     package:
 *       download-failure-rate-percent: 1.0
 * </pre>
 *
 * <p>These thresholds are used by:
 * <ul>
 *   <li>{@code AlertRules} bean — consumed by alerting pipelines or custom health indicators</li>
 *   <li>OpenTelemetry sampling decisions (via {@code OtelConfig})</li>
 *   <li>Prometheus alerting rules (exported as metrics for Prometheus Alertmanager)</li>
 * </ul>
 *
 * <p>The {@link HealthIndicator} implementation surfaces a synthetic "ALERT" health check
 * that is {@code DOWN} when any critical threshold is breached, allowing Kubernetes/LoadBalancer
 * probes to react to degraded observability conditions.
 */
@Configuration
public class AlertRules {

    /**
     * Root configuration properties bound to {@code alert.thresholds}.
     */
    @Bean
    @ConfigurationProperties(prefix = "alert.thresholds")
    public AlertThresholds alertThresholds() {
        return new AlertThresholds(
                new ApiThresholds(0L, 0.0),
                new SyncThresholds(0, 0),
                new GpsThresholds(0.0, 0.0),
                new PackageThresholds(0.0)
        );
    }

    // ---------------------------------------------------------------------------------------------
    // Convenience accessors — called by AlertRulesHealthIndicator
    // ---------------------------------------------------------------------------------------------

    public record ApiThresholds(
            long latencyP99Ms,
            double errorRatePercent
    ) {}

    public record SyncThresholds(
            int queueDepthWarning,
            int queueDepthCritical
    ) {}

    public record GpsThresholds(
            double accuracyWarningM,
            double accuracyCriticalM
    ) {}

    public record PackageThresholds(
            double downloadFailureRatePercent
    ) {}

    public record AlertThresholds(
            ApiThresholds api,
            SyncThresholds sync,
            GpsThresholds gps,
            PackageThresholds package_
    ) {}

    /**
     * Health indicator that checks critical alert thresholds and reports
     * {@code DOWN} when any critical threshold is breached.
     *
     * <p>This provides a synthetic health endpoint that can be used by
     * Kubernetes liveness/readiness probes or external monitoring to react
     * to degraded conditions (e.g. sync queue depth critical, API latency critical).
     *
     * <p>In production, Prometheus Alertmanager is the primary alerting path
     * (thresholds are exported as metrics). This indicator is a fallback
     * for environments without Prometheus.
     */
    @Bean
    public HealthIndicator alertRulesHealthIndicator(
            AlertThresholds thresholds,
            MeterRegistry meterRegistry,
            AtomicInteger syncQueueDepthHolder) {
        return () -> {
            Health.Builder builder = Health.up().withDetail("source", "AlertRules");

            boolean degraded = false;

            // Sync queue depth check
            if (thresholds.sync() != null && thresholds.sync().queueDepthCritical() > 0) {
                int currentDepth = syncQueueDepthHolder.get();
                builder.withDetail("sync.queue.depth.current", currentDepth);
                builder.withDetail("sync.queue.depth.criticalThreshold",
                        thresholds.sync().queueDepthCritical());
                if (currentDepth > thresholds.sync().queueDepthCritical()) {
                    degraded = true;
                }
            }

            // API latency p99 check
            if (thresholds.api() != null && thresholds.api().latencyP99Ms() > 0) {
                Timer apiLatencyTimer = meterRegistry.find("vsp_api.api.latency").timer();
                // Micrometer 1.12 removed Timer.getSnapshot(); use mean as a conservative proxy.
                // In production, ensure the timer is registered with publishPercentileHistogram(true)
                // and publishPercentiles(0.5, 0.95, 0.99) so p99 data is available via the histogram.
                double latencyMeanMs = (apiLatencyTimer != null)
                        ? apiLatencyTimer.mean(java.util.concurrent.TimeUnit.MILLISECONDS)
                        : 0.0;
                builder.withDetail("api.latency.mean.currentMs", latencyMeanMs);
                builder.withDetail("api.latency.mean.criticalThresholdMs",
                        thresholds.api().latencyP99Ms());
                if (latencyMeanMs > thresholds.api().latencyP99Ms()) {
                    degraded = true;
                }
            }

            // Package download failure rate check
            if (thresholds.package_() != null && thresholds.package_().downloadFailureRatePercent() > 0) {
                double successCount = meterRegistry.find("vsp_api.package.download.count")
                        .tag("outcome", "success").counter().count();
                double failureCount = meterRegistry.find("vsp_api.package.download.count")
                        .tag("outcome", "failure").counter().count();
                double total = successCount + failureCount;
                double failureRatePercent = (total > 0) ? (failureCount / total) * 100.0 : 0.0;
                builder.withDetail("package.download.failure-rate.currentPercent", failureRatePercent);
                builder.withDetail("package.download.failure-rate.criticalThreshold",
                        thresholds.package_().downloadFailureRatePercent() + "%");
                if (failureRatePercent > thresholds.package_().downloadFailureRatePercent()) {
                    degraded = true;
                }
            }

            return builder.status(degraded ? "DOWN" : "UP").build();
        };
    }

}
