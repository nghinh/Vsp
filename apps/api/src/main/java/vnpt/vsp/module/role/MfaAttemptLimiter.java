package vnpt.vsp.module.role;

import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import vnpt.vsp.api.error.VspApiException;
import vnpt.vsp.api.error.VspErrorCode;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.Map;

import static net.logstash.logback.marker.Markers.append;

/**
 * Caps how often one account may be offered a TOTP code.
 *
 * <p>A TOTP code is six digits, and RFC 6238 verification accepts the
 * neighbouring time step as well as the current one, so at any instant roughly
 * three of a million codes are live. Unlimited guessing turns that into a few
 * minutes of scripting; the endpoint answers {@code {"valid":true|false}}, so
 * it is a clean oracle with no side effect to slow an attacker down. The
 * arithmetic is the whole control here: five attempts per fifteen minutes puts
 * an exhaustive search past any horizon worth naming, while a code that is
 * genuinely being typed by its owner never comes close to the ceiling.</p>
 *
 * <p>Only failures accumulate — a correct code clears the account's history —
 * so an admin who signs in daily is never throttled, and the counter measures
 * guessing rather than usage.</p>
 *
 * <h2>Why not a lockout</h2>
 * <p>Locking the account after N failures was the alternative and is rejected
 * on purpose. Every one of these endpoints is reachable by anyone holding an
 * access token for the account, and {@code /admin/users/{id}/mfa/verify} may be
 * called for another account by a SUPER_ADMIN, so a lockout is a control an
 * attacker triggers on demand: it converts a brute force that cannot succeed
 * into a denial of service that can, against the exact accounts — SUPER_ADMIN
 * among them — that would have to undo it. Throttling already makes the oracle
 * useless without giving anyone that switch. The refusals are counted in
 * {@value #THROTTLED_METRIC} and logged, so a sustained attack is something to
 * alert on rather than something to absorb silently.</p>
 *
 * <h2>Scope</h2>
 * <p>The state is per-process and in memory, which is the honest limit of this:
 * behind several API instances an attacker gets the ceiling once per instance.
 * That is a constant factor on an interval measured in years, and moving the
 * counters to the Redis this application already runs is a change that can be
 * made without touching a caller — the whole surface is {@link #recordFailure}
 * and {@link #recordSuccess}.</p>
 */
@Component
public class MfaAttemptLimiter {

    private static final Logger log = LoggerFactory.getLogger(MfaAttemptLimiter.class);

    /** Incremented once per refused attempt, tagged with the operation. */
    public static final String THROTTLED_METRIC = "vsp_api.mfa.attempts.throttled";

    private final int maxAttempts;
    private final Duration window;
    private final Clock clock;
    private final MeterRegistry meterRegistry;

    /**
     * Failure timestamps per account, most-recently-used last and capped, so a
     * caller who can name arbitrary account ids cannot grow this without bound.
     * Eviction can only ever forgive failures, never invent them.
     */
    private final Map<Long, Deque<Long>> failuresByAccount;

    @Autowired
    public MfaAttemptLimiter(
            @Value("${vsp.mfa.rate-limit.max-attempts:5}") int maxAttempts,
            @Value("${vsp.mfa.rate-limit.window:PT15M}") Duration window,
            @Value("${vsp.mfa.rate-limit.tracked-accounts:10000}") int trackedAccounts,
            MeterRegistry meterRegistry) {
        this(maxAttempts, window, trackedAccounts, meterRegistry, Clock.systemUTC());
    }

    MfaAttemptLimiter(int maxAttempts,
                      Duration window,
                      int trackedAccounts,
                      MeterRegistry meterRegistry,
                      Clock clock) {
        this.maxAttempts = maxAttempts;
        this.window = window;
        this.clock = clock;
        this.meterRegistry = meterRegistry;
        this.failuresByAccount = Collections.synchronizedMap(
                new LinkedHashMap<>(16, 0.75f, true) {
                    @Override
                    protected boolean removeEldestEntry(Map.Entry<Long, Deque<Long>> eldest) {
                        return size() > trackedAccounts;
                    }
                });
    }

    /**
     * Refuses the attempt when this account has already used up its budget of
     * failures. Call before doing any work on behalf of the request.
     *
     * @throws VspApiException {@link VspErrorCode#MFA_005}, rendered as 429
     */
    public void checkAllowed(Long golferAccountId, String operation) {
        if (golferAccountId == null) {
            return;
        }
        if (recentFailures(golferAccountId) < maxAttempts) {
            return;
        }

        meterRegistry.counter(THROTTLED_METRIC, "operation", operation).increment();
        log.warn(append("action", "MFA_ATTEMPTS_THROTTLED"),
                "MFA attempts throttled: golferAccountId={}, operation={}, failures>={} within {}",
                golferAccountId, operation, maxAttempts, window);

        throw new VspApiException(VspErrorCode.MFA_005,
                "Too many MFA attempts for this account. Try again in at most "
                        + window.toMinutes() + " minutes.",
                null, null);
    }

    /** Records a rejected code against the account's budget. */
    public void recordFailure(Long golferAccountId) {
        if (golferAccountId == null) {
            return;
        }
        Deque<Long> failures = failuresByAccount.computeIfAbsent(golferAccountId, id -> new ArrayDeque<>());
        synchronized (failures) {
            prune(failures);
            failures.addLast(clock.millis());
        }
    }

    /**
     * Clears the account's history. A correct code is proof the caller is not
     * guessing, so it must not leave the owner rationed for the rest of the
     * window.
     */
    public void recordSuccess(Long golferAccountId) {
        if (golferAccountId != null) {
            failuresByAccount.remove(golferAccountId);
        }
    }

    private int recentFailures(Long golferAccountId) {
        Deque<Long> failures = failuresByAccount.get(golferAccountId);
        if (failures == null) {
            return 0;
        }
        synchronized (failures) {
            prune(failures);
            return failures.size();
        }
    }

    /** Drops failures that have aged out of the window. */
    private void prune(Deque<Long> failures) {
        long cutoff = clock.millis() - window.toMillis();
        while (!failures.isEmpty() && failures.peekFirst() <= cutoff) {
            failures.removeFirst();
        }
    }
}
