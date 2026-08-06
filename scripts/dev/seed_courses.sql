-- Seed realistic Vietnamese golf facility NAMES with invented geometry.
--
-- The coordinates are approximate clubhouse points typed by hand; the eighteen
-- holes per course are generated arithmetically (green exactly `plen` metres
-- due north of a tee that marches along a fixed diagonal) and every course gets
-- the same card. Every row is labelled D_UNVERIFIED_COMMUNITY / UNVERIFIED
-- accordingly — see the header of seed_courses_vn.sql for why that matters and
-- why it must not be softened.
--
-- Idempotent: skips facilities whose name already exists.
DO $$
DECLARE
    fac  RECORD;
    cid  BIGINT;
    fid  BIGINT;
    h    INT;
    pars INT[] := ARRAY[4,5,4,3,4,4,5,3,4, 4,4,3,5,4,4,3,4,5];
    plen NUMERIC;
    p    INT;
    tlon DOUBLE PRECISION;
    tlat DOUBLE PRECISION;
    glat DOUBLE PRECISION;
    facilities CONSTANT TEXT[][] := ARRAY[
        ARRAY['BRG Kings Island Golf Resort','Đồng Mô, Sơn Tây, Hà Nội','105.4000','21.0333','024 3924 6789'],
        ARRAY['Sky Lake Resort & Golf Club','Chương Mỹ, Hà Nội','105.6800','20.8700','024 3388 1234'],
        ARRAY['Long Biên Golf Course','Long Biên, Hà Nội','105.9000','21.0500','024 3987 6543'],
        ARRAY['Tam Đảo Golf Resort','Tam Đảo, Vĩnh Phúc','105.6200','21.4600','021 1123 4567'],
        ARRAY['Vinpearl Golf Nam Hội An','Duy Xuyên, Quảng Nam','108.3300','15.7500','023 5654 3210'],
        ARRAY['Tân Sơn Nhất Golf Course','Gò Vấp, TP. Hồ Chí Minh','106.6600','10.8100','028 3547 8888'],
        ARRAY['Vietnam Golf & Country Club','Thủ Đức, TP. Hồ Chí Minh','106.8300','10.8400','028 3280 0100'],
        ARRAY['Long Thành Golf Resort','Long Thành, Đồng Nai','106.9500','10.7900','025 1355 0088']
    ];
BEGIN
    FOR i IN 1 .. array_length(facilities,1) LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM golf_facilities WHERE name = facilities[i][1]);

        INSERT INTO golf_facilities
            (name, address, phone, website, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1], facilities[i][2], facilities[i][5], NULL,
             ST_SetSRID(ST_MakePoint(facilities[i][3]::float8, facilities[i][4]::float8), 4326),
             'D_UNVERIFIED_COMMUNITY','UNVERIFIED',30.0,'seed:approximate-facility-point',
             'VSP Seed (approximate)','internal-synthetic',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO fid;

        INSERT INTO courses
            (name, facility_id, holes_count, par_total, location,
             accuracy_class, verification_status, confidence, source, publisher, license,
             effective_date, version, created_at, updated_at)
        VALUES
            (facilities[i][1] || ' — Championship', fid, 18, 72,
             ST_SetSRID(ST_MakePoint(facilities[i][3]::float8, facilities[i][4]::float8), 4326),
             'D_UNVERIFIED_COMMUNITY','UNVERIFIED',30.0,'seed:approximate-facility-point',
             'VSP Seed (approximate)','internal-synthetic',
             CURRENT_DATE, 1, now(), now())
        RETURNING id INTO cid;

        FOR h IN 1 .. 18 LOOP
            p := pars[h];
            plen := CASE p WHEN 3 THEN 155 + (h*3) WHEN 5 THEN 480 + (h*4) ELSE 360 + (h*2) END;
            tlon := facilities[i][3]::float8 + (h * 0.0008);
            tlat := facilities[i][4]::float8 + (h * 0.0006);
            glat := tlat + (plen / 111000.0);  -- push green north by ~length in metres
            -- One length per hole, and it is the one the coordinates give.
            -- 1 degree of latitude is not exactly 111 km, so the card and the
            -- points used to disagree by up to 2 m — the same fiction told
            -- twice, slightly differently. The app measures from the points,
            -- so the points decide what the card says.
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
    END LOOP;
END $$;

SELECT (SELECT count(*) FROM golf_facilities) AS facilities,
       (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM holes) AS holes,
       (SELECT count(*) FROM tee_sets) AS tee_sets;
