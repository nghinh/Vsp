-- What a golfer learned on a hole, kept for the next time they stand on it.
--
-- The scores are already here — score_entries knows every stroke on every
-- hole of every round. What has never been kept is the reason: "driver runs
-- out into the ditch, 3-wood is plenty", "green falls hard back-to-front",
-- "the pin is never as close as it looks". A golfer works that out on the
-- fourth tee and has forgotten it by the next visit.
--
-- Deliberately per golfer, not per course. This is not a course description
-- somebody publishes; it is one player's own book, and two players standing
-- on the same tee have different notes because they hit the ball differently.
--
-- Several notes on the same hole is the point rather than a flaw: what a
-- golfer wrote in March and what they wrote in August is a record of them
-- learning the hole, and the app shows the recent ones together.

CREATE TABLE hole_notes (
    id                  BIGSERIAL PRIMARY KEY,
    golfer_account_id   BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,
    course_id           BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,

    -- The hole as this course numbers it. A round of two nines carries hole
    -- 12, which is the back nine's hole 3 — the app resolves that before it
    -- gets here, so a note always belongs to the đường that holds the hole.
    hole_number         INTEGER NOT NULL CHECK (hole_number BETWEEN 1 AND 18),

    note                TEXT NOT NULL CHECK (length(trim(note)) > 0),

    -- Which round it was written during, where it was written during one.
    -- Null for a note added from the strategy page between rounds.
    round_id            UUID REFERENCES rounds(id) ON DELETE SET NULL,

    deleted_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The only read there is: this golfer, this hole, newest first.
CREATE INDEX idx_hole_notes_golfer_hole
    ON hole_notes (golfer_account_id, course_id, hole_number, created_at DESC)
    WHERE deleted_at IS NULL;

COMMENT ON TABLE hole_notes IS
    'One golfer''s own notes on a hole. Not a course description — two players on the same tee keep different notes.';
COMMENT ON COLUMN hole_notes.round_id IS
    'The round it was written during, where there was one. Null for a note added between rounds.';
