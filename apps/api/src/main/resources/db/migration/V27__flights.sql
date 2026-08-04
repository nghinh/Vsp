-- Flights table for grouping players into tee times
-- Per Story 12.1 Slice B: flights with starting tee and score confirmation

CREATE TABLE flights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    flight_number INT NOT NULL,
    tee_time_id UUID,
    starting_tee VARCHAR(10) NOT NULL,
    confirmed_at TIMESTAMP,
    confirmed_by BIGINT,
    CONSTRAINT chk_flight_starting_tee CHECK (starting_tee IN ('FRONT', 'BACK'))
);

CREATE INDEX idx_flights_tournament ON flights(tournament_id);
CREATE INDEX idx_flights_tee_time ON flights(tee_time_id);

-- Note: Add foreign key to tournament_players after tee_times table is created
