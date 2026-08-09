-- Vietnam golf roster: reconciliation against OpenStreetMap.
--
-- Two jobs, both of which exist because the nationwide seed
-- (seed_courses_vn.sql) had to invent facility coordinates:
--
--   1  RELOCATE. Seven facilities sit on a point somebody typed to two decimal
--      places from memory. OSM has a real boundary for each, so the point is
--      replaced with that boundary's centroid — and the eighteen synthetic
--      holes are translated by the same delta, because moving the clubhouse
--      and leaving the holes eight kilometres away would be worse than the
--      error it fixes. Some of these were out by 18 km.
--
--   2  ADD. Five courses OSM maps inside Vietnam that this database had never
--      heard of. Facility, course, eighteen holes, tee sets and a published
--      data version, exactly as the nationwide seed builds them.
--
-- WHY THE PAIRINGS ARE WRITTEN OUT BY HAND
--   The obvious implementation is name similarity plus a distance ceiling, and
--   it is wrong here. Folded to ASCII, "Sân Golf Đầm Vạc" and "Tam Đảo Golf
--   Resort" become "dam vac" and "tam dao" — 0.67 similar by pure coincidence
--   of letters, and 18 km apart, which passes a 25 km gate. Applied
--   automatically that pairing moves Tam Đảo to a lake in Vĩnh Yên. Đầm Vạc is
--   Heron Lake. Every pairing below was adjudicated one at a time and carries
--   the evidence that settled it; nothing here was decided by a threshold.
--
-- WHAT IS NOT CLAIMED
--   The coordinates become real. The eighteen holes underneath them stay
--   synthetic arithmetic and keep saying so — D_UNVERIFIED_COMMUNITY,
--   source 'synthetic:seed-arithmetic'. Real hole geometry arrives from
--   tools/course-digitization, which overwrites them where OSM has it.
--
--   This is also not the whole country. OSM maps 51 course-sized golf polygons
--   inside Vietnam; 35 carry a name. Sixteen are drawn but unnamed, and the
--   Vietnam Golf Association counts roughly a hundred operating courses. The
--   gap is real and is not closed here — see docs/vn-golf-roster-review.md.
--
-- ATTRIBUTION
--   Coordinates and boundaries are (c) OpenStreetMap contributors, ODbL-1.0.
--   Rows located from OSM carry that in source / publisher / license. Do not
--   strip it.
--
-- Idempotent. Relocation only touches rows still on a seeded point; a second
-- run finds none. Additions are skipped when the facility name already exists.

-- ── 1. Relocate facilities that are sitting on an invented point ────────────
DO $$
DECLARE
    r        RECORD;
    fid      BIGINT;
    dlon     DOUBLE PRECISION;
    dlat     DOUBLE PRECISION;
    moved    INT := 0;
    -- [facility name, osm ref, lon, lat, the evidence for the pairing]
    fixes CONSTANT TEXT[][] := ARRAY[
      ARRAY['Vietnam Golf & Country Club','osm:way/332139498','106.8246','10.8565',
            'OSM "Sân Golf Thủ Đức", 219.6 ha — the only 36-hole course in Thủ Đức'],
      ARRAY['Heron Lake Golf Course & Resort','osm:way/1023111557','105.6093','21.2955',
            'OSM "Sân Golf Đầm Vạc" — Heron Lake is the Đầm Vạc course at Vĩnh Yên'],
      ARRAY['Vinpearl Golf Nam Hội An','osm:way/1340528240','108.4110','15.7938',
            'OSM "Vin Pearl Golf Course" on the Nam Hội An coast'],
      ARRAY['Dalat Palace Golf Club','osm:way/99661171','108.4452','11.9479',
            'OSM "Sân Golf Đà Lạt", name:en "Dalat Golf Course", on Xuân Hương lake'],
      ARRAY['SAM Tuyền Lâm Golf & Resort','osm:way/473720748','108.4495','11.8794',
            'OSM "Sacom Golf Club" at Tuyền Lâm — SAM Holdings was Sacom'],
      ARRAY['PGA Ocean Golf Course NovaWorld','osm:relation/19324303','108.0272','10.8302',
            'OSM "NovaWorld Phan Thiết Golf Club"'],
      ARRAY['BRG Ruby Tree Golf Resort','osm:way/627899731','106.7778','20.7327',
            'unnamed 206 ha polygon containing the node "Sân Golf BRG Ruby Tree Hải Phòng"']
    ];
