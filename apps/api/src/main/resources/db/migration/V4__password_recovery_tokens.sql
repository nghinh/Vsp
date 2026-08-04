-- V4__password_recovery_tokens.sql
-- Flyway migration: creates password_recovery_tokens table for password reset flow.
-- Per PRD Section 8.1: password recovery supported for phone/email accounts.
-- Tokens are single-use, short-lived (1 hour), and tied to a specific account.

CREATE TABLE password_recovery_tokens (
    id                  BIGSERIAL PRIMARY KEY,
    golfer_account_id  BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,
    token               VARCHAR(64) NOT NULL UNIQUE,
    type                VARCHAR(20) NOT NULL DEFAULT 'PASSWORD_RESET',  -- 'PASSWORD_RESET'
    expires_at          TIMESTAMPTZ NOT NULL,
    used_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_recovery_token_type CHECK (type IN ('PASSWORD_RESET'))
);

-- Index for fast lookup during password reset
CREATE INDEX idx_password_recovery_tokens_account_id ON password_recovery_tokens (golfer_account_id);

-- Index for finding active (non-used, non-expired) token
CREATE INDEX idx_password_recovery_tokens_active ON password_recovery_tokens (golfer_account_id, expires_at) WHERE used_at IS NULL;

-- Index for token lookup (high-selectivity)
CREATE INDEX idx_password_recovery_tokens_token ON password_recovery_tokens (token) WHERE used_at IS NULL;

-- Index for cleanup of old tokens
CREATE INDEX idx_password_recovery_tokens_expires ON password_recovery_tokens (expires_at);

COMMENT ON TABLE password_recovery_tokens IS 'Password recovery tokens for resetting forgotten passwords.';
