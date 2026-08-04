-- Tournament tables for tournament management
-- Per Story 12.1 Slice B: core tournament entity

CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    format VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    course_id BIGINT NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    tournament_policy_id UUID REFERENCES tournament_policies(id),
    registration_deadline TIMESTAMP,
    max_players INT,
    description VARCHAR(2000),
    leaderboard_version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_tournament_format CHECK (format IN ('STROKE_PLAY', 'MATCH_PLAY', 'STABLEFORD')),
    CONSTRAINT chk_tournament_status CHECK (status IN ('DRAFT', 'REGISTRATION_OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_course ON tournaments(course_id);
CREATE INDEX idx_tournaments_policy ON tournaments(tournament_policy_id);
CREATE INDEX idx_tournaments_created_by ON tournaments(created_by);
CREATE INDEX idx_tournaments_start_date ON tournaments(start_date);
