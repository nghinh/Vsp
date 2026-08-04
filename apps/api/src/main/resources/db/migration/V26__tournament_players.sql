-- Tournament players table for tournament registration
-- Per Story 12.1 Slice B: player registration with status tracking

CREATE TABLE tournament_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    player_id BIGINT NOT NULL,
    handicap DOUBLE PRECISION,
    flight_id UUID,
    registration_time TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'REGISTERED',
    CONSTRAINT chk_tournament_player_status CHECK (status IN ('REGISTERED', 'CONFIRMED', 'WITHDRAWN', 'DISQUALIFIED')),
    CONSTRAINT uq_tournament_player UNIQUE (tournament_id, player_id)
);

CREATE INDEX idx_tournament_players_tournament ON tournament_players(tournament_id);
CREATE INDEX idx_tournament_players_player ON tournament_players(player_id);
CREATE INDEX idx_tournament_players_flight ON tournament_players(flight_id);
CREATE INDEX idx_tournament_players_status ON tournament_players(status);
