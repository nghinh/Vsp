-- Vietnam golf roster: courses that exist but nobody has located.
--
-- The OSM pass (seed_courses_vn_osm.sql) can only add a course OSM has drawn.
-- It has drawn about half of them. This file adds the rest of the operating
-- courses found in public sources — the Vietnam Golf Association's members,
-- the bookable-club directories, operator announcements — and gives them the
-- one thing that is actually known about them: a name, a province, and how
-- many holes they have.
--
-- NO COORDINATES. That is the point of the file, not an omission.
--
--   A row here has `location IS NULL`, and null travels all the way to the
--   phone: the API omits latitude/longitude, the client models them as
--   nullable, and the course lists with no distance beside it. The alternative
--   — the two-decimal-place guess the original nationwide seed used — put
--   facilities up to 18 km from where they are, and the app computes the
--   distances it shows a golfer from exactly those numbers.
--
--   A golfer who knows the name can still find the course, pick it, and score
--   a round on it. What they cannot do is be told a distance nobody knows.
--
-- NO HOLES EITHER. `holes.par` is NOT NULL, so a hole row cannot be written
-- without inventing a par, and eighteen invented pars is a scorecard for a
-- course nobody has seen. Courses here therefore carry no `holes` rows at all.
-- Scoring does not need them — a round numbers its own holes — and the map tab
-- shows the unsurveyed view, which is the truth.
--
--   `courses.par_total` is NOT NULL as well, and 72 is written there for the
--   18-hole courses. That IS an assumption, and the only one in this file.
--   It is the near-universal total for a full-length 18 and it is stamped
--   D_UNVERIFIED_COMMUNITY like everything else.
--
-- COVERAGE
--   19 operating courses were found missing from the 55. Six of them OSM has
--   drawn, and those are handled in seed_courses_vn_osm.sql where a real
--   coordinate comes with them. The 13 below are the ones OSM has never
--   mapped: Lào Cai, Yên Bái, Phú Thọ and Thái Nguyên in particular have no
--   golf mapping at all.
--
--   That makes 74 operating courses. The "roughly a hundred" figure that gets
--   quoted counts approved projects, not playable courses; the eight found
--   under construction are deliberately not in this file, because a course you
--   cannot play is not a course you can pick. They are listed in
--   docs/vn-golf-roster-review.md.
--
-- Addresses are commune-level where a source states one, province-level where
-- none does. A coarse address is not a fabrication; a wrong district is.
--
-- Idempotent: a facility already present by name is skipped.

DO $$
DECLARE
    fid   BIGINT;
    added INT := 0;
    -- [name, address, holes]
    facilities CONSTANT TEXT[][] := ARRAY[
      -- ── North-west and midlands: no OSM golf mapping whatsoever ──────────
      ARRAY['Sapa Grand Golf Course','Bát Xát, Lào Cai','18'],
      ARRAY['Yên Bái Star Golf & Resort','Trấn Yên, Yên Bái','27'],
      ARRAY['Văn Lang Empire T&T Golf Club','Tam Nông, Phú Thọ','18'],
      ARRAY['Glory Golf Club','Phổ Yên, Thái Nguyên','9'],
      -- ── Bắc Giang: two courses opened 2023-2024 ──────────────────────────
      -- Stone Highland (Bắc Giang) is not Stone Valley (Hà Nam, already row
      -- 20). Different provinces, different courses, similar names.
      ARRAY['Stone Highland Golf & Resort','Việt Yên, Bắc Giang','18'],
      ARRAY['Corn Hill Golf & Resort','Lục Nam, Bắc Giang','18'],
      -- ── North-east and north-central ─────────────────────────────────────
      ARRAY['Silk Path Đông Triều Golf & Country Club','Đông Triều, Quảng Ninh','18'],
      ARRAY['Montaña Golf Club','Kỳ Sơn, Hòa Bình','18'],
      ARRAY['Blue Diamond Golf Links','Đồng Hới, Quảng Bình','18'],
      ARRAY['Golden Sands Golf Resort','Phú Vang, Thừa Thiên Huế','18'],
      -- ── South-central and south ──────────────────────────────────────────
      ARRAY['ANARA Bình Tiên Golf Club','Thuận Bắc, Ninh Thuận','18'],
      ARRAY['Vinpearl Golf Léman Củ Chi','Củ Chi, TP. Hồ Chí Minh','18'],
      ARRAY['Eschuri Vũng Bầu Golf','Phú Quốc, Kiên Giang','27']
    ];
BEGIN
    FOR i IN 1 .. array_length(facilities, 1) LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM golf_facilities WHERE name = facilities[i][1]);

        INSERT INTO golf_facilities
            (name, address, phone, website, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1], facilities[i][2], NULL, NULL, NULL,
             'D_UNVERIFIED_COMMUNITY','UNVERIFIED',10.0,'roster:name-only',
             'VSP Roster (public sources)','internal-roster',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO fid;

        INSERT INTO courses
            (name, facility_id, holes_count, par_total, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1] || ' — Championship', fid,
             facilities[i][3]::int,
             -- The one assumption in this file. A nine-hole course is a 36.
             CASE WHEN facilities[i][3]::int <= 9 THEN 36 ELSE 72 END,
             NULL,
             'D_UNVERIFIED_COMMUNITY','UNVERIFIED',10.0,'roster:name-only',
             'VSP Roster (public sources)','internal-roster',
             CURRENT_DATE, 1, now(), now());

        added := added + 1;
    END LOOP;

    RAISE NOTICE 'added % name-only facilities', added;
END $$;

SELECT (SELECT count(*) FROM golf_facilities) AS facilities,
       (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM golf_facilities WHERE location IS NULL) AS location_unknown,
       (SELECT count(*) FROM golf_facilities
         WHERE source = 'seed:approximate-facility-point') AS still_on_a_guess;
