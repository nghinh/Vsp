package vnpt.vsp.module.role.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * JPA entity representing an MFA-enabled admin account.
 * Links a GolferAccount to the admin RBAC system.
 * Per Story 2.5 AC-2: Admin accounts require MFA.
 * Per RFC 6238: TOTP with SHA-1, 6-digit code, 30-second window.
 */
@Entity
@Table(name = "admin_accounts")
@vnpt.vsp.module.role.RoleModule
public class AdminAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "golfer_account_id", unique = true, nullable = false)
    private Long golferAccountId;

    @Column(name = "mfa_enabled", nullable = false)
    private Boolean mfaEnabled = false;

    /**
     * The AES-GCM encrypted TOTP secret, Base64-armoured.
     *
     * <p>Non-null exactly when there is a secret to check codes against: while an
     * enrolment is pending ({@code mfaEnabled} false) and for as long as MFA is
     * on. {@code mfaEnabled} true with this null is the inconsistent state the
     * old enable-in-one-call flow could leave behind, and nothing may produce it.
     *
     * <p>255, not 64: the stored blob is a 12-byte IV plus ciphertext plus a
     * 16-byte tag, Base64-armoured — about 80 characters for a 160-bit secret. At
     * 64 the column could not hold one, so every enrolment that got as far as
     * saving died on "value too long for type character varying(64)".
     */
    @Column(name = "mfa_secret", length = 255)
    private String mfaSecret;

    @Column(name = "mfa_verified_at")
    private Instant mfaVerifiedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "adminAccount", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<AdminRoleAssignment> roleAssignments = new ArrayList<>();

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

    public Long getGolferAccountId() {
        return golferAccountId;
    }

    public void setGolferAccountId(Long golferAccountId) {
        this.golferAccountId = golferAccountId;
    }

    public Boolean getMfaEnabled() {
        return mfaEnabled;
    }

    public void setMfaEnabled(Boolean mfaEnabled) {
        this.mfaEnabled = mfaEnabled;
    }

    public String getMfaSecret() {
        return mfaSecret;
    }

    public void setMfaSecret(String mfaSecret) {
        this.mfaSecret = mfaSecret;
    }

    public Instant getMfaVerifiedAt() {
        return mfaVerifiedAt;
    }

    public void setMfaVerifiedAt(Instant mfaVerifiedAt) {
        this.mfaVerifiedAt = mfaVerifiedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public List<AdminRoleAssignment> getRoleAssignments() {
        return roleAssignments;
    }

    public void setRoleAssignments(List<AdminRoleAssignment> roleAssignments) {
        this.roleAssignments = roleAssignments;
    }
}
