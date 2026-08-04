-- Rounds and scores tables for round management
-- Per Story 2.3 and 2.5: rounds with soft-delete for ROUND_DELETION privacy request

CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    golfer_account_id BIGINT NOT NULL REFERENCES golfer_accounts(id),
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMP,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_round_status CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'ABANDONED', 'CANCELLED'))
);

CREATE INDEX idx_rounds_golfer ON rounds(golfer_account_id);
CREATE INDEX idx_rounds_status ON rounds(status);
CREATE INDEX idx_rounds_deleted ON rounds(deleted_at);

CREATE TABLE scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id),
    golfer_account_id BIGINT NOT NULL REFERENCES golfer_accounts(id),
    deleted_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scores_round ON scores(round_id);
CREATE INDEX idx_scores_golfer ON scores(golfer_account_id);
CREATE INDEX idx_scores_deleted ON scores(deleted_at);
