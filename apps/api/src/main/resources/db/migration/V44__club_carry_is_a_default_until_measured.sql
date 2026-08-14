-- Say whether a club's carry distance is this golfer's or a starting point.
--
-- WHY THIS COLUMN EXISTS
--
--   A new golfer's bag is now filled with a standard fourteen so they can get
--   club advice on their first round instead of typing fourteen numbers before
--   the app is any use. That is a real improvement and it carries a real risk:
--   once written, "IRON 128 m" from a table looks exactly like "IRON 128 m"
--   the golfer measured on a range.
--
--   The club-selection advice is only as good as those numbers. A golfer who
--   never edits them is being advised on somebody else's swing, and neither
--   the advice nor the screen would have any way to say so. That is the same
--   failure this project has already paid for once with scorecards: a
--   plausible number nobody can tell apart from a measured one.
--
--   So the flag is the point of the feature, not an afterthought. It lets the
--   app mark the clubs still on standard distances, and lets the advice say
--   what it is built on.
--
--   Cleared the moment a golfer edits the carry — see BagServiceImpl — because
--   from then on the number is theirs.
--
-- EXISTING ROWS
--
--   False. Every club already in the database was typed by a golfer, so it is
--   theirs by definition, and defaulting to true would relabel real
--   measurements as guesses.

ALTER TABLE clubs
    ADD COLUMN IF NOT EXISTS carry_is_default boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN clubs.carry_is_default IS
    'True while carry_distance is the seeded standard rather than this golfer''s own. Cleared on edit.';
