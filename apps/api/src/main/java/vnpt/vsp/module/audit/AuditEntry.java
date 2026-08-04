package vnpt.vsp.module.audit;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

/**
 * JPA entity representing a single audit log entry.
 * <p>
 * Audit entries are <strong>append-only</strong> — no update or delete operations
 * are permitted. Retention is enforced by a scheduled job (not a DB constraint) per
 * NFR10 (7-year compliance).
 * <p>
 * The {@code correlationId} field links this entry to the HTTP request trace
 * managed by {@link vnpt.vsp.api.error.CorrelationIdFilter} via MDC, satisfying
 * the correlation-ID requirement in §13 Observability Architecture.
 */
@Entity
@Table(name = "audit_entries", indexes = {
        @Index(name = "idx_audit_object", columnList = "object_type, object_id"),
        @Index(name = "idx_audit_actor", columnList = "actor, timestamp"),
        @Index(name = "idx_audit_action", columnList = "action, timestamp"),
        @Index(name = "idx_audit_correlation", columnList = "correlation_id")
})
public class AuditEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String actor;

    @Column(length = 100)
    private String role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private AuditAction action;

    @Column(name = "object_type", nullable = false, length = 100)
    private String objectType;

    @Column(name = "object_id")
    private String objectId;

    @Column(name = "before_json", columnDefinition = "TEXT")
    private String beforeJson;

    @Column(name = "after_json", columnDefinition = "TEXT")
    private String afterJson;

    @Column(name = "metadata_json", columnDefinition = "TEXT")
    private String metadataJson;

    @Column(name = "correlation_id", length = 100)
    private String correlationId;

    @Column(nullable = false)
    private OffsetDateTime timestamp;

    @Column(nullable = false)
    private Integer version = 1;

    // Default constructor for JPA
    protected AuditEntry() {
    }

    // Builder-style constructor
    public AuditEntry(String actor, String role, AuditAction action,
                      String objectType, String objectId,
                      String beforeJson, String afterJson,
                      String metadataJson, String correlationId) {
        this.actor = actor;
        this.role = role;
        this.action = action;
        this.objectType = objectType;
        this.objectId = objectId;
        this.beforeJson = beforeJson;
        this.afterJson = afterJson;
        this.metadataJson = metadataJson;
        this.correlationId = correlationId;
        this.timestamp = OffsetDateTime.now();
        this.version = 1;
    }

    // Getters only — immutable after construction
    public Long getId() { return id; }
    public String getActor() { return actor; }
    public String getRole() { return role; }
    public AuditAction getAction() { return action; }
    public String getObjectType() { return objectType; }
    public String getObjectId() { return objectId; }
    public String getBeforeJson() { return beforeJson; }
    public String getAfterJson() { return afterJson; }
    public String getMetadataJson() { return metadataJson; }
    public String getCorrelationId() { return correlationId; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public Integer getVersion() { return version; }
}
