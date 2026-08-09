-- Remove the QA fixtures left behind by manual portal testing.
--
-- WHY THIS IS A SCRIPT AND NOT THREE CURL CALLS
--   Deleting a facility deletes everything under it, and the ids differ in
--   every database. A snippet pasted into a console names ids; this names
--   fixtures, prints what it matched before touching anything, and can be run
--   twice with no second effect. That is the difference between a cleanup and
--   an incident.
--
-- WHAT IT DELETES
--   Facilities whose name marks them as test data — the portal sweep on
--   2026-08-09 created "Sân thử nghiệm QA" (later renamed "… (đã sửa)" while
--   exercising the edit form) with one course, "Sân thử — Course A2", and its
--   eighteen holes.
--
--   It deletes holes, then courses, then the facility, explicitly.
--
--   The migrations declare ON DELETE CASCADE on both foreign keys, so one
--   delete on golf_facilities ought to be enough — and in a Flyway-built
--   database it is. It is not enough here. The dev profile disables Flyway and
--   lets Hibernate build the schema from the entities, and Hibernate writes a
--   plain foreign key: the live constraint is named fklhuy36i0kt0gs6owjsxud33ee
--   and has no cascade. Relying on the cascade fails against exactly the
--   database this script is written for, so it does not rely on it. Deleting
--   in order works under both schemas.
--
-- SAFETY
--   Dev only. It matches on names no production facility would carry, refuses
--   to run if that pattern would take more than a handful of rows, and reports
--   what it removed. It does not touch anything created by the seed scripts —
--   those are named after real clubs.
--
-- Usage, against the local dev database the API defaults to:
--
--   psql -h localhost -p 5432 -d vsp -f scripts/dev/cleanup_qa_fixtures.sql
--
-- Step 1 prints the matches; if they are not what you expect, Ctrl-C before
-- the commit and nothing is lost.

\set ON_ERROR_STOP on

BEGIN;

-- ── 1. Show what matches, before anything is removed ────────────────────────
SELECT
    f.id            AS facility_id,
    f.name          AS facility_name,
    count(DISTINCT c.id) AS courses,
    count(h.id)     AS holes
FROM golf_facilities f
LEFT JOIN courses c ON c.facility_id = f.id
LEFT JOIN holes   h ON h.course_id   = c.id
WHERE f.name ILIKE 'Sân thử%'
   OR f.name ILIKE '%thử nghiệm QA%'
GROUP BY f.id, f.name
ORDER BY f.id;

-- ── 2. Refuse a run that would take more than the known fixtures ────────────
DO $$
DECLARE
    doomed BIGINT;
BEGIN
    SELECT count(*) INTO doomed
    FROM golf_facilities
    WHERE name ILIKE 'Sân thử%' OR name ILIKE '%thử nghiệm QA%';

    IF doomed = 0 THEN
        RAISE NOTICE 'Nothing to clean up — no QA fixtures matched.';
    ELSIF doomed > 5 THEN
        -- Someone has either renamed real data or widened the pattern. Either
        -- way a cleanup script is the wrong tool for whatever this is.
        RAISE EXCEPTION
            'Refusing to delete % facilities: that is more than this script expects. Check the names above.',
            doomed;
    ELSE
        RAISE NOTICE 'Removing % QA facility row(s) and everything beneath them.', doomed;
    END IF;
END $$;

-- ── 3. Delete children first, then the facility ─────────────────────────────
--
-- Every table below holds a foreign key into holes or courses, and in this
-- database not one of them cascades — the list was read from pg_constraint
-- rather than guessed, after two runs failed on tables nobody had thought of.
-- If a new child table appears, this will fail loudly on it rather than leave
-- an orphan, which is the right way round.
CREATE TEMP TABLE doomed_facilities ON COMMIT DROP AS
SELECT id FROM golf_facilities
WHERE name ILIKE 'Sân thử%' OR name ILIKE '%thử nghiệm QA%';

CREATE TEMP TABLE doomed_courses ON COMMIT DROP AS
SELECT id FROM courses WHERE facility_id IN (SELECT id FROM doomed_facilities);

CREATE TEMP TABLE doomed_holes ON COMMIT DROP AS
SELECT id FROM holes WHERE course_id IN (SELECT id FROM doomed_courses);

-- Hole geometry and per-hole operations
DELETE FROM bunkers                 WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM cart_paths              WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM fairway_segments        WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM greens                  WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM landmarks               WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM out_of_bounds           WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM penalty_areas           WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM tee_boxes               WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM water_hazards           WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM green_conditions        WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM pin_positions           WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM pin_positions_ops       WHERE hole_id IN (SELECT id FROM doomed_holes);
DELETE FROM draft_geometry_features WHERE hole_id IN (SELECT id FROM doomed_holes);

DELETE FROM holes WHERE id IN (SELECT id FROM doomed_holes);

-- Course-level children
DELETE FROM course_conditions       WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM course_conditions_ops   WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM data_versions           WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM draft_geometry_features WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM favorite_courses        WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM recent_courses          WHERE course_id IN (SELECT id FROM doomed_courses);
DELETE FROM tee_sets                WHERE course_id IN (SELECT id FROM doomed_courses);

DELETE FROM courses WHERE id IN (SELECT id FROM doomed_courses);
DELETE FROM golf_facilities WHERE id IN (SELECT id FROM doomed_facilities);

-- ── 4. Confirm ──────────────────────────────────────────────────────────────
SELECT count(*) AS qa_facilities_remaining
FROM golf_facilities
WHERE name ILIKE 'Sân thử%'
   OR name ILIKE '%thử nghiệm QA%';

COMMIT;
