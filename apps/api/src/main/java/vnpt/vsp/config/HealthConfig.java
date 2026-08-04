package vnpt.vsp.config;

import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

/**
 * Simple health indicator that reports the application itself is UP.
 * Used as a lightweight check for the liveness probe.
 */
@Component
public class HealthConfig {

    @Component
    public static class LivenessHealthIndicator implements HealthIndicator {
        @Override
        public Health health() {
            return Health.up()
                    .withDetail("application", "vsp-api")
                    .build();
        }
    }
}
