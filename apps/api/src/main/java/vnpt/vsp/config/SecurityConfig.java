package vnpt.vsp.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpMethod;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import vnpt.vsp.api.error.SecurityErrorResponder;
import vnpt.vsp.module.identity.security.JwtAuthenticationFilter;

/**
 * Security configuration for JWT-based authentication.
 * Per Architecture Section 12: OAuth/OIDC-compatible identity, short-lived access tokens.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final SecurityErrorResponder securityErrorResponder;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter,
                          SecurityErrorResponder securityErrorResponder) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.securityErrorResponder = securityErrorResponder;
    }

    /**
     * Keeps the JWT filter out of the plain servlet filter chain.
     * <p>
     * It is a {@code @Component} extending {@code OncePerRequestFilter}, which
     * Boot otherwise registers with the servlet container as well, at the very
     * end of the chain. There it authenticates nothing useful — every security
     * decision has already been taken by then — while creating a second place
     * a reader has to reason about. The security chains add it explicitly.
     */
    @Bean
    public FilterRegistrationBean<JwtAuthenticationFilter> jwtAuthenticationFilterRegistration(
            JwtAuthenticationFilter filter) {
        FilterRegistrationBean<JwtAuthenticationFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // Disable CSRF (we use JWT, not cookies)
                .csrf(AbstractHttpConfigurer::disable)

                // Stateless session management
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // Authorization rules
                .authorizeHttpRequests(auth -> auth
                        // Public auth endpoints
                        .requestMatchers(
                                "/auth/login",
                                "/auth/register/phone",
                                "/auth/register/email",
                                "/auth/otp/send",
                                "/auth/otp/verify",
                                "/auth/password/recover",
                                "/auth/password/reset",
                                "/auth/refresh",

                                // Social sign-in. These are a way *in*, so
                                // requiring a token to reach them made them
                                // unreachable by the only caller there is: the
                                // mobile login screen has no token yet. They
                                // are safe to open only because
                                // SocialTokenValidatorService now verifies the
                                // provider's signature, audience and expiry —
                                // opening them while it read tokens without
                                // checking them would have handed anonymous
                                // callers an account-takeover endpoint.
                                "/auth/google",
                                "/auth/apple"
                        ).permitAll()

                        // Actuator endpoints
                        .requestMatchers("/actuator/**").permitAll()

                        // Course package files. These are immutable, public
                        // course data served in place of a CDN where none is
                        // configured, and the download client fetches them as
                        // plain URLs — exactly as it would from a CDN, which
                        // would not carry the app's bearer token either.
                        .requestMatchers(HttpMethod.GET, "/packages/**").permitAll()

                        // All other endpoints require authentication
                        .anyRequest().authenticated()
                )

                // Refusals from the chain itself carry the same error body as
                // every other API error, instead of an empty 403.
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(securityErrorResponder)
                        .accessDeniedHandler(securityErrorResponder)
                )

                // Add JWT filter before UsernamePasswordAuthenticationFilter
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
