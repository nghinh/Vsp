package vnpt.vsp.api.admin;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Spring Security configuration for admin REST endpoints.
 * Per Story 8.1 AC-1: only COURSE_ADMIN and SUPER_ADMIN may access /admin/** endpoints.
 * Uses method-level @PreAuthorize as fallback enforcement.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class AdminSecurityConfig {

    @Bean
    public SecurityFilterChain adminSecurityFilterChain(HttpSecurity http) throws Exception {
        http
                .securityMatcher("/admin/**")
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // All admin endpoints require authentication
                        .requestMatchers("/admin/**").authenticated()
                        .anyRequest().authenticated()
                );

        return http.build();
    }
}
