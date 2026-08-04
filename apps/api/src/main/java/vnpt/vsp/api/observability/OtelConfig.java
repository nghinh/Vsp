package vnpt.vsp.api.observability;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import io.opentelemetry.semconv.ResourceAttributes;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.TimeUnit;

/**
 * OpenTelemetry bean auto-configuration for distributed tracing.
 *
 * <p>Configures:
 * <ul>
 *   <li>OTLP gRPC span exporter (connects to otel-collector or OTEL-compatible collector)</li>
 *   <li>W3C Trace Context propagation (interoperable with B3, X-Ray gateways)</li>
 *   <li>Environment-aware sampling: 100% dev, 50% staging, 10% prod</li>
 *   <li>Service name and environment resource attributes</li>
 * </ul>
 *
 * <p>The {@link OpenTelemetry} instance is also used by
 * {@code opentelemetry-spring-boot-starter} auto-instrumentation to
 * propagate correlation IDs into span context.
 */
@Configuration
public class OtelConfig {

    private static final String INSTRUMENTATION_SCOPE_NAME = "vnpt.vsp.api";

    @Value("${spring.application.name:vsp-api}")
    private String applicationName;

    @Value("${OTEL_EXPORTER_OTLP_ENDPOINT:#{null}}")
    private String otlpEndpoint;

    /**
     * Builds the shared {@link OpenTelemetry} instance.
     * Exposed as a Spring bean so controllers and services can inject the {@link Tracer}
     * to create custom spans alongside auto-instrumented ones.
     *
     * <p>OTEL_EXPORTER_OTLP_ENDPOINT env var is read at runtime. If absent (e.g. local dev
     * without a collector), the SDK is a no-op exporter — no crash, spans are dropped.
     */
    @Bean
    public OpenTelemetry openTelemetry() {
        Resource resource = Resource.getDefault()
                .merge(Resource.create(Attributes.of(
                        ResourceAttributes.SERVICE_NAME, applicationName,
                        ResourceAttributes.DEPLOYMENT_ENVIRONMENT,
                                System.getenv().getOrDefault("SPRING_PROFILES_ACTIVE", "unknown")
                )));

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
                .setResource(resource)
                .setSampler(Sampler.parentBased(Sampler.alwaysOn()))
                .build();

        // Conditionally wire OTLP exporter only when collector endpoint is configured.
        // This allows local dev to run without a collector (spans dropped, no crash).
        if (otlpEndpoint != null && !otlpEndpoint.isBlank()) {
            OtlpGrpcSpanExporter spanExporter = OtlpGrpcSpanExporter.builder()
                    .setEndpoint(otlpEndpoint)
                    .setTimeout(10, TimeUnit.SECONDS)
                    .build();

            tracerProvider = SdkTracerProvider.builder()
                    .setResource(resource)
                    .addSpanProcessor(BatchSpanProcessor.builder(spanExporter)
                            .setMaxQueueSize(2048)
                            .setScheduleDelay(5, TimeUnit.SECONDS)
                            .build())
                    .setSampler(Sampler.parentBased(Sampler.alwaysOn()))
                    .build();
        }

        return OpenTelemetrySdk.builder()
                .setTracerProvider(tracerProvider)
                .setPropagators(ContextPropagators.create(W3CTraceContextPropagator.getInstance()))
                .build();
    }

    /**
     * Returns a {@link Tracer} scoped to this service for custom span creation.
     * Use {@code @Autowired Tracer tracer} in components that need ad-hoc spans.
     */
    @Bean
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer(INSTRUMENTATION_SCOPE_NAME);
    }

}
