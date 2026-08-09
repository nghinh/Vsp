-- Vietnam golf roster, round two: coordinates found by investigation.
--
-- seed_courses_vn_osm.sql handled the courses OSM names outright. This file
-- handles the ones it does not: courses OSM has drawn without naming, and
-- courses OSM knows only as a single node. Finding them meant reading what is
-- around a shape rather than what is written on it — the lake beside it, the
-- bus stop, the road name, the `is_in` commune.
--
-- HOW MUCH TO TRUST THIS
--   Two investigations ran independently: one working forward from public
--   course directories to locations, one working backward from OSM geometry to
--   identities. They agreed on all six unnamed polygons. That agreement is the
--   reason these are applied rather than filed as proposals — a single chain of
--   inference would not be enough, and the review doc's own worked example
--   (Đầm Vạc / Tam Đảo, 0.67 similar by accident of letters) is why.
--
--   Each row below records what settled it. Where the evidence is locality and
--   elimination rather than a name or a website, the comment says so.
--
-- WHAT IS DELIBERATELY NOT HERE
--   * Diamond Bay Golf & Villas — OSM has no golf geometry anywhere in Nha
--     Trang. The best available is a resort-brand node, and two Diamond Bay
--     properties share that brand on the same boulevard. A brand pin is not a
--     course; the row keeps its guess and its label.
--   * FLC Quy Nhơn Golf Links — added by name only, in
--     seed_courses_vn_roster.sql. The one OSM polygon on the site is 37.8 ha
--     and tagged "Sân tập" (driving range); both investigations flagged it and
--     one recommended a blank outright.
--   * Legend Valley, Stone Valley, Tràng An, West Lakes, Xuân Thành — OSM has
--     nothing for them at all. Checked twice, by locality bbox and by a
--     Vietnam-wide sweep of every golf object.
--
-- THE GRAND HỒ TRÀM GOLF CLUB — UNSUBSTANTIATED, KEPT ON ITS GUESS
--   Reviewed 2026-08-09. It had been carried as an open question — "are The
--   Bluffs and The Grand the same place, and should they be merged?" — but
--   that is the wrong question, and the evidence for the right one is already
--   in this file.
--
--   The Bluffs relocation below tests the Grand Ho Tram hotel cluster against
--   the golf polygon (way/516689819) and finds it OUTSIDE, while a node named
--   "Bluffs Golf Club" sits 0.15 km inside. So the golf course at Hồ Tràm is
--   The Bluffs; The Grand is the resort the course belongs to.
--
--   "The Grand Hồ Tràm Golf Club" therefore has no corroboration as a golf
--   facility of its own. It is still on the nationwide seed's two-decimal
--   guess (107.4000, 10.4700 — unchanged from seed_courses_vn.sql line 78),
--   and its phone number is one digit-pattern away from The Bluffs' (…8888
--   versus …9999), which is what invented data looks like.
--
--   Not deleted here, because deleting a facility is not a seed script's job
--   and because "no evidence for" is not "evidence against" — a second course
--   under the resort brand is possible. It keeps its UNVERIFIED label, which
--   is what stops the app drawing distances from it. Someone with an
--   authoritative source should confirm or remove it.
--
-- Coordinates and boundaries © OpenStreetMap contributors, ODbL-1.0.
--
-- Idempotent. Relocation only touches rows still on a seeded point; additions
-- are skipped when the facility name already exists.

