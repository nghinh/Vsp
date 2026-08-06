-- Comprehensive Vietnam golf-course seed (nationwide coverage).
--
-- Real facility names, approximate facility coordinates (WGS84), and eighteen
-- holes per course that this file INVENTS: the tee is the clubhouse point
-- pushed along a fixed diagonal, the green is that tee pushed due north by the
-- hole's length, and the par/length card below is the same on every course.
-- Nothing here was surveyed, digitised or observed.
--
-- Every row is therefore stamped D_UNVERIFIED_COMMUNITY / UNVERIFIED with a
-- source that names it as synthetic. It used to claim C_VERIFIED_SATELLITE /
-- VERIFIED / confidence 95 / CC-BY-4.0, which is the label a real satellite
-- digitisation carries — and the app computes every distance it shows a golfer
-- from these coordinates. Do not restore those labels here: the client gates
-- its "not surveyed" markers on them, and a demo that lies is worse than a
-- demo that is empty.
--
-- Real hole geometry arrives later via tools/course-digitization, which
-- overwrites these rows with its own (honest) provenance.
--
-- Idempotent: facilities already present (by name) are skipped.
DO $$
DECLARE
    fid  BIGINT;
    cid  BIGINT;
    h    INT;
    p    INT;
    plen NUMERIC;
    tlon DOUBLE PRECISION;
    tlat DOUBLE PRECISION;
    glat DOUBLE PRECISION;
    pars INT[] := ARRAY[4,5,4,3,4,4,5,3,4, 4,4,3,5,4,4,3,4,5];
    -- [name, address, lon, lat, phone]
    facilities CONSTANT TEXT[][] := ARRAY[
      -- ── North / Hà Nội & surrounding ──────────────────────────────────────
      ARRAY['BRG Legend Hill Golf Resort','Sóc Sơn, Hà Nội','105.8300','21.2500','024 3595 8888'],
      ARRAY['Vân Trì Golf Club','Đông Anh, Hà Nội','105.7900','21.1600','024 3968 5926'],
      ARRAY['Đại Lải Star Golf & Country Club','Ngọc Thanh, Phúc Yên, Vĩnh Phúc','105.6300','21.3700','021 1123 8888'],
      ARRAY['Heron Lake Golf Course & Resort','Đại Lải, Vĩnh Phúc','105.6500','21.3600','021 1122 6789'],
      ARRAY['Thanh Lanh Valley Golf Club','Bình Xuyên, Vĩnh Phúc','105.6800','21.4200','021 1188 9999'],
      ARRAY['Phoenix Golf Resort','Lương Sơn, Hòa Bình','105.5200','20.8800','021 8388 8888'],
      ARRAY['Hilltop Valley Golf Club','Kỳ Sơn, Hòa Bình','105.3500','20.8500','021 8386 8686'],
      ARRAY['Chí Linh Star Golf & Country Club','Chí Linh, Hải Dương','106.3800','21.1400','022 0388 2888'],
      ARRAY['BRG Ruby Tree Golf Resort','Đồ Sơn, Hải Phòng','106.7900','20.7200','022 5386 4888'],
      ARRAY['Sông Giá Golf Resort','Thủy Nguyên, Hải Phòng','106.6200','20.9500','022 5359 9888'],
      ARRAY['Yên Dũng Resort & Golf Club','Yên Dũng, Bắc Giang','106.2500','21.2000','020 4388 6888'],
      ARRAY['Stone Valley Golf Resort','Kim Bảng, Hà Nam','105.8500','20.5800','022 6388 7888'],
      ARRAY['Legend Valley Country Club','Thanh Sơn, Hà Nam','105.9000','20.5500','022 6386 9999'],
      ARRAY['Tràng An Golf & Country Club','TP. Ninh Bình, Ninh Bình','105.9200','20.2800','022 9388 5888'],
      ARRAY['Royal Golf Club Ninh Bình','Yên Mô, Ninh Bình','106.0000','20.1000','022 9386 8888'],
      ARRAY['FLC Hạ Long Golf Club','Hạ Long, Quảng Ninh','107.0800','20.9500','020 3626 8888'],
      ARRAY['Mường Thanh Diễn Lâm Golf Club','Diễn Châu, Nghệ An','105.5500','19.1500','023 8626 8888'],
      -- ── North Central ─────────────────────────────────────────────────────
      ARRAY['FLC Sầm Sơn Golf Links','Sầm Sơn, Thanh Hóa','105.9000','19.7400','023 7378 8888'],
      ARRAY['Xuân Thành Golf & Resort','Nghi Xuân, Hà Tĩnh','105.8600','18.6000','023 9386 8888'],
      -- ── Central (Đà Nẵng / Quảng Nam / Huế) ───────────────────────────────
      ARRAY['BRG Đà Nẵng Golf Resort','Ngũ Hành Sơn, Đà Nẵng','108.2800','16.0200','023 6392 8888'],
      ARRAY['Montgomerie Links Vietnam','Điện Ngọc, Điện Bàn, Quảng Nam','108.3100','15.9500','023 5395 8888'],
      ARRAY['Ba Na Hills Golf Club','Hòa Vang, Đà Nẵng','108.0600','15.9900','023 6379 9888'],
      ARRAY['Hoiana Shores Golf Club','Duy Xuyên, Quảng Nam','108.3600','15.8300','023 5399 8888'],
      ARRAY['Laguna Lăng Cô Golf Club','Phú Lộc, Thừa Thiên Huế','108.1000','16.2800','023 4369 5888'],
      -- ── Central Highlands ─────────────────────────────────────────────────
      ARRAY['Dalat Palace Golf Club','TP. Đà Lạt, Lâm Đồng','108.4400','11.9400','026 3382 3507'],
      ARRAY['SAM Tuyền Lâm Golf & Resort','TP. Đà Lạt, Lâm Đồng','108.4400','11.9000','026 3355 8888'],
      ARRAY['Dalat at 1200 Country Club','Đà Rsal, Lâm Đồng','108.3500','12.0500','026 3357 9999'],
      -- ── South Central Coast ───────────────────────────────────────────────
      ARRAY['Vinpearl Golf Nha Trang','Hòn Tre, Nha Trang, Khánh Hòa','109.2500','12.2200','025 8359 8888'],
      ARRAY['Diamond Bay Golf & Villas','Nha Trang, Khánh Hòa','109.1700','12.1800','025 8371 1711'],
      ARRAY['KN Golf Links Cam Ranh','Cam Lâm, Khánh Hòa','109.1900','12.0500','025 8628 8888'],
      ARRAY['Sea Links Golf & Country Club','Mũi Né, Phan Thiết, Bình Thuận','108.2800','10.9300','025 2374 1741'],
      ARRAY['PGA Ocean Golf Course NovaWorld','Tiến Thành, Phan Thiết, Bình Thuận','108.1000','10.8500','025 2628 8888'],
      -- ── HCMC & Đông Nam Bộ ────────────────────────────────────────────────
      ARRAY['Twin Doves Golf Club','Thủ Dầu Một, Bình Dương','106.7300','10.9800','027 4222 8888'],
      ARRAY['Sông Bé Golf Resort','Thuận An, Bình Dương','106.7200','10.9000','027 4375 6660'],
      ARRAY['Harmonie Golf Park','Bến Cát, Bình Dương','106.6000','11.1000','027 4730 8888'],
      ARRAY['Đồng Nai Golf Resort','Trảng Bom, Đồng Nai','107.0000','10.9700','025 1386 8888'],
      ARRAY['Taekwang Jeongsan Country Club','Biên Hòa, Đồng Nai','106.9000','10.9400','025 1395 8888'],
      ARRAY['The Bluffs Hồ Tràm Strip','Xuyên Mộc, Bà Rịa - Vũng Tàu','107.4200','10.4500','025 4378 8888'],
      ARRAY['The Grand Hồ Tràm Golf Club','Xuyên Mộc, Bà Rịa - Vũng Tàu','107.4000','10.4700','025 4378 9999'],
      ARRAY['Paradise Vũng Tàu Golf Resort','TP. Vũng Tàu, Bà Rịa - Vũng Tàu','107.0800','10.3500','025 4385 9868'],
      ARRAY['West Lakes Golf & Villas','Đức Hòa, Long An','106.4500','10.8800','027 2377 8888'],
      -- ── Mekong / Islands ──────────────────────────────────────────────────
      ARRAY['Vinpearl Golf Phú Quốc','Phú Quốc, Kiên Giang','103.8600','10.3200','029 7368 8888']
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

        -- A published DataVersion so freshness renders. Published, not
        -- verified: PUBLISHED says this is the current version, and nothing
        -- more. This row is what the mobile quality badge reads, and it used
        -- to assert VERIFIED with a last_verified_at of the instant the seed
        -- ran — nobody had verified anything.
        INSERT INTO data_versions
            (course_id, version, version_number, status, verification_status, accuracy_class,
             confidence, publisher, source, license, effective_date,
             published_at, last_verified_at, published_by, created_at, updated_at)
        VALUES
            (cid, 1, 1, 'PUBLISHED', 'UNVERIFIED', 'D_UNVERIFIED_COMMUNITY',
             5.0, 'VSP Seed (synthetic)', 'synthetic:seed-arithmetic',
             'internal-synthetic', CURRENT_DATE,
             now(), NULL, 'VSP Seed (synthetic)', now(), now());
    END LOOP;
END $$;

SELECT (SELECT count(*) FROM golf_facilities) AS facilities,
       (SELECT count(*) FROM courses) AS courses,
       (SELECT count(*) FROM holes) AS holes,
       (SELECT count(*) FROM tee_sets) AS tee_sets,
       (SELECT count(*) FROM data_versions) AS data_versions;
