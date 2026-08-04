-- V3__otp_codes.sql
-- Flyway migration: creates otp_codes table for phone/email verification OTP storage.
-- Per PRD Section 8.1: OTP verification required for phone/email registration.
-- OTP codes are short-lived (10 minutes), single-use, and tied to a specific account.

CREATE TABLE otp_codes (
    id                  BIGSERIAL PRIMARY KEY,
    golfer_account_id  BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,
    code                VARCHAR(10) NOT NULL,
    type                VARCHAR(20) NOT NULL,  -- 'PHONE_VERIFY' or 'EMAIL_VERIFY'
    expires_at          TIMESTAMPTZ NOT NULL,
    verified_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_otp_type CHECK (type IN ('PHONE_VERIFY', 'EMAIL_VERIFY')),
    CONSTRAINT chk_otp_code_format CHECK (LENGTH(code) = 6)
);

-- Index for fast lookup during OTP verification
CREATE INDEX idx_otp_codes_account_id ON otp_codes (golfer_account_id);

-- Index for finding active (non-verified, non-expired) OTP for an account
CREATE INDEX idx_otp_codes_active ON otp_codes (golfer_account_id, type, expires_at) WHERE verified_at IS NULL;

-- Index for cleanup of old expired OTPs
CREATE INDEX idx_otp_codes_expires ON otp_codes (expires_at);

COMMENT ON TABLE otp_codes IS 'OTP codes for phone and email verification during registration and password recovery.';
