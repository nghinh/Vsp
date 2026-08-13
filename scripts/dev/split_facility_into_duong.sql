-- Give a facility the sân or đường it actually has, in place of the single
-- invented "— Championship" row.
--
-- SÂN AND ĐƯỜNG ARE NOT THE SAME THING
--
--   A *sân* is a complete course: eighteen holes, played on its own. BRG Kings
--   Island has three of them — Kings, Mountain View, Lakeside — and a round is
--   played on one.
--
--   An *đường* is a nine. It is not a round by itself; two of them pair into
--   one. Long Biên has đường A, B and C, so a round there is A+B, A+C or B+C,
--   and the club prints a separate card for each pairing.
--
--   Both are one row in `courses`. What differs is `holes_count` and how many
--   of them a scorecard names: a sân's card has one segment, an đường pairing's
--   card has two, in the order played. That is what `scorecard_segments` and
--   ScorecardQueryService.byPairing exist for.
--
-- WHAT THIS IS FOR
--
--   Every facility in this database carries exactly one course, named
--   "<facility> — Championship" and eighteen holes long, because that is what
--   the nationwide seed wrote (scripts/dev/seed_courses_vn.sql:105). None of
--   the real structure is in the data, and until it is, the round setup form
--   has nothing to offer and a scorecard cannot say what it was printed for.
--
-- WHAT IT REFUSES TO DO
--
--   It does not invent holes. `holes.par` is NOT NULL, so a hole row cannot be
--   written without a par, and eighteen invented pars is a scorecard for a
--   course nobody has read — the same reasoning that kept seed_courses_vn_
--   roster.sql from writing any. Pars arrive through the SCORECARD correction
--   queue, from a golfer holding the club's card.
--
--   It does not touch the existing "— Championship" row either. Rounds point at
--   course ids, and deleting one takes a golfer's round with it. The legacy row
--   stays until its rounds are migrated or retired, which is a separate
--   decision with a golfer's history on the other end of it.
--
--   It no longer guesses par. The old version wrote 36 for every nine, which is
--   wrong the moment a real card disagrees — Long Biên's đường C is par 35, on
--   the club's own published card. Par is now given per unit, because a number
--   nobody read off a card is a number this script has no business inventing.
--
-- WHAT IT NEEDS FROM YOU
--
--   One entry per sân or đường, as `name:holes:par`, comma separated. The name
--   is written exactly as given — no prefix is added, because "Kings Course"
--   and "Đường A" are both names a club signs and neither is a house style this
--   script gets to impose.
--
-- USAGE
--
--   Long Biên — three đường, and đường C really is par 35:
--
--     SET vsp.facility = 'Long Biên Golf Course';
--     SET vsp.units = 'Đường A:9:36,Đường B:9:36,Đường C:9:35';
--     \i scripts/dev/split_facility_into_duong.sql
--
--   BRG Kings Island — three sân of eighteen:
--
--     SET vsp.facility = 'BRG Kings Island Golf Resort';
--     SET vsp.units = 'Kings Course:18:72,Mountain View Course:18:72,Lakeside Course:18:72';
--     \i scripts/dev/split_facility_into_duong.sql
--
--   Prints what it will do, then does it. Run inside a transaction you can roll
--   back if the printout is not what you expected:
--
--     BEGIN; \i scripts/dev/split_facility_into_duong.sql   -- read the notices
--     COMMIT;  -- or ROLLBACK;

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_facility    text := current_setting('vsp.facility', true);
    v_units       text := current_setting('vsp.units', true);
    v_facility_id bigint;
    v_entry       text;
    v_parts       text[];
    v_name        text;
    v_holes       int;
    v_par         int;
    v_created     int := 0;
    v_existing    int;
BEGIN
    IF v_facility IS NULL OR v_units IS NULL OR btrim(v_units) = '' THEN
        RAISE EXCEPTION
            'Set the facility and its units first, e.g. '
            'SET vsp.facility = ''Long Biên Golf Course''; '
            'SET vsp.units = ''Đường A:9:36,Đường B:9:36,Đường C:9:35'';';
    END IF;

    SELECT id INTO v_facility_id
    FROM golf_facilities
    WHERE name = v_facility;

    IF v_facility_id IS NULL THEN
        RAISE EXCEPTION 'No facility named %. Check golf_facilities.name.', v_facility;
    END IF;

    SELECT count(*) INTO v_existing FROM courses WHERE facility_id = v_facility_id;
    RAISE NOTICE 'Facility % (id %) currently has % course(s).', v_facility, v_facility_id, v_existing;

    FOREACH v_entry IN ARRAY string_to_array(v_units, ',')
    LOOP
        v_parts := string_to_array(btrim(v_entry), ':');

        IF array_length(v_parts, 1) <> 3 THEN
            RAISE EXCEPTION
                'Entry "%" is not name:holes:par. Every unit needs all three — '
                'a par this script made up is the thing it exists not to write.',
                v_entry;
        END IF;

        v_name  := btrim(v_parts[1]);
        v_holes := btrim(v_parts[2])::int;
        v_par   := btrim(v_parts[3])::int;

        IF v_name = '' THEN
            RAISE EXCEPTION 'Entry "%" has no name.', v_entry;
        END IF;

        -- A nine and an eighteen are the two things a club builds. Anything
        -- else is a typo in the entry, and a course row with seven holes in it
        -- would be found much later by a golfer who could not finish a round.
        IF v_holes NOT IN (9, 18) THEN
            RAISE EXCEPTION 'Unit % says % holes. Expected 9 or 18.', v_name, v_holes;
        END IF;

        -- Wide enough to hold anything a real club prints, narrow enough to
        -- catch a par and a hole count swapped round.
        IF v_par < 27 OR v_par > 80 THEN
            RAISE EXCEPTION 'Unit % says par %. That is not a par for % holes.',
                v_name, v_par, v_holes;
        END IF;

        IF EXISTS (SELECT 1 FROM courses WHERE facility_id = v_facility_id AND name = v_name) THEN
            RAISE NOTICE '  % already exists — left alone.', v_name;
            CONTINUE;
        END IF;

        INSERT INTO courses (
            facility_id, name, holes_count, par_total,
            accuracy_class, verification_status, confidence,
            source, publisher, license, effective_date, version,
            created_at, updated_at)
        VALUES (
            v_facility_id, v_name, v_holes, v_par,
            'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 5.0,
            'club-directory:published-course-names', 'VSP Ops', 'internal-synthetic',
            CURRENT_DATE, 1, now(), now());

        v_created := v_created + 1;
        RAISE NOTICE '  % created (% holes, par %, no hole rows — pars per hole come from a scorecard).',
            v_name, v_holes, v_par;
    END LOOP;

    RAISE NOTICE '% unit(s) created. The "— Championship" row is untouched: % round(s) still point at it.',
        v_created,
        (SELECT count(*) FROM rounds r
         JOIN courses c ON c.id = r.course_id
         WHERE c.facility_id = v_facility_id AND c.name LIKE '%— Championship');
END
$$;
