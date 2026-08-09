-- Birdies and eagles, when nobody typed the holes.
--
-- The fast way to run prize-giving is to enter one number per golfer — the
-- round's gross — and rank off that. It is the difference between 44 numbers
-- and 792, and it is enough for every group prize: net is gross minus
-- handicap, and the countback only matters when two players tie.
--
-- What it is not enough for is "Golfer đạt điểm birdies, eagle sẽ có phần
-- thưởng từ BTC". A birdie count can be derived from eighteen hole scores and
-- from nothing else, so on the fast path it has to be typed — the flights read
-- theirs off the card as they hand it in.
--
-- Derived counts still win where the holes are present; these are the fallback,
-- not an override. See OutingScoring.birdies.

ALTER TABLE tournament_players
    ADD COLUMN birdie_count INTEGER,
    ADD COLUMN eagle_count  INTEGER;

COMMENT ON COLUMN tournament_players.birdie_count IS
    'Birdies as reported, for a card entered as a total only. Ignored when all '
    'hole scores are present — those are counted instead.';
COMMENT ON COLUMN tournament_players.eagle_count IS
    'Eagles as reported. Same fallback rule as birdie_count.';
