-- Tournament results table for published final standings
-- Per Story 12.1 Slice B: final results with tie-break tracking

CREATE TABLE tournament_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL,
    rank INT NOT NULL,
    score INT NOT NULL,
    score_to_par INT,
    prize DOUBLE PRECISION,
    tie_break_applied BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMP,
    CONSTRAINT uq_tournament_result UNIQUE (tournament_id, player_id)
);

CREATE INDEX idx_tournament_results_tournament ON tournament_results(tournament_id);
CREATE INDEX idx_tournament_results_player ON tournament_results(player_id);
CREATE INDEX idx_tournament_results_rank ON tournament_results(tournament_id, rank);

-- Add tournament_id to rounds table for tournament-format rounds
-- Per Story 12.1 Slice B: tournament rounds link to tournament
ALTER TABLE rounds ADD COLUMN tournament_id UUID REFERENCES tournaments(id);
CREATE INDEX idx_rounds_tournament ON rounds(tournament_id);
