package vnpt.vsp.module.identity.entity;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Refresh token entity representing a rotating session token.
 * Per Story 2.2 AC-1: refresh tokens rotate on each use.
 * Per Story 2.2 AC-3: revoked sessions cannot refresh.
 * Per Architecture Section 12: short-lived access tokens, refresh-token rotation.
 */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "golfer_account_id", nullable = false)
    private GolferAccount golferAccount;

    @Column(name = "token_hash", length = 64, nullable = false)
    private String tokenHash;

    @Column(name = "device_info", length = 255)
    private String deviceInfo;

    @Column(name = "user_agent", length = 512)
    private String userAgent;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "replaced_by_token_id")
    private RefreshToken replacedByToken;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }

    // ─── Getters and Setters ───────────────────────────────────────────────

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

    public String getTokenHash() {
        return tokenHash;
    }

    public void setTokenHash(String tokenHash) {
        this.tokenHash = tokenHash;
    }

    public String getDeviceInfo() {
        return deviceInfo;
    }

    public void setDeviceInfo(String deviceInfo) {
        this.deviceInfo = deviceInfo;
    }

    public String getUserAgent() {
        return userAgent;
    }

    public void setUserAgent(String userAgent) {
        this.userAgent = userAgent;
    }

    public String getIpAddress() {
        return ipAddress;
    }

    public void setIpAddress(String ipAddress) {
        this.ipAddress = ipAddress;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public Instant getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(Instant revokedAt) {
        this.revokedAt = revokedAt;
    }

    public RefreshToken getReplacedByToken() {
        return replacedByToken;
    }

    public void setReplacedByToken(RefreshToken replacedByToken) {
        this.replacedByToken = replacedByToken;
    }

    // ─── Convenience Methods ────────────────────────────────────────────────

    public boolean isActive() {
        return revokedAt == null && expiresAt.isAfter(Instant.now());
    }

    public boolean isRevoked() {
        return revokedAt != null;
    }

    public boolean isExpired() {
        return expiresAt.isBefore(Instant.now());
    }

    public void revoke() {
        this.revokedAt = Instant.now();
    }

    public void markReplacedBy(RefreshToken newToken) {
        this.replacedByToken = newToken;
    }
}
