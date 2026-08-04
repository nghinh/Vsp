package vnpt.vsp.module.identity.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Golfer account entity representing a golfer's identity.
 * Supports phone, email, Google, and Apple authentication methods.
 * Per PRD Section 8.1: users can register with phone, email, Google, or Apple.
 */
@Entity
@Table(name = "golfer_accounts")
public class GolferAccount {

    public enum Status {
        PENDING,    // Awaiting verification
        ACTIVE,     // Verified and active
        SUSPENDED,  // Temporarily locked
        DELETED     // Soft-deleted
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 20, unique = true)
    private String phone;

    @Column(length = 255, unique = true)
    private String email;

    @Column(name = "password_hash", length = 255)
    private String passwordHash;

    @Column(name = "display_name", length = 100, nullable = false)
    private String displayName;

    @Column(name = "google_subject", length = 255, unique = true)
    private String googleSubject;

    @Column(name = "apple_subject", length = 255, unique = true)
    private String appleSubject;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private Status status = Status.PENDING;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "anonymized_at")
    private Instant anonymizedAt;

    @Column(name = "anonymized_data", length = 1000)
    private String anonymizedData;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getGoogleSubject() {
        return googleSubject;
    }

    public void setGoogleSubject(String googleSubject) {
        this.googleSubject = googleSubject;
    }

    public String getAppleSubject() {
        return appleSubject;
    }

    public void setAppleSubject(String appleSubject) {
        this.appleSubject = appleSubject;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public Instant getVerifiedAt() {
        return verifiedAt;
    }

    public void setVerifiedAt(Instant verifiedAt) {
        this.verifiedAt = verifiedAt;
    }

    public Instant getAnonymizedAt() {
        return anonymizedAt;
    }

    public void setAnonymizedAt(Instant anonymizedAt) {
        this.anonymizedAt = anonymizedAt;
    }

    public String getAnonymizedData() {
        return anonymizedData;
    }

    public void setAnonymizedData(String anonymizedData) {
        this.anonymizedData = anonymizedData;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    // ─── Convenience Methods ────────────────────────────────────────────────

    public boolean isVerified() {
        return verifiedAt != null;
    }

    public boolean isActive() {
        return status == Status.ACTIVE;
    }

    public boolean hasPassword() {
        return passwordHash != null;
    }

    public boolean hasPhone() {
        return phone != null;
    }

    public boolean hasEmail() {
        return email != null;
    }
}
