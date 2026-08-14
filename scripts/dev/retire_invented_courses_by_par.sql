-- Retire the seed's invented courses, and stop the labels lying about them.
--
-- WHAT WENT WRONG WITH THE FIRST ATTEMPT
--
--   retire_invented_championship_holes.sql deletes hole rows whose source is
--   exactly 'synthetic:seed-arithmetic'. By the time it ran, the OpenStreetMap
--   importer had already overwritten `source` on many of those same rows with
--   'osm:way/N' — and `publisher` with 'OpenStreetMap contributors', and
--   `confidence` with 60. So the filter missed them and five facilities kept
--   offering the invented course beside their real ones:
--
--     BRG Kings Island — Championship   18 holes, beside Kings/Mountain View/Lakeside
--     Sky Lake — Championship            1 hole,  beside Sky and Lake
--     Twin Doves — Championship          9 holes, beside Luna/Stella/Sole
--     Sông Bé — Championship             9 holes, beside Lotus/Palm/Desert
--     Đồng Nai — Championship            9 holes, beside đường A/B/C
--
--   `playable` is computed from whether a course has any holes, so all five
--   were offered in the round-setup picker and returned by search. Sky Lake's
--   is the strangest: a course announcing 18 holes with one hole row.
--
-- WHY THIS DOES NOT DELETE ANYTHING
--
--   Those 46 hole rows carry real measured coordinates from OSM, and none of
--   them appears on any other course at the same club — checked, the overlap is
--   zero. Deleting them to hide the course would throw away 46 surveyed points
--   that exist nowhere else, to solve a problem about what a picker offers.
--
--   The coordinates are real; they are attached to the wrong course, because
--   when the importer ran the invented course was the only one there. Matching
--   them to the right đường is a separate job and wants its own evidence. Until
--   then they are kept.
--
--   So the course is retired by expiry_date instead — a column the schema
--   already has, on the same metadata block as source and publisher, and used
--   by nothing until now. CourseSearchRepository excludes an expired course
--   from search and from the picker.
--
-- WHY THE PAR FINGERPRINT AND NOT `source`
--
--   Because `source` is the thing that turned out to be unreliable. The seed
--   wrote one par card onto every facility it created — 4,5,4,3,4,4,5,3,4 and
--   its nine-hole half — and no two real courses share that. It is the only
--   marker the OSM importer did not overwrite.
--
-- AND THE LABELS
--
--   63 holes across five courses read 'osm:way/N' while their par is the
--   seed's invention. That is not a small imprecision: it is the row claiming
--   provenance it does not have for the number a golfer scores against. They
--   are relabelled to say both things, so the honest count of invented holes is
--   171 rather than the 108 the source column admits to.
--
-- USAGE
--
--   ssh ubuntu-docker "docker exec -i vsp-postgres psql -U vsp -d vsp \
--     -v ON_ERROR_STOP=1" < scripts/dev/retire_invented_courses_by_par.sql

\set ON_ERROR_STOP on

BEGIN;

-- ─── The seed's own par card, as a fingerprint ──────────────────────────────

CREATE TEMP VIEW seeded AS
SELECT h.course_id
FROM holes h
GROUP BY h.course_id
HAVING string_agg(h.par::text, ',' ORDER BY h.hole_number) IN (
    '4,5,4,3,4,4,5,3,4,4,4,3,5,4,4,3,4,5',
    '4,5,4,3,4,4,5,3,4'
);

-- ─── 1. Say what the row actually is ────────────────────────────────────────
-- The geometry came from OSM and the par did not. One column, two facts, and
-- until now it told only the flattering one.

UPDATE holes h
   SET source     = 'synthetic:seed-arithmetic par; ' || h.source || ' geometry',
       confidence = 5.00,
       updated_at = now(),
       version    = h.version + 1
  FROM seeded s
 WHERE s.course_id = h.course_id
   AND h.source LIKE 'osm:%';

