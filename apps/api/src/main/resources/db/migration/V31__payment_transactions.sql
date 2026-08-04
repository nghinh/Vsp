-- V25__payment_transactions.sql
-- Flyway migration: creates payment transaction, audit log, and idempotency tables.
-- Per Story 12.3: Payment and Transaction Services.
--
-- CRITICAL: Platform stores NO prohibited card data (PAN, CVV, expiry).
-- Only opaque paymentMethodRef tokens from the provider are stored.

CREATE TABLE payment_transactions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key     VARCHAR(255) NOT NULL,
    provider_reference   VARCHAR(255),                     -- provider's transaction ref (not card data)
    payment_method_ref  VARCHAR(255),                     -- opaque token from provider (NOT card data)
    amount              BIGINT NOT NULL CHECK (amount >= 0),
    currency            VARCHAR(3) NOT NULL,             -- ISO 4217
    state               VARCHAR(30) NOT NULL DEFAULT 'pending'
                                        CHECK (state IN ('pending', 'succeeded', 'failed', 'refunded', 'partially_refunded')),
    failure_reason      VARCHAR(30),
    failure_message     TEXT,
    metadata_json       TEXT,                            -- arbitrary key-value metadata
    refunded_amount     BIGINT NOT NULL DEFAULT 0 CHECK (refunded_amount >= 0),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_refund_amount CHECK (refunded_amount <= amount)
);

-- Index for idempotency lookups (unique constraint to prevent duplicates)
CREATE UNIQUE INDEX idx_payment_tx_idempotency_key ON payment_transactions (idempotency_key);

-- Index for state queries (reconciliation job)
CREATE INDEX idx_payment_tx_state ON payment_transactions (state, updated_at);

-- Index for user-facing transaction lookups
CREATE INDEX idx_payment_tx_created ON payment_transactions (created_at DESC);

-- Index for provider reference lookups (webhook matching)
CREATE INDEX idx_payment_tx_provider_ref ON payment_transactions (provider_reference) WHERE provider_reference IS NOT NULL;

-- ─── Payment Audit Log ───────────────────────────────────────────────────────

CREATE TABLE payment_audit_log (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id     UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
    action            VARCHAR(50) NOT NULL,
    actor             VARCHAR(255) NOT NULL,             -- user ID, 'SYSTEM', or 'PROVIDER_WEBHOOK'
    previous_state    VARCHAR(30),
    new_state         VARCHAR(30),
    metadata_json     TEXT,                              -- additional context: IP, reason, etc.
    correlation_id    VARCHAR(100),                      -- request trace ID from MDC
    timestamp         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for audit trail queries by transaction
CREATE INDEX idx_payment_audit_tx ON payment_audit_log (transaction_id, timestamp);

-- Index for audit queries by actor
CREATE INDEX idx_payment_audit_actor ON payment_audit_log (actor, timestamp);

-- Index for audit queries by action type
CREATE INDEX idx_payment_audit_action ON payment_audit_log (action, timestamp);

-- ─── Idempotency Records ──────────────────────────────────────────────────────
-- Stores idempotency keys for payment operations with TTL-based expiry.
-- Complements the generic IdempotencyService in-memory/Redis store with
-- a persistent PostgreSQL backup for durability.

CREATE TABLE idempotency_records (
    key             VARCHAR(255) PRIMARY KEY,
    endpoint        VARCHAR(100) NOT NULL,
    request_hash    VARCHAR(64) NOT NULL,               -- SHA-256 of request body for conflict detection
    response_code   INTEGER,
    response_body   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMPTZ NOT NULL               -- TTL boundary
);

-- Index for expired record cleanup
CREATE INDEX idx_idempotency_expires ON idempotency_records (expires_at);

-- Background cleanup of expired idempotency records is handled by the
-- IdempotencyStore implementation (TTL-based eviction).

-- ─── Refund Requests ───────────────────────────────────────────────────────────

CREATE TABLE refund_requests (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id        UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
    amount                BIGINT NOT NULL CHECK (amount > 0),
    reason                VARCHAR(30) NOT NULL,
    reason_detail         TEXT,
    provider_refund_ref   VARCHAR(255),                -- provider's refund reference
    status                VARCHAR(20) NOT NULL DEFAULT 'pending'
                                            CHECK (status IN ('pending', 'succeeded', 'failed')),
    idempotency_key       VARCHAR(255) NOT NULL,
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for refund lookups by transaction
CREATE INDEX idx_refund_tx ON refund_requests (transaction_id);

-- Index for refund lookups by status
CREATE INDEX idx_refund_status ON refund_requests (status, requested_at);

-- Unique constraint on idempotency key
CREATE UNIQUE INDEX idx_refund_idempotency ON refund_requests (idempotency_key);
