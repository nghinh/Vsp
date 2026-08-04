package vnpt.vsp.config;

import org.springframework.context.annotation.Configuration;

/**
 * JPA repository configuration for the data quality module.
 *
 * <p>Scoped to {@code vnpt.vsp.module.dataquality} to avoid expanding the
 * main application's {@code @EntityScan} (which is restricted to
 * {@code vnpt.vsp.module.identity.entity} for backward compatibility).</p>
 *
 * <p>Note: {@code allowBeanDefinitionOverriding=true} is set in the builder
 * to handle the pre-existing {@code scoreRepository} bean name conflict
 * between {@code module.round} and {@code module.score} packages.</p>
 */
@Configuration
public class DataQualityJpaConfig {
}