-- ─── 2. Retire the invented course where the club has a real one ────────────
-- Only where a real unit exists to play instead. Seven clubs carry the seed's
-- par card and have nothing else at all — Yên Dũng, Mường Thanh, Xuân Thành,
-- PGA Ocean, Vinpearl Hải Phòng, Royal Long An, Tuần Châu. Retiring theirs
-- would leave those clubs with no playable course, which is worse than
-- offering an honest-labelled guess.

UPDATE courses c
   SET expiry_date = CURRENT_DATE,
       updated_at  = now()
 WHERE c.id IN (SELECT course_id FROM seeded)
   AND c.name LIKE '%— Championship'
   AND c.expiry_date IS NULL
   AND EXISTS (
        SELECT 1 FROM courses real_one
        JOIN holes rh ON rh.course_id = real_one.id
        WHERE real_one.facility_id = c.facility_id
          AND real_one.id <> c.id
          AND rh.source NOT LIKE 'synthetic%');

-- ─── 3. Make a course's stated shape match its rows ─────────────────────────
-- holes_count and par_total are served straight to the app. Four courses
-- announced 18 holes over 9 or 1 rows, and five disagreed with the sum of
-- their own pars — Long Thành said 72 against 71. A course with no rows at all
-- keeps what it says: that is a course waiting for a card, not a wrong number.

UPDATE courses c
   SET holes_count = counted.n,
       par_total   = counted.par,
       updated_at  = now()
  FROM (SELECT course_id, count(*) AS n, sum(par) AS par
          FROM holes GROUP BY course_id) counted
 WHERE counted.course_id = c.id
   AND (c.holes_count IS DISTINCT FROM counted.n
        OR c.par_total IS DISTINCT FROM counted.par);

-- ─── What changed ───────────────────────────────────────────────────────────

SELECT f.name || ' / ' || c.name AS retired,
       (SELECT count(*) FROM holes h WHERE h.course_id = c.id) AS holes_kept,
       (SELECT count(*) FROM holes h
         WHERE h.course_id = c.id AND h.teeing_ground_location IS NOT NULL)
           AS coordinates_kept
FROM courses c JOIN golf_facilities f ON f.id = c.facility_id
WHERE c.expiry_date = CURRENT_DATE
ORDER BY f.name;

SELECT count(*) AS holes_now_labelled_as_seeded_par
FROM holes WHERE source LIKE 'synthetic:seed-arithmetic par;%';

COMMIT;

-- ─── Sky Lake, which the fingerprint cannot reach ───────────────────────────
--
-- Its Championship row is down to a single hole, so there is no par sequence
-- left to recognise: one hole of par 4 is not a card, it is what survived the
-- first retirement deleting the rows whose source had not been overwritten.
--
-- Retired on what is left rather than on what it was: a course announcing
-- itself beside Sky Course and Lake Course, both real eighteens, while holding
-- one hole. Its one measured coordinate is kept, like the other forty-five.

\set ON_ERROR_STOP on

BEGIN;

UPDATE courses c
   SET expiry_date = CURRENT_DATE,
       updated_at  = now()
 WHERE c.name LIKE '%— Championship'
   AND c.expiry_date IS NULL
   AND (SELECT count(*) FROM holes h WHERE h.course_id = c.id) BETWEEN 1 AND 8
   AND EXISTS (
        SELECT 1 FROM courses real_one
        JOIN holes rh ON rh.course_id = real_one.id
        WHERE real_one.facility_id = c.facility_id
          AND real_one.id <> c.id
          AND rh.source NOT LIKE 'synthetic%'
        GROUP BY real_one.id
        HAVING count(rh.id) >= 9);

SELECT f.name || ' / ' || c.name AS retired_as_a_fragment,
       (SELECT count(*) FROM holes h WHERE h.course_id = c.id) AS holes_kept
FROM courses c JOIN golf_facilities f ON f.id = c.facility_id
WHERE c.expiry_date = CURRENT_DATE
  AND (SELECT count(*) FROM holes h WHERE h.course_id = c.id) BETWEEN 1 AND 8;

COMMIT;
