package vnpt.vsp.module.privacy.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Privacy request entity for data export, account deletion, and round deletion.
 * Per Story 2.5 AC-3: Users can request data export, account deletion,
 * and round deletion with auditable processing.
 * <p>
 * State machine: PENDING → PROCESSING → COMPLETED / REJECTED
 */
@Entity
@Table(name = "privacy_requests")
public class PrivacyRequest {

    /**
     * Type of privacy request.
     */
    public enum RequestType {
        DATA_EXPORT,
        ACCOUNT_DELETION,
        ROUND_DELETION
    }

    /**
     * Processing status of a privacy request.
     * Transitions: PENDING → PROCESSING → COMPLETED / REJECTED
     */
    public enum Status {
        PENDING,
        PROCESSING,
        COMPLETED,
        REJECTED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "requester_golfer_account_id", nullable = false)
    private Long requesterGolferAccountId;

    @Enumerated(EnumType.STRING)
    @Column(name = "request_type", length = 50, nullable = false)
    private RequestType requestType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 50, nullable = false)
    private Status status = Status.PENDING;

    @Column(name = "target_round_id")
    private UUID targetRoundId;

    @Column(name = "requested_at", nullable = false)
    private Instant requestedAt;

    @Column(name = "processed_at")
    private Instant processedAt;

    @Column(name = "processed_by")
    private Long processedBy;

    @Column(name = "rejection_reason", length = 500)
    private String rejectionReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
        if (requestedAt == null) {
            requestedAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRequesterGolferAccountId() {
        return requesterGolferAccountId;
    }

    public void setRequesterGolferAccountId(Long requesterGolferAccountId) {
        this.requesterGolferAccountId = requesterGolferAccountId;
    }

    public RequestType getRequestType() {
        return requestType;
    }

    public void setRequestType(RequestType requestType) {
        this.requestType = requestType;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public UUID getTargetRoundId() {
        return targetRoundId;
    }

    public void setTargetRoundId(UUID targetRoundId) {
        this.targetRoundId = targetRoundId;
    }

    public Instant getRequestedAt() {
        return requestedAt;
    }

    public void setRequestedAt(Instant requestedAt) {
        this.requestedAt = requestedAt;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt) {
        this.processedAt = processedAt;
    }

    public Long getProcessedBy() {
        return processedBy;
    }

    public void setProcessedBy(Long processedBy) {
        this.processedBy = processedBy;
    }

    public String getRejectionReason() {
        return rejectionReason;
    }

    public void setRejectionReason(String rejectionReason) {
        this.rejectionReason = rejectionReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
