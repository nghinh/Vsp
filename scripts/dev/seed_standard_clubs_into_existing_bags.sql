-- Fill the bags that already exist with the standard fourteen.
--
-- New bags get the set from BagServiceImpl.createDefaultBag. Every bag created
-- before that existed has whatever the golfer typed, which on this deployment
-- is between nothing and three clubs — and a bag of one driver produces club
-- advice that recommends the driver for the approach as well.
--
-- ADDITIVE, NEVER OVERWRITING
--
--   A standard club is inserted only where the bag has nothing of that type
--   and loft already. So admin's DRIVER 10.5° at 240 m stays at 240 — it is
--   theirs, they typed it — and the thirteen clubs they do not have are added
--   around it.
--
--   That matters more than it looks. Overwriting would replace a measured
--   distance with a table's, silently, and the golfer would have no way to
--   tell it had happened.
--
--   A club with no loft on file (nghinh's DRIVER, nguyenhongnghi's second
--   iron) is matched on type alone for DRIVER and PUTTER, of which a bag holds
--   one, and left alone otherwise: two irons at unknown lofts are two irons,
--   and guessing which they are would be inventing the golfer's bag.
--
-- EVERY SEEDED CARRY IS FLAGGED
--
--   carry_is_default = true, so the app can say the club advice is built on
--   standard numbers, and BagServiceImpl clears the flag the moment the golfer
--   edits the carry. Without the flag a seeded 128 m is indistinguishable from
--   a measured one, which is the whole risk of doing this at all.
--
-- USAGE
--
--   ssh ubuntu-docker "docker exec -i vsp-postgres psql -U vsp -d vsp \
--     -v ON_ERROR_STOP=1" < scripts/dev/seed_standard_clubs_into_existing_bags.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE standard(club_type text, loft numeric, carry numeric)
ON COMMIT DROP;
INSERT INTO standard VALUES
    ('DRIVER', 10.5, 200),
    ('WOOD',   15.0, 185),
    ('WOOD',   18.0, 172),
    ('HYBRID', 21.0, 163),
    ('IRON',   24.0, 155),
    ('IRON',   27.0, 146),
    ('IRON',   30.0, 137),
    ('IRON',   34.0, 128),
    ('IRON',   38.0, 117),
    ('IRON',   42.0, 106),
    ('WEDGE',  46.0,  95),
    ('WEDGE',  50.0,  84),
    ('WEDGE',  54.0,  70),
    -- A putter carries nothing; giving it a distance would put it in the
    -- running for an approach shot.
    ('PUTTER',  3.0,   0);

INSERT INTO clubs (golf_bag_id, club_type, loft, carry_distance, carry_is_default,
                   created_at, updated_at)
SELECT b.id, s.club_type, s.loft,
       NULLIF(s.carry, 0),
       s.carry > 0,
       now(), now()
FROM golf_bags b
CROSS JOIN standard s
WHERE NOT EXISTS (
    SELECT 1 FROM clubs c
    WHERE c.golf_bag_id = b.id
      AND c.club_type = s.club_type
      AND (
            -- Same club, by loft.
            (c.loft IS NOT NULL AND abs(c.loft - s.loft) <= 2.0)
            -- A bag holds one driver and one putter, so a lofted-unknown one
            -- of those is still that club.
            OR (c.loft IS NULL AND s.club_type IN ('DRIVER', 'PUTTER'))
      ));

SELECT a.email,
       count(*) FILTER (WHERE NOT c.carry_is_default) AS their_own,
       count(*) FILTER (WHERE c.carry_is_default)     AS standard_added,
       count(*)                                       AS clubs_now
FROM golf_bags b
JOIN clubs c ON c.golf_bag_id = b.id
LEFT JOIN golfer_accounts a ON a.id = b.golfer_account_id
GROUP BY b.id, a.email
ORDER BY a.email;

COMMIT;
