package vnpt.vsp.module.payment.domain.models;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/**
 * JPA entity representing a payment idempotency record.
 *
 * Provides persistent idempotency storage as a PostgreSQL backup
 * to the in-memory/Redis IdempotencyService, ensuring durability
 * across restarts.
 */
@Entity
@Table(name = "idempotency_records", indexes = {
        @Index(name = "idx_idempotency_expires", columnList = "expires_at")
})
public class IdempotencyRecordEntity {

    @Id
    @Column(length = 255)
    private String key;

    @Column(nullable = false, length = 100)
    private String endpoint;

    @Column(name = "request_hash", nullable = false, length = 64)
    private String requestHash;

    @Column(name = "response_code")
    private Integer responseCode;

    @Column(name = "response_body", columnDefinition = "TEXT")
    private String responseBody;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    // Default constructor for JPA
    protected IdempotencyRecordEntity() {
    }

    public IdempotencyRecordEntity(String key, String endpoint, String requestHash,
                                    Integer responseCode, String responseBody, OffsetDateTime expiresAt) {
        this.key = key;
        this.endpoint = endpoint;
        this.requestHash = requestHash;
        this.responseCode = responseCode;
        this.responseBody = responseBody;
        this.createdAt = OffsetDateTime.now();
        this.expiresAt = expiresAt;
    }

    public boolean isExpired() {
        return OffsetDateTime.now().isAfter(expiresAt);
    }

    // Getters
    public String getKey() { return key; }
    public String getEndpoint() { return endpoint; }
    public String getRequestHash() { return requestHash; }
    public Integer getResponseCode() { return responseCode; }
    public String getResponseBody() { return responseBody; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getExpiresAt() { return expiresAt; }
}
