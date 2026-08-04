-- Tie-break rules table for tournament tie resolution
-- Per Story 12.1 Slice B: ordered tie-break procedure

CREATE TABLE tie_break_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    rule_order INT NOT NULL,
    rule_type VARCHAR(30) NOT NULL,
    CONSTRAINT chk_tie_break_rule_type CHECK (rule_type IN ('SCORECARD_PLAYOFF', 'EXACT_HANDICAP', 'LOWEST_ROUND', 'MOST_BIRDIES', 'DRAW'))
);

CREATE INDEX idx_tie_break_rules_tournament ON tie_break_rules(tournament_id);
CREATE INDEX idx_tie_break_rules_order ON tie_break_rules(tournament_id, rule_order);
