package vnpt.vsp.module.identity.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Fixed-window rate limiter for the unauthenticated credential-entry endpoints
 * under {@code /auth/**}. Brute-forcing a password or a 6-digit OTP, and SMS
 * bombing through OTP send, were all unthrottled — {@code MfaAttemptLimiter}
 * only covers admin TOTP. This caps attempts per client IP per endpoint.
 *
 * <p>It is a standalone {@code @Component} filter so it adds no coupling to the
 * security chain, and it <em>fails open</em>: if Redis is unreachable the
 * request proceeds rather than locking everyone out of sign-in. The window and
 * ceiling are configurable via {@code vsp.auth.rate-limit.*}.
 */
@Component
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(AuthRateLimitFilter.class);

    /** Only the unauthenticated credential-testing entry points are limited. */
    private static final Set<String> LIMITED_PATHS = Set.of(
            "/auth/login",
            "/auth/otp/send",
            "/auth/otp/verify",
            "/auth/password/recover",
            "/auth/password/reset",
            "/auth/register/phone",
            "/auth/register/email",
            "/auth/google",
            "/auth/apple");

    private final RedisTemplate<String, Object> redisTemplate;
    private final int maxRequests;
    private final Duration window;

    public AuthRateLimitFilter(
            RedisTemplate<String, Object> redisTemplate,
            @Value("${vsp.auth.rate-limit.max:20}") int maxRequests,
            @Value("${vsp.auth.rate-limit.window-seconds:60}") long windowSeconds) {
        this.redisTemplate = redisTemplate;
        this.maxRequests = maxRequests;
        this.window = Duration.ofSeconds(windowSeconds);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !("POST".equalsIgnoreCase(request.getMethod())
                && LIMITED_PATHS.contains(request.getRequestURI()));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String key = "authrl:" + request.getRequestURI() + ":" + clientIp(request);
        try {
            Long count = redisTemplate.opsForValue().increment(key);
            if (count != null && count == 1L) {
                redisTemplate.expire(key, window);
            }
            if (count != null && count > maxRequests) {
                response.setStatus(429);
                response.setHeader("Retry-After", String.valueOf(window.toSeconds()));
                response.setContentType("application/json");
                response.getWriter().write(
                        "{\"code\":\"VSP-ERR-RATE-001\",\"message\":\"Too many requests. Please try again later.\"}");
                return;
            }
        } catch (Exception e) {
            // Fail open: never let a Redis hiccup block authentication.
            log.warn("Auth rate-limit check skipped (Redis unavailable): {}", e.getMessage());
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Behind Cloudflare Tunnel the origin's remote address is the tunnel itself,
     * so the real client is in {@code CF-Connecting-IP} (set by Cloudflare) with
     * {@code X-Forwarded-For} as the fallback.
     */
    private String clientIp(HttpServletRequest request) {
        String cf = request.getHeader("CF-Connecting-IP");
        if (cf != null && !cf.isBlank()) {
            return cf.trim();
        }
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
