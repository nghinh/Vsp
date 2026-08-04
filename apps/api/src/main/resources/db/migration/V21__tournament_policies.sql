-- Tournament policies and audit trail
-- Per Story 7.4 Slice A: TournamentPolicy domain model + persistence

-- TournamentPolicy: feature restriction policy attached to a tournament-format round
CREATE TABLE tournament_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    wind_adjustment BOOLEAN NOT NULL DEFAULT TRUE,
    plays_like BOOLEAN NOT NULL DEFAULT TRUE,
    elevation BOOLEAN NOT NULL DEFAULT TRUE,
    club_recommendation BOOLEAN NOT NULL DEFAULT TRUE,
    contours BOOLEAN NOT NULL DEFAULT TRUE,
    putting_help BOOLEAN NOT NULL DEFAULT TRUE,
    ai_features BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES golfer_accounts(id),
    version INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_tournament_policies_created_by ON tournament_policies(created_by);
CREATE INDEX idx_tournament_policies_is_locked ON tournament_policies(is_locked);

-- TournamentPolicyChange: audit trail for all policy changes
CREATE TABLE tournament_policy_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES tournament_policies(id),
    changed_by BIGINT NOT NULL REFERENCES golfer_accounts(id),
    changed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    before_json JSONB,
    after_json JSONB NOT NULL,
    reason VARCHAR(500)
);

CREATE INDEX idx_tournament_policy_changes_policy ON tournament_policy_changes(policy_id);
CREATE INDEX idx_tournament_policy_changes_changed_at ON tournament_policy_changes(changed_at);
