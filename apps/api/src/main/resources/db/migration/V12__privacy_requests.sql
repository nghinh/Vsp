-- Privacy requests table
-- Per Story 2.5 AC-3: Users can request data export, account deletion, round deletion with auditable processing
CREATE TABLE privacy_requests (
    id BIGSERIAL PRIMARY KEY,
    requester_golfer_account_id BIGINT NOT NULL REFERENCES golfer_accounts(id),
    request_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    target_round_id UUID,
    requested_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP,
    processed_by BIGINT REFERENCES golfer_accounts(id),
    rejection_reason VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_request_type CHECK (request_type IN ('DATA_EXPORT', 'ACCOUNT_DELETION', 'ROUND_DELETION')),
    CONSTRAINT chk_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'REJECTED'))
);

CREATE INDEX idx_privacy_requests_requester ON privacy_requests(requester_golfer_account_id);
CREATE INDEX idx_privacy_requests_status ON privacy_requests(status);
CREATE INDEX idx_privacy_requests_requested_at ON privacy_requests(requested_at);

-- Anonymization columns for golfer accounts (for ACCOUNT_DELETION privacy request)
-- Note: rounds.deleted_at added in V14 (after rounds table creation)
ALTER TABLE golfer_accounts ADD COLUMN anonymized_at TIMESTAMP;
ALTER TABLE golfer_accounts ADD COLUMN anonymized_data TEXT;
