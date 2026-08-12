-- Split one facility's single "— Championship" course into the đường it
-- actually has.
--
-- WHAT THIS IS FOR
--
--   Every facility in this database carries exactly one course, named
--   "<facility> — Championship" and eighteen holes long, because that is what
--   the nationwide seed wrote (scripts/dev/seed_courses_vn.sql:105). Long Biên
--   has đường A, B and C; Đại Lải has its own; Kings Island has three full
--   eighteens. None of that is in the data, and until it is, the round setup
--   form has nothing to offer and a scorecard cannot say which đường it was
--   printed for.
--
-- WHAT IT REFUSES TO DO
--
--   It does not invent holes. `holes.par` is NOT NULL, so a hole row cannot be
--   written without a par, and eighteen invented pars is a scorecard for a
--   course nobody has read — the same reasoning that kept seed_courses_vn_
--   roster.sql from writing any. Pars arrive through the SCORECARD correction
--   queue, from a golfer holding the club's card.
--
--   It does not touch the existing "— Championship" row either. 164 rounds
--   point at course ids, and deleting one takes a golfer's round with it. The
--   legacy row stays until its rounds are migrated onto a đường, which is a
--   separate decision with a golfer's history on the other end of it.
--
-- WHAT IT NEEDS FROM YOU
--
--   The đường names as the club signs them, and how many holes each has. Both
--   are on the club's own scorecard, its website, or the board at the first
--   tee. `par_total` is NOT NULL: 36 is written for a nine and 72 for an
--   eighteen, stamped D_UNVERIFIED_COMMUNITY like every other assumption in
--   this database, and corrected the moment a card arrives.
--
-- USAGE
--
--   psql -v facility='Long Biên Golf Course' -v duong='A,B,C' -v holes=9 \
--        -f scripts/dev/split_facility_into_duong.sql
--
--   Prints what it will do, then does it. Run inside a transaction you can
--   roll back if the printout is not what you expected:
--
--   BEGIN; \i scripts/dev/split_facility_into_duong.sql   -- read the notices
--   COMMIT;  -- or ROLLBACK;

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_facility   text := current_setting('vsp.facility', true);
    v_duong      text := current_setting('vsp.duong', true);
    v_holes      int  := coalesce(nullif(current_setting('vsp.holes', true), ''), '9')::int;
    v_facility_id bigint;
    v_name       text;
    v_created    int := 0;
    v_existing   int;
BEGIN
    IF v_facility IS NULL OR v_duong IS NULL THEN
        RAISE EXCEPTION
            'Set the facility and its đường first, e.g. '
            'SET vsp.facility = ''Long Biên Golf Course''; SET vsp.duong = ''A,B,C''; SET vsp.holes = ''9'';';
    END IF;

    SELECT id INTO v_facility_id
    FROM golf_facilities
    WHERE name = v_facility;

    IF v_facility_id IS NULL THEN
        RAISE EXCEPTION 'No facility named %. Check golf_facilities.name.', v_facility;
    END IF;

    SELECT count(*) INTO v_existing FROM courses WHERE facility_id = v_facility_id;
    RAISE NOTICE 'Facility % (id %) currently has % course(s).', v_facility, v_facility_id, v_existing;

    FOREACH v_name IN ARRAY string_to_array(v_duong, ',')
    LOOP
        v_name := 'Đường ' || btrim(v_name);

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
            v_facility_id, v_name, v_holes,
            CASE WHEN v_holes = 9 THEN 36 ELSE 72 END,
            'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 5.0,
            'club-directory:duong-names', 'VSP Ops', 'internal-synthetic',
            CURRENT_DATE, 1, now(), now());

        v_created := v_created + 1;
        RAISE NOTICE '  % created (% holes, no hole rows — pars come from a scorecard).', v_name, v_holes;
    END LOOP;

    RAISE NOTICE '% đường created. The "— Championship" row is untouched: % round(s) still point at it.',
        v_created,
        (SELECT count(*) FROM rounds r
         JOIN courses c ON c.id = r.course_id
         WHERE c.facility_id = v_facility_id AND c.name LIKE '%— Championship');
END
$$;
