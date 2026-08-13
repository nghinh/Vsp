-- Publish a data version for every course that now holds measured geometry.
--
-- WHY THIS IS NEEDED
--
--   917 holes carry real tee and green points, read off mscorecard's map
--   editor and checked against the club's own printed yardage. Three of the
--   four things that read hole geometry consult the table directly and see
--   them already: the portal's geometry review, the admin hole editor, and the
--   shot dispersion overlay.
--
--   The fourth is the one a golfer actually looks at. The hole map reads only
--   a downloaded course package, a package is built from a published data
--   version, and 44 of the 70 courses with measured holes have never had a
--   version at all — versions are created by the import flow, and these
--   courses were seeded rather than imported.
--
--   So the coordinates are in the database and invisible on the course. This
--   is the row that closes that gap; the build is triggered per course
--   afterwards through the API, which is what actually assembles the files.
--
-- WHAT IT WRITES
--
--   One PUBLISHED version per course that has at least one hole whose geometry
--   came from the map editor, and does not already have a version. The
--   provenance fields describe that geometry rather than the seed's: source
--   names the map editor, and the accuracy class is the best any hole on the
--   course reached, so a course whose holes were corroborated against the card
--   says C_VERIFIED_SATELLITE and one whose holes are still unverified says D.
--
--   Nothing is overwritten. A course that already has a version keeps it — its
--   package build takes the version id it already had.
--
-- USAGE
--
--   ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
--     psql -U vsp -d vsp -v ON_ERROR_STOP=1" < scripts/dev/publish_versions_for_measured_courses.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE measured ON COMMIT DROP AS
SELECT h.course_id,
       -- The best class any hole on the course reached. A course is not more
       -- accurate than its holes, and claiming C for a course whose points
       -- nobody could check against a card would be the overclaim this whole
       -- exercise exists to remove.
       CASE WHEN bool_or(h.accuracy_class = 'C_VERIFIED_SATELLITE')
            THEN 'C_VERIFIED_SATELLITE' ELSE 'D_UNVERIFIED_COMMUNITY' END AS accuracy_class,
       CASE WHEN bool_or(h.verification_status = 'VERIFIED')
            THEN 'VERIFIED' ELSE 'UNVERIFIED' END AS verification_status,
       count(*) AS holes
FROM holes h
WHERE h.source LIKE 'mscorecard%map editor%'
  AND NOT EXISTS (SELECT 1 FROM data_versions v WHERE v.course_id = h.course_id)
GROUP BY h.course_id;

SELECT count(*) AS courses_to_publish, sum(holes) AS holes_covered FROM measured;

INSERT INTO data_versions (
    course_id, version_number, status,
    published_at, published_by, publish_note,
    created_at, updated_at,
    accuracy_class, confidence, effective_date, license, publisher,
    source, verification_status, version)
SELECT
    m.course_id, 1, 'PUBLISHED',
    now(), 'operator: coordinate load',
    'First measured geometry: tee and green points from mscorecard''s map '
      || 'editor, cross-checked against the club''s printed yardage.',
    now(), now(),
    m.accuracy_class,
    CASE WHEN m.accuracy_class = 'C_VERIFIED_SATELLITE' THEN 85.0 ELSE 60.0 END,
    CURRENT_DATE, 'community-contributed', 'mscorecard.com contributors',
    'mscorecard.com map editor; checked against the club''s card',
    m.verification_status, 1
FROM measured m;

SELECT count(*) AS versions_now FROM data_versions;

COMMIT;