BEGIN
    FOR i IN 1 .. array_length(fixes, 1) LOOP
        -- Only a row still on a seeded guess. A facility somebody has since
        -- located properly, or verified, is left exactly as it is.
        SELECT id, ST_X(location::geometry), ST_Y(location::geometry)
          INTO fid, dlon, dlat
          FROM golf_facilities
         WHERE name = fixes[i][1]
           AND source = 'seed:approximate-facility-point';

        CONTINUE WHEN fid IS NULL;

        dlon := fixes[i][3]::float8 - dlon;
        dlat := fixes[i][4]::float8 - dlat;

        UPDATE golf_facilities
           SET location = ST_SetSRID(ST_MakePoint(fixes[i][3]::float8, fixes[i][4]::float8), 4326),
               source = fixes[i][2],
               publisher = 'OpenStreetMap contributors',
               license = 'ODbL-1.0',
               -- The point is now real and unreviewed, which is what
               -- PENDING_REVIEW means. The accuracy class does not improve:
               -- a boundary centroid is not a survey.
               verification_status = 'PENDING_REVIEW',
               accuracy_class = 'D_UNVERIFIED_COMMUNITY',
               updated_at = now(),
               version = version + 1
         WHERE id = fid;

        UPDATE courses
           SET location = ST_SetSRID(ST_MakePoint(fixes[i][3]::float8, fixes[i][4]::float8), 4326),
               updated_at = now()
         WHERE facility_id = fid;

        -- Translate the synthetic holes by the same delta. They stay fiction,
        -- but fiction next to the right course rather than fiction in the next
        -- province — the app frames its map on the hole, not the clubhouse.
        UPDATE holes h
           SET teeing_ground_location = ST_Translate(h.teeing_ground_location, dlon, dlat),
               green_location = ST_Translate(h.green_location, dlon, dlat),
               updated_at = now()
          FROM courses c
         WHERE h.course_id = c.id
           AND c.facility_id = fid
           AND h.source = 'synthetic:seed-arithmetic';

        moved := moved + 1;
    END LOOP;

    RAISE NOTICE 'relocated % facilities onto OSM coordinates', moved;
END $$;

-- ── 2. Add courses OSM maps in Vietnam that this database lacked ────────────
DO $$
DECLARE
    fid   BIGINT;
    cid   BIGINT;
    h     INT;
    p     INT;
    plen  NUMERIC;
    tlon  DOUBLE PRECISION;
    tlat  DOUBLE PRECISION;
    glat  DOUBLE PRECISION;
    added INT := 0;
    pars  INT[] := ARRAY[4,5,4,3,4,4,5,3,4, 4,4,3,5,4,4,3,4,5];
    -- [name, address, lon, lat, osm ref]
    -- Address is province-level where the coordinate does not pin the district
    -- beyond doubt. A wrong district is a fabrication; a coarse one is not.
    facilities CONSTANT TEXT[][] := ARRAY[
      ARRAY['Vinpearl Golf Hải Phòng','Vũ Yên, Hải Phòng','106.7304','20.8706','osm:way/1117837123'],
      ARRAY['Sân Golf Quốc tế Móng Cái','Móng Cái, Quảng Ninh','108.0523','21.4875','osm:way/149353388'],
      ARRAY['Cửa Lò Golf Resort','Cửa Lò, Nghệ An','105.7370','18.7830','osm:way/631990008'],
      ARRAY['Royal Long An Golf & Country Club','Long An','106.3376','10.7831','osm:way/1384279568'],
      ARRAY['Royal Island Golf & Villas','Bình Dương','106.7868','11.0257','osm:relation/16245589']
    ];
