package vnpt.vsp.module.identity.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * OTP code entity for phone and email verification.
 * Per PRD Section 8.1: OTP verification required for phone/email registration.
 * Codes are 6 digits, single-use, and expire after 10 minutes.
 */
@Entity
@Table(name = "otp_codes")
public class OtpCode {

    public enum OtpType {
        PHONE_VERIFY,
        EMAIL_VERIFY,
        PASSWORD_RECOVERY
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "golfer_account_id", nullable = false)
    private GolferAccount golferAccount;

    @Column(length = 10, nullable = false)
    private String code;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private OtpType type;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }

    // ─── Getters and Setters ────────────────────────────────────────────────

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public GolferAccount getGolferAccount() {
        return golferAccount;
    }

    public void setGolferAccount(GolferAccount golferAccount) {
        this.golferAccount = golferAccount;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public OtpType getType() {
        return type;
    }

    public void setType(OtpType type) {
        this.type = type;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public Instant getVerifiedAt() {
        return verifiedAt;
    }

    public void setVerifiedAt(Instant verifiedAt) {
        this.verifiedAt = verifiedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    // ─── Convenience Methods ────────────────────────────────────────────────

    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }

    public boolean isVerified() {
        return verifiedAt != null;
    }

    public boolean isActive() {
        return !isExpired() && !isVerified();
    }

    public void markVerified() {
        this.verifiedAt = Instant.now();
    }
}
