-- Tell the truth about seeded course geometry.
--
-- Run once against an existing dev database:
--   docker exec -i vsp_postgres psql -U vsp -d vsp < scripts/dev/relabel_synthetic_geometry.sql
--
-- Idempotent: every statement is keyed on the labels it is replacing, so a
-- second run is a no-op. Fresh databases do not need it — the seed scripts now
-- write these labels themselves. It lives here rather than in db/migration
-- because dev runs on the Hibernate entity schema with Flyway disabled, and
-- the Flyway schema is a different one (UUID keys, VARCHAR geometry, a
-- separate data_quality_metadata table).
--
-- scripts/dev/seed_courses*.sql invents every hole: the tee is the clubhouse
-- point pushed (hole_number * 0.0008, hole_number * 0.0006) degrees, and the
-- green is that tee pushed exactly playing_length_meters / 111000 degrees due
-- north. Every seeded hole therefore runs on a bearing of exactly 0.00°, and
-- all 50 seeded courses share one identical par/length card. None of that was
-- ever observed on a satellite image, yet the rows claimed
-- accuracy_class = C_VERIFIED_SATELLITE, verification_status = VERIFIED and
-- confidence 95. The app computes every distance it shows a golfer from those
-- points, and a golfer picks a club from the distance.
--
-- The derived fairway corridors and green extents built on top of these points
-- were already labelled D_UNVERIFIED_COMMUNITY. The points underneath them —
-- the ones the numbers actually come from — were not. This script makes the
-- labels match reality.
--
-- Two scales were also in use in the confidence column, which the entity
-- contract (DataQualityMetadata) and the portal both read as a percentage
-- 0.00-100.00: the seed wrote 95, the OSM importer wrote 0.60 meaning "60%",
-- which the portal rendered as 1%. Everything is put on the documented
-- percentage scale here so the column means one thing.

-- ─── 1. Facility and course clubhouse points ────────────────────────────────
-- Hand-typed approximate coordinates for a real place. Useful for "courses
-- near me", not a survey.

UPDATE golf_facilities
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 30.00,
       source              = 'seed:approximate-facility-point',
       publisher           = 'VSP Seed (approximate)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now()
 WHERE source = 'SEED';

UPDATE courses
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 30.00,
       source              = 'seed:approximate-facility-point',
       publisher           = 'VSP Seed (approximate)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now()
 WHERE source = 'SEED';

-- ─── 2. Hole tee/green points ───────────────────────────────────────────────
-- The rows this migration exists for. Matched on provenance *and* on the
-- geometric fingerprint of the generator (tee and green share a longitude, so
-- the hole runs due north), so a row that only claims to be seeded is not
-- relabelled and a genuinely surveyed row can never be caught by accident.

UPDATE holes
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 5.00,
       source              = 'synthetic:seed-arithmetic',
       publisher           = 'VSP Seed (synthetic)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now(),
       version             = version + 1
 WHERE source = 'SEED'
   AND teeing_ground_location IS NOT NULL
   AND green_location IS NOT NULL
   AND ST_X(teeing_ground_location) = ST_X(green_location);

-- A seeded hole with no points at all is still not satellite-verified.
UPDATE holes
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 5.00,
       source              = 'synthetic:seed-arithmetic',
       publisher           = 'VSP Seed (synthetic)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now(),
       version             = version + 1
 WHERE source = 'SEED';

-- ─── 3. Tee sets ────────────────────────────────────────────────────────────
-- Three invented names per course carrying no yardages of their own.

UPDATE tee_sets
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 5.00,
       source              = 'synthetic:seed-arithmetic',
       publisher           = 'VSP Seed (synthetic)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now()
 WHERE source = 'SEED';

-- ─── 4. Data versions ───────────────────────────────────────────────────────
-- This is the row the mobile freshness/quality badge reads. It said VERIFIED
-- and carried a last_verified_at of the moment the seed ran — nobody verified
-- anything. status stays PUBLISHED: the version is genuinely the published one
-- and clearing it would hide the course from search rather than qualify it.

UPDATE data_versions
   SET accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
       verification_status = 'UNVERIFIED',
       confidence          = 5.00,
       source              = 'synthetic:seed-arithmetic',
       publisher           = 'VSP Seed (synthetic)',
       license             = 'internal-synthetic',
       last_verified_at    = NULL,
       updated_at          = now()
 WHERE source = 'SEED';

-- ─── 5. Confidence onto one scale ───────────────────────────────────────────
-- The OSM importer's 0.60 / 0.55 / 0.20 were fractions written into a column
-- everything else reads as a percentage. tools/course-digitization/osm/
-- build_from_osm.py now writes 60 / 55 / 20 directly; these are the rows it
-- already wrote.

UPDATE holes            SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE golf_facilities  SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE courses          SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE greens           SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE fairway_segments SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE bunkers          SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;
UPDATE water_hazards    SET confidence = confidence * 100 WHERE confidence > 0 AND confidence <= 1;

-- ─── 6. One length per hole, and it comes from the coordinates ──────────────
-- Two numbers described every hole and they disagreed. playing_length_meters
-- came from the seed's arithmetic card (identical on all 50 courses); the
-- coordinates came — on 61 holes — from a real OpenStreetMap golf=hole
-- centreline. Long Thành hole 2 was stated 488 m and its real points are 377 m
-- apart. The app measures from the coordinates, so the coordinates win and the
-- stated length is rebuilt from them.
--
-- For a hole with a real OSM centreline the length is the length of that line,
-- not the straight line between its ends: a dogleg genuinely plays longer than
-- tee-to-green, and osm_hole_match.osm_len_m is that same real geometry
-- measured along the way it is walked.

-- osm_hole_match is created by that tool, not by a migration, so a database
-- that has never run it simply has no OSM holes to correct.
DO $$
BEGIN
    IF to_regclass('public.osm_hole_match') IS NOT NULL THEN
        UPDATE holes h
           SET playing_length_meters = round(m.osm_len_m::numeric, 2),
               updated_at            = now()
          FROM osm_hole_match m
         WHERE m.db_hole_id = h.id
           AND h.source LIKE 'osm:%'
           AND h.verification_status <> 'VERIFIED'
           AND h.playing_length_meters IS DISTINCT FROM round(m.osm_len_m::numeric, 2);
    END IF;
END $$;

-- Synthetic holes: the stated length and the generated points differ by up to
-- ~1.9 m because 1° of latitude is not exactly 111 km. Same fiction, told
-- twice, slightly differently. Make the one number the app measures the one
-- number it states.
UPDATE holes
   SET playing_length_meters =
           round(ST_Distance(teeing_ground_location::geography,
                             green_location::geography)::numeric, 2),
       updated_at = now()
 WHERE verification_status <> 'VERIFIED'
   AND teeing_ground_location IS NOT NULL
   AND green_location IS NOT NULL
   AND (source = 'synthetic:seed-arithmetic' OR source = 'derived:facility-offset');
