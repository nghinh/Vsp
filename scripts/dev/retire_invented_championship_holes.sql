-- Stop offering the seed's invented course at clubs whose real ones are loaded.
--
-- WHAT IS WRONG
--
--   The nationwide seed gave every facility one course, "<facility> —
--   Championship", with eighteen holes it invented: the same par card copied
--   onto fifty-eight courses and lengths computed from a guessed coordinate.
--
--   Since then the clubs' real structure has been loaded — Long Biên's đường A,
--   B and C off the club's own published card, Kings Island's three sân, Tân
--   Sơn Nhất's four. But the invented row is still there, still has its
--   eighteen holes, and still sorts first in the round-setup picker. A golfer
--   opening Long Biên sees "Long Biên Golf Course — Championship (18 hố)"
--   selected by default and starts a round on made-up pars, with the club's own
--   card sitting one line below.
--
-- WHAT THIS DOES
--
--   Deletes the synthetic hole rows from that Championship course, at the
--   fourteen facilities that have real holes on a real unit. Nothing else: the
--   course row stays, so any id pointing at it still resolves.
--
--   Removing the holes is what matters, because `playable` is computed from
--   whether a course has any. With none, course detail stops offering it in the
--   round-setup picker and search stops returning it — the two places a golfer
--   could have walked into it — while the scorecard screen still lists it, so a
--   card photographed for it can still be submitted.
--
--   Only rows whose source is exactly 'synthetic:seed-arithmetic' are touched.
--   A Championship row carrying a real card — Sono Belle's eighteen, say, which
--   is the club's actual championship layout — is left alone.
--
-- USAGE
--
--   ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
--     psql -U vsp -d vsp -v ON_ERROR_STOP=1" < scripts/dev/retire_invented_championship_holes.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE retiring ON COMMIT DROP AS
SELECT c.id AS course_id, f.name AS facility, c.name AS course
FROM courses c
JOIN golf_facilities f ON f.id = c.facility_id
WHERE c.name LIKE '%— Championship'
  AND EXISTS (
        SELECT 1 FROM holes h
        WHERE h.course_id = c.id AND h.source = 'synthetic:seed-arithmetic')
  -- and the club has a real unit to play instead
  AND EXISTS (
        SELECT 1 FROM courses c2
        JOIN holes h2 ON h2.course_id = c2.id
        WHERE c2.facility_id = f.id
          AND c2.name NOT LIKE '%— Championship'
          AND h2.source NOT LIKE 'synthetic%');

SELECT facility, course FROM retiring ORDER BY facility;

DELETE FROM holes
WHERE course_id IN (SELECT course_id FROM retiring)
  AND source = 'synthetic:seed-arithmetic';

SELECT count(*) AS facilities_retired FROM retiring;

COMMIT;
