package vnpt.vsp.module.identity.dto;

import java.time.Instant;

/**
 * DTO for a session returned in the session list.
 * Per Story 2.2 AC-3: user can list and revoke sessions.
 */
public class SessionResponse {

    private Long sessionId;
    private String deviceInfo;
    private String userAgent;
    private String ipAddress;
    private Instant createdAt;
    private Instant expiresAt;
    private boolean currentSession;

    public SessionResponse() {}

    public SessionResponse(Long sessionId, String deviceInfo, String userAgent,
                          String ipAddress, Instant createdAt, Instant expiresAt,
                          boolean currentSession) {
        this.sessionId = sessionId;
        this.deviceInfo = deviceInfo;
        this.userAgent = userAgent;
        this.ipAddress = ipAddress;
        this.createdAt = createdAt;
        this.expiresAt = expiresAt;
        this.currentSession = currentSession;
    }

    public static Builder builder() {
        return new Builder();
    }

    public Long getSessionId() {
        return sessionId;
    }

    public void setSessionId(Long sessionId) {
        this.sessionId = sessionId;
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

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }

    public boolean isCurrentSession() {
        return currentSession;
    }

    public void setCurrentSession(boolean currentSession) {
        this.currentSession = currentSession;
    }

    public static class Builder {
        private Long sessionId;
        private String deviceInfo;
        private String userAgent;
        private String ipAddress;
        private Instant createdAt;
        private Instant expiresAt;
        private boolean currentSession;

        public Builder sessionId(Long sessionId) {
            this.sessionId = sessionId;
            return this;
        }

        public Builder deviceInfo(String deviceInfo) {
            this.deviceInfo = deviceInfo;
            return this;
        }

        public Builder userAgent(String userAgent) {
            this.userAgent = userAgent;
            return this;
        }

        public Builder ipAddress(String ipAddress) {
            this.ipAddress = ipAddress;
            return this;
        }

        public Builder createdAt(Instant createdAt) {
            this.createdAt = createdAt;
            return this;
        }

        public Builder expiresAt(Instant expiresAt) {
            this.expiresAt = expiresAt;
            return this;
        }

        public Builder currentSession(boolean currentSession) {
            this.currentSession = currentSession;
            return this;
        }

        public SessionResponse build() {
            return new SessionResponse(sessionId, deviceInfo, userAgent, ipAddress, createdAt, expiresAt, currentSession);
        }
    }
}
