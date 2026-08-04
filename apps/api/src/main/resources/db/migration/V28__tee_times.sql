-- Tee times table for tournament scheduling
-- Per Story 12.1 Slice B: tee time slots with course and starting tee assignment

CREATE TABLE tee_times (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    tee_time TIMESTAMP NOT NULL,
    course_id BIGINT NOT NULL,
    starting_tee_box_id BIGINT,
    flight_id UUID UNIQUE REFERENCES flights(id)
);

CREATE INDEX idx_tee_times_tournament ON tee_times(tournament_id);
CREATE INDEX idx_tee_times_course ON tee_times(course_id);
CREATE INDEX idx_tee_times_flight ON tee_times(flight_id);
CREATE INDEX idx_tee_times_time ON tee_times(tee_time);

-- Add flight_id FK to tournament_players (players belong to flights)
ALTER TABLE tournament_players ADD CONSTRAINT fk_tournament_players_flight
    FOREIGN KEY (flight_id) REFERENCES flights(id);

-- Add tee_time_id FK to flights (flight assigned to tee time)
ALTER TABLE flights ADD CONSTRAINT fk_flights_tee_time
    FOREIGN KEY (tee_time_id) REFERENCES tee_times(id);
