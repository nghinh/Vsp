-- Round completion and score correction audit infrastructure
-- Per Story 5.5 Slice 1: completion endpoint + score correction with audit trail

-- Score correction audit table
-- Tracks all field-level corrections to score entries with actor and timestamp
CREATE TABLE score_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id),
    player_id BIGINT NOT NULL REFERENCES golfer_accounts(id),
    field_name VARCHAR(50) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    corrected_at TIMESTAMP NOT NULL DEFAULT NOW(),
    corrected_by BIGINT NOT NULL REFERENCES golfer_accounts(id)
);

CREATE INDEX idx_score_corrections_round ON score_corrections(round_id);
CREATE INDEX idx_score_corrections_player ON score_corrections(player_id);
CREATE INDEX idx_score_corrections_corrected_at ON score_corrections(corrected_at);

-- Score entries per hole
-- Stores per-hole scoring data: strokes, putts, penalties, and optional tracking fields
CREATE TABLE score_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    score_id UUID NOT NULL REFERENCES scores(id),
    hole_number INT NOT NULL CHECK (hole_number BETWEEN 1 AND 27),
    par INT NOT NULL,
    strokes INT NOT NULL,
    putts INT DEFAULT 0,
    penalties INT DEFAULT 0,
    fairway_hit BOOLEAN,
    gir BOOLEAN,
    bunker BOOLEAN,
    club VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_score_entries_strokes CHECK (strokes >= 1)
);

CREATE INDEX idx_score_entries_score ON score_entries(score_id);
CREATE INDEX idx_score_entries_hole ON score_entries(score_id, hole_number);
