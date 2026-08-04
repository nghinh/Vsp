package vnpt.vsp.module.tournament.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Audit record for TournamentPolicy changes.
 *
 * Per PRD §8.12: "Enabled feature set is auditable."
 *
 * Every create, update, and lock operation emits a record with
 * before/after JSON snapshots for compliance review.
 */
@Entity
@Table(name = "tournament_policy_changes")
public class TournamentPolicyChange {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "policy_id", nullable = false)
    private UUID policyId;

    @Column(name = "changed_by", nullable = false)
    private Long changedBy;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "before_json", columnDefinition = "jsonb")
    private Map<String, Object> beforeJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "after_json", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> afterJson;

    @Column(name = "reason", length = 500)
    private String reason;

    @PrePersist
    protected void onCreate() {
        if (changedAt == null) {
            changedAt = Instant.now();
        }
    }

    // ─── Getters / Setters ──────────────────────────────────────────────────

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getPolicyId() { return policyId; }
    public void setPolicyId(UUID policyId) { this.policyId = policyId; }

    public Long getChangedBy() { return changedBy; }
    public void setChangedBy(Long changedBy) { this.changedBy = changedBy; }

    public Instant getChangedAt() { return changedAt; }
    public void setChangedAt(Instant changedAt) { this.changedAt = changedAt; }

    public Map<String, Object> getBeforeJson() { return beforeJson; }
    public void setBeforeJson(Map<String, Object> beforeJson) { this.beforeJson = beforeJson; }

    public Map<String, Object> getAfterJson() { return afterJson; }
    public void setAfterJson(Map<String, Object> afterJson) { this.afterJson = afterJson; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
}
