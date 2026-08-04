package vnpt.vsp.module.identity.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Password recovery token entity for password reset flow.
 * Per PRD Section 8.1: password recovery supported for phone/email accounts.
 * Tokens are single-use and expire after 1 hour.
 */
@Entity
@Table(name = "password_recovery_tokens")
public class PasswordRecoveryToken {

    public enum TokenType {
        PASSWORD_RESET
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "golfer_account_id", nullable = false)
    private GolferAccount golferAccount;

    @Column(length = 64, nullable = false, unique = true)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(length = 20, nullable = false)
    private TokenType type = TokenType.PASSWORD_RESET;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "used_at")
    private Instant usedAt;

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

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public TokenType getType() {
        return type;
    }

    public void setType(TokenType type) {
        this.type = type;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public Instant getUsedAt() {
        return usedAt;
    }

    public void setUsedAt(Instant usedAt) {
        this.usedAt = usedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    // ─── Convenience Methods ────────────────────────────────────────────────

    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }

    public boolean isUsed() {
        return usedAt != null;
    }

    public boolean isActive() {
        return !isExpired() && !isUsed();
    }

    public void markUsed() {
        this.usedAt = Instant.now();
    }
}
