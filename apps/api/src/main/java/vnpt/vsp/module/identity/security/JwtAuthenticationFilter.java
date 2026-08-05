package vnpt.vsp.module.identity.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.io.IOException;
import java.util.List;

/**
 * JWT authentication filter that extracts and validates JWT tokens from requests.
 * Per Architecture Section 12: short-lived access tokens, refresh-token rotation.
 * <p>
 * The authenticated principal is granted one {@code ROLE_<name>} authority per
 * assigned admin role, which is what {@code hasRole}/{@code hasAnyRole} — in
 * the URL rules and in {@code @PreAuthorize} — read. The roles are looked up
 * from the database on every request rather than carried as a JWT claim: an
 * access token lives for an hour, and a revoked admin must lose access when the
 * role is revoked, not when their token happens to expire.
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    /** Spring Security's convention: {@code hasRole('X')} tests for {@code ROLE_X}. */
    public static final String ROLE_PREFIX = "ROLE_";

    private final JwtService jwtService;
    private final RoleService roleService;

    public JwtAuthenticationFilter(JwtService jwtService, RoleService roleService) {
        this.jwtService = jwtService;
        this.roleService = roleService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String authHeader = request.getHeader(AUTHORIZATION_HEADER);

        if (authHeader == null || !authHeader.startsWith(BEARER_PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(BEARER_PREFIX.length());

        try {
            Long accountId = jwtService.validateToken(token);

            if (accountId != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                // Verify it's an access token
                if (jwtService.isAccessToken(token)) {
                    List<GrantedAuthority> authorities = authoritiesOf(accountId);

                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(
                                    accountId,
                                    null,
                                    authorities
                            );

                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);

                    log.debug("Authenticated golfer account: {} with authorities {}", accountId, authorities);
                }
            }
        } catch (Exception e) {
            log.debug("JWT authentication failed: {}", e.getMessage());
        }

        filterChain.doFilter(request, response);
    }

    /**
     * The granted authorities for an account: one {@code ROLE_<name>} per
     * assigned admin role, and none at all for an ordinary golfer.
     * <p>
     * A lookup failure yields no authorities rather than propagating: the
     * request then proceeds as an authenticated golfer and is refused by the
     * authorization rules. Failing open here would hand admin access to
     * whoever can make the role store unavailable.
     */
    private List<GrantedAuthority> authoritiesOf(Long accountId) {
        try {
            return roleService.getRoles(accountId).stream()
                    .map(RoleName::name)
                    .map(name -> (GrantedAuthority) new SimpleGrantedAuthority(ROLE_PREFIX + name))
                    .toList();
        } catch (Exception e) {
            log.error("Role lookup failed for account {} — proceeding with no roles: {}",
                    accountId, e.getMessage());
            return List.of();
        }
    }
}