BEGIN
    FOR i IN 1 .. array_length(facilities, 1) LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM golf_facilities WHERE name = facilities[i][1]);

        INSERT INTO golf_facilities
            (name, address, phone, website, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1], facilities[i][2], NULL, NULL,
             ST_SetSRID(ST_MakePoint(facilities[i][3]::float8, facilities[i][4]::float8), 4326),
             'D_UNVERIFIED_COMMUNITY','PENDING_REVIEW',30.0, facilities[i][5],
             'OpenStreetMap contributors','ODbL-1.0',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO fid;

        INSERT INTO courses
            (name, facility_id, holes_count, par_total, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1] || ' — Championship', fid, 18, 72,
             ST_SetSRID(ST_MakePoint(facilities[i][3]::float8, facilities[i][4]::float8), 4326),
             'D_UNVERIFIED_COMMUNITY','PENDING_REVIEW',30.0, facilities[i][5],
             'OpenStreetMap contributors','ODbL-1.0',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO cid;

        -- Holes are the nationwide seed's arithmetic, not OSM: a tee pushed
        -- along a diagonal and a green pushed north. They are labelled as such
        -- so nothing downstream mistakes them for the real routing.
        FOR h IN 1 .. 18 LOOP
            p := pars[h];
            plen := CASE p WHEN 3 THEN 155 + (h*3) WHEN 5 THEN 480 + (h*4) ELSE 360 + (h*2) END;
            tlon := facilities[i][3]::float8 + (h * 0.0008);
            tlat := facilities[i][4]::float8 + (h * 0.0006);
            glat := tlat + (plen / 111000.0);
            plen := round(ST_Distance(
                        ST_SetSRID(ST_MakePoint(tlon, tlat), 4326)::geography,
                        ST_SetSRID(ST_MakePoint(tlon, glat), 4326)::geography
                    )::numeric, 2);
            INSERT INTO holes
                (course_id, hole_number, par, playing_length_meters,
                 teeing_ground_location, green_location,
                 accuracy_class, verification_status, confidence, source, publisher, license,
                 effective_date, version, created_at, updated_at)
            VALUES
                (cid, h, p, plen,
                 ST_SetSRID(ST_MakePoint(tlon, tlat), 4326),
                 ST_SetSRID(ST_MakePoint(tlon, glat), 4326),
                 'D_UNVERIFIED_COMMUNITY','UNVERIFIED',5.0,'synthetic:seed-arithmetic',
                 'VSP Seed (synthetic)','internal-synthetic',
                 CURRENT_DATE, 1, now(), now());
        END LOOP;

        INSERT INTO tee_sets
            (course_id, name, total_par,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (cid,'Blue (Championship)',72,'D_UNVERIFIED_COMMUNITY','UNVERIFIED',5.0,'synthetic:seed-arithmetic','VSP Seed (synthetic)','internal-synthetic',CURRENT_DATE,1,now(),now()),
            (cid,'White (Men)',72,'D_UNVERIFIED_COMMUNITY','UNVERIFIED',5.0,'synthetic:seed-arithmetic','VSP Seed (synthetic)','internal-synthetic',CURRENT_DATE,1,now(),now()),
            (cid,'Red (Ladies)',72,'D_UNVERIFIED_COMMUNITY','UNVERIFIED',5.0,'synthetic:seed-arithmetic','VSP Seed (synthetic)','internal-synthetic',CURRENT_DATE,1,now(),now());

        INSERT INTO data_versions
            (course_id, version, version_number, status, verification_status, accuracy_class,
             confidence, publisher, source, license, effective_date,
             published_at, last_verified_at, published_by, created_at, updated_at)
        VALUES
            (cid, 1, 1, 'PUBLISHED', 'UNVERIFIED', 'D_UNVERIFIED_COMMUNITY',
             5.0, 'VSP Seed (synthetic)', 'synthetic:seed-arithmetic',
             'internal-synthetic', CURRENT_DATE,
             now(), NULL, 'VSP Seed (synthetic)', now(), now());

        added := added + 1;
    END LOOP;

    RAISE NOTICE 'added % facilities from OSM', added;
END $$;

SELECT (SELECT count(*) FROM golf_facilities) AS facilities,
       (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM holes) AS holes,
       (SELECT count(*) FROM golf_facilities
         WHERE source = 'seed:approximate-facility-point') AS still_on_a_guess;
