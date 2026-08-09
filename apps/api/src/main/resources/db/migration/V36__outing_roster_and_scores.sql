-- A club outing, as the club actually runs one.
--
-- The tournament tables were built for registered app users playing a scored
-- event: tournament_players.player_id is a NOT NULL bigint pointing at a golfer
-- account, and there is nowhere at all to put a score. The club's outing sheet
-- is a different shape. Forty-four people are identified by name and Mã VGA,
-- most of them have never opened the app, they are split into two prize groups
-- by handicap, and on the day the only thing that matters is getting eleven
-- scorecards typed in and the winners on a screen before the buffet ends.
--
-- So: let a player be a name, carry the division and the judging handicap, and
-- give the row somewhere to hold eighteen numbers.

-- ─── Players who are not app accounts ───────────────────────────────────────

ALTER TABLE tournament_players
    ALTER COLUMN player_id DROP NOT NULL;

ALTER TABLE tournament_players
    ADD COLUMN display_name      VARCHAR(120),
    ADD COLUMN vga_code          VARCHAR(32),
    ADD COLUMN division_code     VARCHAR(8),
    -- The handicap the prize is judged off: the declared one after the club's
    -- cap. Kept beside `handicap` rather than replacing it, because the two
    -- differ for exactly the players the cap exists for, and the sheet prints
    -- both ("Handicap xét giải" against vHandicap).
    ADD COLUMN playing_handicap  INTEGER,
    ADD COLUMN gross_total       INTEGER,
    -- One entry per hole, in play order; 0 means "not entered yet". An array
    -- rather than a row per hole: it is always read and written whole, one
    -- scorecard at a time, and 44 rows beat 792.
    ADD COLUMN hole_scores       INTEGER[],
    ADD COLUMN scores_entered_at TIMESTAMPTZ,
    ADD COLUMN scores_entered_by BIGINT;

COMMENT ON COLUMN tournament_players.player_id IS
    'Golfer account, when the player has one. Null for a guest entered by name — see V36.';
COMMENT ON COLUMN tournament_players.playing_handicap IS
    'Handicap the prize is judged off, after the outing rules'' cap';
COMMENT ON COLUMN tournament_players.hole_scores IS
    'Strokes per hole in play order; 0 = not entered';

-- A player is either an account or a name. Neither is not a player.
ALTER TABLE tournament_players
    ADD CONSTRAINT chk_tournament_player_identified
        CHECK (player_id IS NOT NULL OR display_name IS NOT NULL);

CREATE INDEX idx_tournament_player_division
    ON tournament_players(tournament_id, division_code);

-- ─── The rules of this particular outing ────────────────────────────────────

-- Division boundaries, the handicap cap, the judging floor, the countback
-- windows, the daily-CAP scale, which holes carry a technical prize: all of it
-- differs per outing and none of it belongs in code. Stored as JSON because it
-- is read and written whole, by one screen, and never queried across events.
ALTER TABLE tournaments
    ADD COLUMN outing_rules JSONB;

COMMENT ON COLUMN tournaments.outing_rules IS
    'OutingRules for this event — divisions, handicap cap, judging floor, '
    'countback windows, daily-CAP bands, technical prizes. Null = not configured yet.';

-- ─── Technical prize measurements ───────────────────────────────────────────

-- "BTC sẽ có bảng ghi thành tích trên sân" — the nearest-to-pin and
-- longest-drive board is filled in by the players themselves during the round,
-- so these arrive separately from the scorecards and often before them.
CREATE TABLE tournament_technical_entries (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    player_id     UUID NOT NULL REFERENCES tournament_players(id) ON DELETE CASCADE,
    prize_code    VARCHAR(16) NOT NULL,
    hole_number   INTEGER NOT NULL,
    measurement   NUMERIC(8,2) NOT NULL,
    recorded_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    recorded_by   BIGINT,
    -- One measurement per player per hole per prize: a second entry replaces
    -- the first rather than competing with it.
    CONSTRAINT uq_technical_entry UNIQUE (tournament_id, prize_code, hole_number, player_id)
);

CREATE INDEX idx_technical_entry_tournament
    ON tournament_technical_entries(tournament_id, prize_code, hole_number);

-- ─── Results ────────────────────────────────────────────────────────────────

-- tournament_results already exists and already carries rank, score and
-- hole_scores. What it has no room for is which division a rank belongs to,
-- which prize the rank won, and the numbers the club reads out beside it.
-- Results are keyed by the entry, not the account: player_id is a NOT NULL
-- bigint pointing at a golfer account, so a guest's result had nowhere to go
-- and the whole prize table would have failed to save on the first name that
-- was not an app user.
ALTER TABLE tournament_results
    ALTER COLUMN player_id DROP NOT NULL;

ALTER TABLE tournament_results
    ADD COLUMN tournament_player_id UUID REFERENCES tournament_players(id) ON DELETE CASCADE,
    ADD COLUMN division_code      VARCHAR(8),
    ADD COLUMN prize_title        VARCHAR(120),
    ADD COLUMN playing_handicap   INTEGER,
    ADD COLUMN net_score          INTEGER,
    -- Net against par, after the floor: the number the prize is actually
    -- decided on, kept so a published result can be re-read without re-running
    -- the rules that produced it.
    ADD COLUMN judging_score      INTEGER,
    ADD COLUMN daily_cap_adjustment INTEGER,
    ADD COLUMN eagle_count        INTEGER,
    ADD COLUMN tied_unresolved    BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN tournament_results.judging_score IS
    'Net relative to par after the outing rules'' floor — the number the prize was decided on';
COMMENT ON COLUMN tournament_results.tied_unresolved IS
    'Every configured tie-break came out level; the organisers had to choose';

CREATE INDEX idx_tournament_result_division
    ON tournament_results(tournament_id, division_code, rank);
