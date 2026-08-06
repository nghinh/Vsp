package vnpt.vsp.module.role;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The arithmetic of the MFA throttle, on a clock the test moves itself — a
 * limiter proven by sleeping for its window is a limiter nobody will keep.
 */
class MfaAttemptLimiterTest {

    private static final int MAX_ATTEMPTS = 5;
    private static final Duration WINDOW = Duration.ofMinutes(15);
    private static final long ACCOUNT = 42L;
    private static final long OTHER_ACCOUNT = 43L;

    private MutableClock clock;
    private MeterRegistry meterRegistry;
    private MfaAttemptLimiter limiter;

    @BeforeEach
    void setUp() {
        clock = new MutableClock(Instant.parse("2026-01-01T00:00:00Z"));
        meterRegistry = new SimpleMeterRegistry();
        limiter = new MfaAttemptLimiter(MAX_ATTEMPTS, WINDOW, 1000, meterRegistry, clock);
    }

    @Test
    @DisplayName("The budget is spent, then the next attempt is refused")
    void refusesTheAttemptAfterTheBudgetIsSpent() {
        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            int number = attempt;
            assertDoesNotThrow(() -> limiter.checkAllowed(ACCOUNT, "verify"),
                    "attempt " + (number + 1) + " is within the budget of " + MAX_ATTEMPTS);
            limiter.recordFailure(ACCOUNT);
        }

        VspApiException refused = assertThrows(VspApiException.class,
                () -> limiter.checkAllowed(ACCOUNT, "verify"));

        assertEquals(VspErrorCode.MFA_005, refused.getErrorCode());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, refused.getErrorCode().getHttpStatus());
    }

    @Test
    @DisplayName("A refusal is counted so a sustained attack can be alerted on")
    void countsRefusals() {
        spendTheBudget(ACCOUNT);

        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"));
        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"));

        assertEquals(2.0, meterRegistry.counter(
                MfaAttemptLimiter.THROTTLED_METRIC, "operation", "verify").count());
    }

    @Test
    @DisplayName("One account's budget is not another's")
    void budgetsArePerAccount() {
        spendTheBudget(ACCOUNT);

        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"));
        assertDoesNotThrow(() -> limiter.checkAllowed(OTHER_ACCOUNT, "verify"));
    }

    @Test
    @DisplayName("A throttled account is served again once the window has passed")
    void theWindowExpires() {
        spendTheBudget(ACCOUNT);
        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"));

        clock.advance(WINDOW.minusSeconds(1));
        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"),
                "still inside the window");

        clock.advance(Duration.ofSeconds(2));
        assertDoesNotThrow(() -> limiter.checkAllowed(ACCOUNT, "verify"));
    }

    @Test
    @DisplayName("A correct code clears the account, so an owner is never rationed")
    void successResetsTheBudget() {
        for (int attempt = 0; attempt < MAX_ATTEMPTS - 1; attempt++) {
            limiter.recordFailure(ACCOUNT);
        }

        limiter.recordSuccess(ACCOUNT);

        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            assertDoesNotThrow(() -> limiter.checkAllowed(ACCOUNT, "verify"));
            limiter.recordFailure(ACCOUNT);
        }
        assertThrows(VspApiException.class, () -> limiter.checkAllowed(ACCOUNT, "verify"),
                "the budget starts over, it does not become unlimited");
    }

    /**
     * The map is capped, so a caller naming arbitrary account ids cannot grow
     * it without bound. Eviction forgives failures; it must never invent them,
     * which is what the assertion on the freshly-named account checks.
     */
    @Test
    @DisplayName("Tracking is bounded, and eviction can only forgive")
    void trackingIsBounded() {
        MfaAttemptLimiter small = new MfaAttemptLimiter(
                MAX_ATTEMPTS, WINDOW, 4, meterRegistry, clock);

        for (long account = 0; account < 1_000; account++) {
            small.recordFailure(account);
        }

        assertDoesNotThrow(() -> small.checkAllowed(0L, "verify"),
                "an evicted account starts clean rather than throttled");

        spendTheBudget(small, 999L);
        assertThrows(VspApiException.class, () -> small.checkAllowed(999L, "verify"),
                "the most recently seen accounts are still tracked");
    }

    @Test
    @DisplayName("The refusal says how long the caller must wait")
    void refusalNamesTheWindow() {
        spendTheBudget(ACCOUNT);

        VspApiException refused = assertThrows(VspApiException.class,
                () -> limiter.checkAllowed(ACCOUNT, "verify"));

        assertTrue(refused.getMessage().contains(String.valueOf(WINDOW.toMinutes())),
                "message should name the wait: " + refused.getMessage());
    }

    private void spendTheBudget(long account) {
        spendTheBudget(limiter, account);
    }

    private void spendTheBudget(MfaAttemptLimiter target, long account) {
        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            target.recordFailure(account);
        }
    }

    /** A clock the test winds forward, so the window is provable in milliseconds. */
    private static final class MutableClock extends Clock {
        private Instant now;

        private MutableClock(Instant start) {
            this.now = start;
        }

        void advance(Duration amount) {
            now = now.plus(amount);
        }

        @Override
        public ZoneOffset getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
