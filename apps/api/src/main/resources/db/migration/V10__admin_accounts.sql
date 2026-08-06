-- V10__admin_accounts.sql
-- Flyway migration: creates admin_accounts table for MFA-enabled admin accounts.
-- Per Story 2.5 AC-2: Admin accounts require MFA.
-- Per Architecture §12 Security: MFA for admin users.
-- Per RFC 6238: TOTP with SHA-1, 6-digit code, 30-second window.

CREATE TABLE admin_accounts (
    id                          BIGSERIAL PRIMARY KEY,
    golfer_account_id          BIGINT NOT NULL UNIQUE REFERENCES golfer_accounts(id) ON DELETE CASCADE,

    -- MFA state
    mfa_enabled                 BOOLEAN NOT NULL DEFAULT FALSE,
    -- 255, not 64: the stored value is the AES-GCM blob (12-byte IV + ciphertext
    -- + 16-byte tag) Base64-armoured, which is ~80 characters for a 160-bit
    -- secret. At VARCHAR(64) no encrypted secret could ever be written — every
    -- enrolment ended in "value too long for type character varying(64)".
    mfa_secret                 VARCHAR(255),    -- AES-GCM encrypted TOTP secret, Base64-armoured
    mfa_verified_at            TIMESTAMPTZ,     -- Set on successful first TOTP verification

    -- Timestamps
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookup by golfer account
CREATE UNIQUE INDEX idx_admin_accounts_golfer ON admin_accounts (golfer_account_id);

COMMENT ON TABLE admin_accounts IS 'MFA-enabled admin account linking to GolferAccount. Per Story 2.5 AC-2.';
COMMENT ON COLUMN admin_accounts.mfa_secret IS 'AES-encrypted TOTP secret. Decrypted only in-memory during verification.';
COMMENT ON COLUMN admin_accounts.mfa_verified_at IS 'Timestamp of first successful TOTP verification. MFA cannot be disabled without this being set.';
