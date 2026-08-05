package vnpt.vsp.api.admin;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import vnpt.vsp.api.error.SecurityErrorResponder;
import vnpt.vsp.module.identity.security.JwtAuthenticationFilter;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.Arrays;

/**
 * Spring Security configuration for admin REST endpoints.
 * Per Story 8.1 AC-1: only COURSE_ADMIN and SUPER_ADMIN may access /admin/** endpoints.
 * <p>
 * This chain has its own {@code securityMatcher} and therefore matches before
 * the application-wide chain in {@code SecurityConfig}. It must carry the JWT
 * filter itself: a chain does not inherit the other chain's filters, and
 * without it every admin request arrives anonymous and is refused whatever
 * token it carried.
 * <p>
 * The URL rule requires <em>some</em> admin role, and {@code @PreAuthorize} on
 * each handler requires the specific one. The URL rule is not redundant: it is
 * the floor that decides what a controller with no annotation gets, and the
 * answer has to be "refused" rather than "whatever any signed-in golfer asks
 * for". Several {@code /admin/**} controllers had no annotation at all.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class AdminSecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final SecurityErrorResponder securityErrorResponder;

    public AdminSecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter,
                               SecurityErrorResponder securityErrorResponder) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.securityErrorResponder = securityErrorResponder;
    }

    /**
     * Every defined role, derived from the enum so a role added later is
     * admitted to the admin surface without anyone remembering to edit a list
     * here — the per-endpoint annotations still decide what it may do.
     */
    static String[] adminRoles() {
        return Arrays.stream(RoleName.values()).map(Enum::name).toArray(String[]::new);
    }

    @Bean
    public SecurityFilterChain adminSecurityFilterChain(HttpSecurity http) throws Exception {
        http
                .securityMatcher("/admin/**")
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .anyRequest().hasAnyRole(adminRoles())
                )
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(securityErrorResponder)
                        .accessDeniedHandler(securityErrorResponder)
                )
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
