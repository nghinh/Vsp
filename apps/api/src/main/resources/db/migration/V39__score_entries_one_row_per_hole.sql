-- One score entry per hole, enforced by the database.
--
-- The sync endpoint reads `findByScoreIdAndHoleNumber` and inserts when it
-- finds nothing. That is correct in isolation and wrong under load: the phone
-- posts one request per tap, so two updates for the same hole can be in flight
-- at once, both find nothing, and both insert. A real round produced pairs of
-- rows for holes 10, 12, 13 and 15 within twenty seconds of each other.
--
-- Duplicates are not merely untidy. The two rows carry the strokes as they
-- stood at each moment, so once a golfer corrects a hole the pair disagrees and
-- the round total is whichever row a query happens to reach first.
--
-- `idx_score_entries_hole` already covers (score_id, hole_number); it just
-- never forbade a second row. Replacing it with a unique index costs nothing —
-- the lookup keeps its index — and turns the race into an error the service
-- can catch and retry as an update.

-- Collapse what is already there. The newest row wins: entries are only ever
-- written forward, so the latest updated_at is the golfer's latest word on
-- that hole.
DELETE FROM score_entries e
      USING score_entries newer
      WHERE e.score_id = newer.score_id
        AND e.hole_number = newer.hole_number
        AND (
              e.updated_at < newer.updated_at
           OR (e.updated_at = newer.updated_at AND e.id < newer.id)
        );

DROP INDEX IF EXISTS idx_score_entries_hole;

CREATE UNIQUE INDEX idx_score_entries_hole
    ON score_entries (score_id, hole_number);
