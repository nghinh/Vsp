-- Whether a round counts toward the golfer's handicap, and what kind of round it was.
--
-- The app has offered Thường / Tập luyện / Giải đấu since the setup screen
-- existed, and the choice went nowhere: there was no column for it, the create
-- request never sent it, and the handicap this app computes counted every
-- round with nine or eighteen scored holes. A golfer who picked "Tập luyện"
-- was told their practice would not count, and it counted.
--
-- Two columns rather than one. The format is what the golfer chose and is
-- worth keeping on its own — a practice round is a different thing from a
-- casual one when reading a history back. Whether it counts is a separate
-- decision the golfer can change: a practice round defaults to not counting
-- and a casual one to counting, and either can be overridden on the setup
-- screen before the first tee.
--
-- Existing rows default to counting. They were already counting; changing
-- that retroactively would move every golfer's handicap for reasons none of
-- them could see.

ALTER TABLE rounds
    ADD COLUMN format VARCHAR(20) NOT NULL DEFAULT 'CASUAL',
    ADD COLUMN counts_toward_handicap BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE rounds
    ADD CONSTRAINT chk_round_format
        CHECK (format IN ('CASUAL', 'PRACTICE', 'TOURNAMENT'));

-- The handicap query reads completed, undeleted, counting rounds for one
-- golfer, newest first. Without this it is a sequential scan over every score
-- entry the platform holds.
CREATE INDEX idx_rounds_handicap_window
    ON rounds (golfer_account_id, created_at DESC)
    WHERE deleted_at IS NULL
      AND status = 'COMPLETED'
      AND counts_toward_handicap;

COMMENT ON COLUMN rounds.format IS
    'CASUAL, PRACTICE or TOURNAMENT — what the golfer chose on the setup screen.';
COMMENT ON COLUMN rounds.counts_toward_handicap IS
    'Whether this round feeds the app-computed handicap. Defaults from format, overridable by the golfer before the round starts.';
