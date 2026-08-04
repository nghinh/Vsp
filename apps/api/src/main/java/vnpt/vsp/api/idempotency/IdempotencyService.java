package vnpt.vsp.api.idempotency;

import java.time.Duration;

/**
 * Service interface for idempotency key storage and replay.
 * <p>
 * Implementations must be thread-safe. The in-memory implementation uses a
 * {@link java.util.concurrent.ConcurrentHashMap}; the production implementation
 * swaps to Redis with the same contract — no calling-code changes required.
 * <p>
 * Stored entries expire after {@code ttl} so the store does not grow indefinitely.
 * Expiry is the responsibility of the implementation (e.g. TTL-based Redis keys
 * or a background eviction thread in the in-memory variant).
 */
public interface IdempotencyService {

    /**
     * Checks whether the given idempotency key has already been seen.
     *
     * @param key the value of the {@code Idempotency-Key} request header
     * @return {@code true} if a response has already been cached for this key
     */
    boolean isDuplicate(String key);

    /**
     * Retrieves the cached response object for the given key, if present and not expired.
     *
     * @param key the idempotency key
     * @return the cached {@link CachedResponse}, or {@code null} if not found or expired
     */
    CachedResponse getCachedResponse(String key);

    /**
     * Caches a response for the given idempotency key with the specified time-to-live.
     *
     * @param key      the idempotency key
     * @param response the response to cache
     * @param ttl      how long the entry should remain valid
     */
    void put(String key, CachedResponse response, Duration ttl);

    /**
     * Removes the entry for the given key, if present.
     * Implementations should call this when the cached response has been replayed
     * so that stale entries do not consume memory indefinitely.
     *
     * @param key the idempotency key to evict
     */
    void evict(String key);
}
