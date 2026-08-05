package vnpt.vsp.module.identity.security;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import vnpt.vsp.module.role.RoleService;
import vnpt.vsp.module.role.entity.RoleName;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * What a bearer token turns into.
 *
 * <p>The filter used to build every principal with {@code Collections.emptyList()}
 * authorities, which is why {@code hasRole} could never have matched for anyone:
 * the roles existed in the database and nothing ever put them in the security
 * context. These tests pin the mapping, and pin that a role store that is down
 * produces a golfer rather than an admin.</p>
 */
@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock private JwtService jwtService;
    @Mock private RoleService roleService;
    @Mock private FilterChain filterChain;

    private JwtAuthenticationFilter filter;
    private MockHttpServletRequest request;
    private MockHttpServletResponse response;

    private static final Long ACCOUNT_ID = 42L;
    private static final String TOKEN = "a.valid.token";

    @BeforeEach
    void setUp() {
        filter = new JwtAuthenticationFilter(jwtService, roleService);
        request = new MockHttpServletRequest();
        response = new MockHttpServletResponse();
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void withValidToken() {
        request.addHeader("Authorization", "Bearer " + TOKEN);
        when(jwtService.validateToken(TOKEN)).thenReturn(ACCOUNT_ID);
        when(jwtService.isAccessToken(TOKEN)).thenReturn(true);
    }

    private List<String> authorities() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(authentication, "the request was not authenticated");
        return authentication.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList();
    }

    @Test
    @DisplayName("Assigned roles become ROLE_-prefixed authorities, which is what hasRole reads")
    void assignedRolesBecomeAuthorities() throws Exception {
        withValidToken();
        when(roleService.getRoles(ACCOUNT_ID))
                .thenReturn(Set.of(RoleName.COURSE_ADMIN, RoleName.GREENKEEPER));

        filter.doFilter(request, response, filterChain);

        assertEquals(ACCOUNT_ID, SecurityContextHolder.getContext().getAuthentication().getPrincipal());
        assertTrue(authorities().containsAll(List.of("ROLE_COURSE_ADMIN", "ROLE_GREENKEEPER")));
        assertEquals(2, authorities().size());
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("A golfer with no admin roles is authenticated with no authorities")
    void golferGetsNoAuthorities() throws Exception {
        withValidToken();
        when(roleService.getRoles(ACCOUNT_ID)).thenReturn(Set.of());

        filter.doFilter(request, response, filterChain);

        assertEquals(ACCOUNT_ID, SecurityContextHolder.getContext().getAuthentication().getPrincipal());
        assertTrue(authorities().isEmpty());
    }

    @Test
    @DisplayName("A role store that fails yields a golfer, not an admin")
    void roleLookupFailureFailsClosed() throws Exception {
        withValidToken();
        when(roleService.getRoles(ACCOUNT_ID)).thenThrow(new IllegalStateException("database down"));

        filter.doFilter(request, response, filterChain);

        assertTrue(authorities().isEmpty(),
                "a failed role lookup must not grant any role");
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("No Authorization header leaves the context anonymous and costs no role lookup")
    void noHeaderIsAnonymous() throws Exception {
        filter.doFilter(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(roleService, never()).getRoles(any());
        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("A refresh token does not authenticate, however many roles its subject holds")
    void refreshTokenDoesNotAuthenticate() throws Exception {
        request.addHeader("Authorization", "Bearer " + TOKEN);
        when(jwtService.validateToken(TOKEN)).thenReturn(ACCOUNT_ID);
        when(jwtService.isAccessToken(TOKEN)).thenReturn(false);

        filter.doFilter(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(roleService, never()).getRoles(any());
    }
}
