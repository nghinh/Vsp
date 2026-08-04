package vnpt.vsp.module.payment.infrastructure.idempotency;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import vnpt.vsp.module.payment.domain.models.IdempotencyRecordEntity;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Optional;

/**
 * Payment-specific idempotency store backed by PostgreSQL.
 *
 * Complements the generic InMemoryIdempotencyService/Redis with persistent storage
 * for payment operations where durability matters.
 *
 * Uses SHA-256 hash of request body to detect conflicting requests with the same
 * idempotency key but different parameters.
 */
@Component
public class PaymentIdempotencyStore {

    private static final Logger log = LoggerFactory.getLogger(PaymentIdempotencyStore.class);
    private static final Duration DEFAULT_TTL = Duration.ofHours(24);

    @PersistenceContext
    private EntityManager em;

    /**
     * Checks whether the given idempotency key exists and is not expired.
     *
     * @param key         the idempotency key
     * @param requestBody the request body to hash and store
     * @param endpoint    the endpoint for record tracking
     * @return empty if key is new or expired; record if key is valid and matches
     */
    public Optional<IdempotencyRecordEntity> findValid(String key, String requestBody, String endpoint) {
        var query = em.createQuery(
                "SELECT i FROM IdempotencyRecordEntity i WHERE i.key = :key",
                IdempotencyRecordEntity.class);
        query.setParameter("key", key);
        return query.getResultStream()
                .filter(r -> !r.isExpired())
                .filter(r -> r.getRequestHash().equals(hash(requestBody)))
                .findFirst();
    }

    /**
     * Stores an idempotency record.
     *
     * @param key          the idempotency key
     * @param endpoint     the endpoint
     * @param requestBody  the request body
     * @param responseCode  the HTTP response code
     * @param responseBody the serialized response body
     * @param ttl          time-to-live
     */
    public void put(String key, String endpoint, String requestBody,
                    int responseCode, String responseBody, Duration ttl) {
        var record = new IdempotencyRecordEntity(
                key,
                endpoint,
                hash(requestBody),
                responseCode,
                responseBody,
                OffsetDateTime.now().plus(ttl)
        );
        em.merge(record);
        log.debug("Stored idempotency record: key={}, expiresIn={}", key, ttl);
    }

    /**
     * Removes an idempotency record.
     */
    public void evict(String key) {
        var record = em.find(IdempotencyRecordEntity.class, key);
        if (record != null) {
            em.remove(record);
        }
    }

    /**
     * Cleans up expired idempotency records.
     */
    public int cleanupExpired() {
        var query = em.createQuery(
                "DELETE FROM IdempotencyRecordEntity i WHERE i.expiresAt < :now",
                IdempotencyRecordEntity.class);
        query.setParameter("now", OffsetDateTime.now());
        return query.executeUpdate();
    }

    private String hash(String input) {
        try {
            var md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            var sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }
}
