package vnpt.vsp.module.identity.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
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
 * security chain. Redis holds the shared, cross-instance count; when Redis is
 * unreachable the filter does <em>not</em> throw the door open — it falls back
 * to a per-instance in-memory limiter so a Redis outage cannot silently turn
 * off brute-force protection. The fallback is per-process rather than shared,
 * so a multi-instance deployment allows up to {@code max} attempts per instance
 * during an outage; that is looser than the Redis path but far tighter than
 * unlimited, and it keeps sign-in working. The window and ceiling are
 * configurable via {@code vsp.auth.rate-limit.*}.
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

    /**
     * Caps the in-memory fallback map so a flood of distinct client IPs during
     * a Redis outage cannot grow it without bound. Past this many live windows
     * the fallback stops adding new keys and lets those requests through —
     * memory safety wins over a perfect cap in the doubly-degraded case of a
     * Redis outage and a source-address flood at once.
     */
    private static final int FALLBACK_MAX_KEYS = 100_000;

    private final RedisTemplate<String, Object> redisTemplate;
    private final int maxRequests;
    private final Duration window;

    /** Per-instance fallback counters, keyed like the Redis key; used only when Redis fails. */
    private final Map<String, FallbackWindow> fallbackCounters = new ConcurrentHashMap<>();

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

        boolean overLimit;
        try {
            Long count = redisTemplate.opsForValue().increment(key);
            if (count != null && count == 1L) {
                redisTemplate.expire(key, window);
            }
            overLimit = count != null && count > maxRequests;
        } catch (Exception e) {
            // Redis is down — degrade to the per-instance limiter rather than
            // removing the cap. Sign-in keeps working; brute-force stays capped.
            log.warn("Auth rate-limit falling back to in-memory counter (Redis unavailable): {}", e.getMessage());
            overLimit = fallbackOverLimit(key);
        }

        if (overLimit) {
            response.setStatus(429);
            response.setHeader("Retry-After", String.valueOf(window.toSeconds()));
            response.setContentType("application/json");
            response.getWriter().write(
                    "{\"code\":\"VSP-ERR-RATE-001\",\"message\":\"Too many requests. Please try again later.\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Per-instance fixed-window count for one key, used only while Redis is
     * unavailable. Returns true once this key has exceeded {@code maxRequests}
     * within the current window. Expired windows are reset in place, and the
     * map is pruned of stale entries when it grows past {@link #FALLBACK_MAX_KEYS}.
     */
    private boolean fallbackOverLimit(String key) {
        long nowMs = System.currentTimeMillis();
        long windowMs = window.toMillis();

        if (fallbackCounters.size() > FALLBACK_MAX_KEYS) {
            fallbackCounters.values().removeIf(w -> w.isExpired(nowMs, windowMs));
            if (fallbackCounters.size() > FALLBACK_MAX_KEYS) {
                return false; // still full of live windows — let it through rather than grow unbounded
            }
        }

        FallbackWindow w = fallbackCounters.computeIfAbsent(key, k -> new FallbackWindow(nowMs));
        long count = w.incrementFor(nowMs, windowMs);
        return count > maxRequests;
    }

    /** A single client's fixed-window counter for the in-memory fallback. */
    private static final class FallbackWindow {
        private volatile long windowStartMs;
        private final AtomicLong count;

        FallbackWindow(long nowMs) {
            this.windowStartMs = nowMs;
            this.count = new AtomicLong(0);
        }

        synchronized long incrementFor(long nowMs, long windowMs) {
            if (nowMs - windowStartMs >= windowMs) {
                windowStartMs = nowMs;
                count.set(0);
            }
            return count.incrementAndGet();
        }

        boolean isExpired(long nowMs, long windowMs) {
            return nowMs - windowStartMs >= windowMs;
        }
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
