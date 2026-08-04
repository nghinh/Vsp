-- V5__refresh_tokens.sql
-- Flyway migration: creates refresh_tokens table for rotating refresh token session management.
-- Per PRD Section 10.6: token expiration and refresh-token rotation.
-- Per Architecture Section 12: short-lived access tokens, refresh-token rotation.
-- Per Story 2.2 AC-1: access tokens short-lived and refresh tokens rotate.
-- Per Story 2.2 AC-3: user can list and revoke sessions; revoked sessions cannot refresh.

CREATE TABLE refresh_tokens (
    id                  BIGSERIAL PRIMARY KEY,
    golfer_account_id  BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,
    token_hash          VARCHAR(64) NOT NULL,
    device_info         VARCHAR(255),
    user_agent          VARCHAR(512),
    ip_address          VARCHAR(45),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at          TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    replaced_by_token_id BIGINT REFERENCES refresh_tokens(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_refresh_token_not_expired CHECK (expires_at > created_at),
    CONSTRAINT chk_refresh_token_revoked CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);

-- Index for fast lookup during token refresh validation (by hash)
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens (token_hash) WHERE revoked_at IS NULL;

-- Index for listing active sessions by account
CREATE INDEX idx_refresh_tokens_account_active ON refresh_tokens (golfer_account_id, created_at DESC) WHERE revoked_at IS NULL;

-- Index for finding a specific active token by account and hash
CREATE INDEX idx_refresh_tokens_account_hash ON refresh_tokens (golfer_account_id, token_hash) WHERE revoked_at IS NULL;

-- Index for cleanup of expired tokens
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens (expires_at);

-- Index for revoked tokens (audit/history)
CREATE INDEX idx_refresh_tokens_revoked ON refresh_tokens (revoked_at) WHERE revoked_at IS NOT NULL;

COMMENT ON TABLE refresh_tokens IS 'Rotating refresh tokens for session management. Each refresh rotates the token and marks the old one revoked.';
COMMENT ON COLUMN refresh_tokens.token_hash IS 'SHA-256 hash of the raw refresh token value. Raw token never stored.';
COMMENT ON COLUMN refresh_tokens.device_info IS 'Client-reported device identifier or device model string.';
COMMENT ON COLUMN refresh_tokens.replaced_by_token_id IS 'Points to the new token that replaced this one during rotation. NULL if this is the current active token or was revoked without replacement.';