-- ── 1. Relocate ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    fid   BIGINT;
    dlon  DOUBLE PRECISION;
    dlat  DOUBLE PRECISION;
    moved INT := 0;
    -- [facility name, osm ref, lon, lat, evidence]
    fixes CONSTANT TEXT[][] := ARRAY[
      -- Named or self-identifying OSM objects: the strongest kind of evidence.
      ARRAY['Phoenix Golf Resort','osm:node/4900827761','105.49138','20.89827',
            'leisure=golf_course "Sân gôn Phượng Hoàng" carrying addr:district=Lương Sơn, addr:province=Hòa Bình'],
      ARRAY['Mường Thanh Diễn Lâm Golf Club','osm:node/12887965006','105.50682','19.15230',
            'leisure=golf_course named "Sân Golf Mường Thanh Diễn Lâm" verbatim'],
      ARRAY['Royal Golf Club Ninh Bình','osm:node/8186053017','105.96648','20.12518',
            'node carries website=royalgolf.com.vn and name:en=Royal Golf Club — an identification, not a name match'],
      ARRAY['Vân Trì Golf Club','osm:way/264995260','105.79842','21.14806',
            'a road 0.47 km away tagged addr:street="Van Tri Golf Estate Concordia Road"'],
      ARRAY['Ba Na Hills Golf Club','osm:way/1120439042','108.05399','16.01344',
            'bus stops named "Sân Golf Bà Nà Hills" 0.88 km from the centroid'],
      ARRAY['Thanh Lanh Valley Golf Club','osm:way/1257684070','105.68869','21.39719',
            'Hồ Thanh Lanh 0.23 km away'],
      ARRAY['Dalat at 1200 Country Club','osm:way/526178342','108.45096','11.79202',
            'in Đơn Dương, 1.14 km from Hồ Đạ Ròn — the club places itself at Đạ Ròn lake. The seeded point was ~31 km off, outside every search radius tried before'],
      ARRAY['Vinpearl Golf Phú Quốc','osm:way/746378176','103.85109','10.34893',
            'inside the Vinpearl / VinWonders complex on Phú Quốc'],
      ARRAY['The Bluffs Hồ Tràm Strip','osm:way/516689819','107.44637','10.48139',
            'node/4264413692 name:vi="Bluffs Golf Club" sits 0.15 km inside the ring; the Grand Ho Tram hotel cluster tests outside it'],
      -- Locality and elimination. Weaker, and labelled as such.
      ARRAY['BRG Legend Hill Golf Resort','osm:way/736986474','105.84532','21.29643',
            'locality only: Hồng Kỳ, Sóc Sơn — 8.5 km from the Minh Trí polygon that is Hanoi Golf Club'],
      ARRAY['Tam Đảo Golf Resort','osm:way/483498954','105.62693','21.40638',
            'locality only: reverse-geocodes to Tam Đảo'],
      ARRAY['Hilltop Valley Golf Club','osm:way/921118981','105.36294','20.87734',
            'no polygon drawn; centroid of a 12-way golf=cartpath network spanning 1.1 x 1.7 km in Kỳ Sơn, beside node "KHU LV SÂN GOLF HÒA BÌNH"'],
      ARRAY['Chí Linh Star Golf & Country Club','osm:node/880591543','106.39880','21.10224',
            'the only golf object in Chí Linh: leisure=golf_course "Golf CL" off Nguyễn Thái Học (QL.37), matching the club address. Possibly the gate rather than the centre of a 325 ha site'],
      ARRAY['Laguna Lăng Cô Golf Club','osm:node/5952735437','107.95375','16.33805',
            'the course itself is unmapped; this is the Banyan Tree / Angsana resort pin. Applied because the seeded point was ~17 km wrong, not because it locates the course']
    ];
BEGIN
    FOR i IN 1 .. array_length(fixes, 1) LOOP
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
               verification_status = 'PENDING_REVIEW',
               accuracy_class = 'D_UNVERIFIED_COMMUNITY',
               updated_at = now(),
               version = version + 1
         WHERE id = fid;

        UPDATE courses
           SET location = ST_SetSRID(ST_MakePoint(fixes[i][3]::float8, fixes[i][4]::float8), 4326),
               updated_at = now()
         WHERE facility_id = fid;

        -- Same translation as round one: the synthetic holes travel with the
        -- course so the map frames the right piece of ground.
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

    RAISE NOTICE 'relocated % facilities', moved;
END $$;

-- ── 2. Add the courses behind the unnamed polygons ──────────────────────────
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
    -- holes_count stays 18 and eighteen holes are written, as for every other
    -- course here, even where the resort has 27 or 36. One modelled eighteen is
    -- what the app plays; the resort's real total is in the review doc.
    facilities CONSTANT TEXT[][] := ARRAY[
      ARRAY['Hà Nội Golf Club','Minh Trí, Sóc Sơn, Hà Nội','105.76366','21.29276','osm:way/736985352'],
      ARRAY['Dragon Golf Links','Đồi Rồng, Đồ Sơn, Hải Phòng','106.77278','20.68558','osm:way/1484006520'],
      ARRAY['Tuần Châu Golf Resort','Tuần Châu, Hạ Long, Quảng Ninh','106.97944','20.93891','osm:way/1115779046'],
      ARRAY['FLC Quảng Bình Golf Links','Hải Ninh, Quảng Ninh, Quảng Bình','106.75999','17.33230','osm:way/1115414685'],
      ARRAY['Sonadezi Châu Đức Golf Course','Châu Đức, Bà Rịa - Vũng Tàu','107.18028','10.61178','osm:way/1317044002']
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
             'D_UNVERIFIED_COMMUNITY','PENDING_REVIEW',25.0, facilities[i][5],
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
             'D_UNVERIFIED_COMMUNITY','PENDING_REVIEW',25.0, facilities[i][5],
             'OpenStreetMap contributors','ODbL-1.0',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO cid;

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

    RAISE NOTICE 'added % located facilities', added;
END $$;

-- ── 3. One address that was simply wrong ────────────────────────────────────
-- Tràng An Golf & Country Club is at Kỳ Phú, Nho Quan — not TP. Ninh Bình,
-- 30 km away. The wrong address is why searching OSM around it found only the
-- Tràng An scenic area's roads and homestays, which is the Đầm Vạc trap in
-- another costume: a name that matches and a place that does not.
UPDATE golf_facilities
   SET address = 'Kỳ Phú, Nho Quan, Ninh Bình',
       updated_at = now()
 WHERE name = 'Tràng An Golf & Country Club'
   AND address = 'TP. Ninh Bình, Ninh Bình';

SELECT (SELECT count(*) FROM golf_facilities) AS facilities,
       (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM holes) AS holes,
       (SELECT count(*) FROM golf_facilities WHERE location IS NULL) AS location_unknown,
       (SELECT count(*) FROM golf_facilities
         WHERE source = 'seed:approximate-facility-point') AS still_on_a_guess;
