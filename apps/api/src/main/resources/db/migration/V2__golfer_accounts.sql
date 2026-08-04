-- V2__golfer_accounts.sql
-- Flyway migration: creates golfer_accounts table for phone/email registration.
-- Per PRD Section 8.1: supports phone, email, Google Sign-In, Apple Sign-In registration.
-- Per Architecture Section 12: OAuth/OIDC-compatible identity, short-lived access tokens.

CREATE TABLE golfer_accounts (
    id                  BIGSERIAL PRIMARY KEY,
    phone               VARCHAR(20) UNIQUE,
    email               VARCHAR(255) UNIQUE,
    password_hash       VARCHAR(255),                              -- NULL for social-only accounts
    display_name        VARCHAR(100) NOT NULL,
    google_subject      VARCHAR(255) UNIQUE,
    apple_subject       VARCHAR(255) UNIQUE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    verified_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_account_identifier CHECK (
        phone IS NOT NULL OR email IS NOT NULL OR google_subject IS NOT NULL OR apple_subject IS NOT NULL
    ),
    CONSTRAINT chk_status CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'DELETED'))
);

-- Index for phone lookup during login
CREATE INDEX idx_golfer_accounts_phone ON golfer_accounts (phone) WHERE phone IS NOT NULL;

-- Index for email lookup during login and registration
CREATE INDEX idx_golfer_accounts_email ON golfer_accounts (email) WHERE email IS NOT NULL;

-- Index for Google subject lookup during social auth
CREATE INDEX idx_golfer_accounts_google ON golfer_accounts (google_subject) WHERE google_subject IS NOT NULL;

-- Index for Apple subject lookup during social auth
CREATE INDEX idx_golfer_accounts_apple ON golfer_accounts (apple_subject) WHERE apple_subject IS NOT NULL;

-- Index for status filtering
CREATE INDEX idx_golfer_accounts_status ON golfer_accounts (status);

COMMENT ON TABLE golfer_accounts IS 'Golfer account identities supporting phone, email, Google, and Apple authentication.';
COMMENT ON COLUMN golfer_accounts.status IS 'PENDING=awaiting verification; ACTIVE=verified; SUSPENDED=locked; DELETED=soft-deleted';
