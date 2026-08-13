-- Index the hole geometry columns themselves, not a lossy round trip of them.
--
-- WHAT WAS WRONG
--
--   V16 created both spatial indexes over an expression:
--
--     CREATE INDEX idx_holes_tee_location
--       ON holes USING GIST (ST_GeomFromWKB(teeing_ground_location::bytea));
--
--   Two things follow from that, and both are bad.
--
--   An expression index is only usable by a query written with the same
--   expression. No query in this codebase is — the comments above them say
--   "for golfer positioning queries" and "for tee selection queries", and
--   neither of those queries was ever written, so the indexes have never
--   served a single lookup. They are pure write cost.
--
--   And casting a geometry to bytea yields EWKB, which ST_GeomFromWKB accepts
--   but warns about, so every insert or update of either column logs two
--   WARNING lines. Loading 917 measured holes produced close to 1,900 of them,
--   which is enough noise to hide a real warning in the same log.
--
-- WHAT THIS DOES
--
--   Drops both and indexes the columns directly. A plain GiST index on a
--   geometry column is what ST_DWithin, ST_Intersects and the rest can
--   actually use, so the capability the original comments described becomes
--   available for the first time — at the same storage cost, minus the
--   warnings.

DROP INDEX IF EXISTS idx_holes_tee_location;
DROP INDEX IF EXISTS idx_holes_green_location;

CREATE INDEX idx_holes_tee_location ON holes USING GIST (teeing_ground_location);
CREATE INDEX idx_holes_green_location ON holes USING GIST (green_location);
