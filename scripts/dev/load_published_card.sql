-- Write a club's published card onto one sân or đường.
--
-- WHAT THIS IS FOR
--
--   Every hole in this database was invented: `synthetic:seed-arithmetic`, the
--   same par card copied onto fifty-eight courses and a length computed from a
--   coordinate that was itself a guess. A club that publishes its own card —
--   hole, par, stroke index, yardage — is a better source than that by a wide
--   margin, and it is a source anyone can check by opening the page.
--
--   This writes such a card. It is not the scorecard correction queue and does
--   not pretend to be: that queue exists for a golfer standing at the tee with
--   the card in their hand, and what it produces is reviewed by an admin. This
--   is an operator loading a published table, with the URL recorded on every
--   row it writes.
--
-- WHAT IT CHECKS BEFORE WRITING
--
--   Three things, all of which the club's own page states independently, so a
--   transcription error shows up as a contradiction rather than as a wrong
--   number nobody notices:
--
--     * the pars sum to the par the club states for the nine or the eighteen
--     * the yardages sum to the total the club states
--     * the stroke indexes are a complete 1..n with no repeats
--
--   Any of these failing aborts the transaction. A card that does not add up
--   is a card that was read wrong.
--
-- WHAT IT DOES NOT WRITE
--
--   Geometry. `teeing_ground_location` and `green_location` stay null, because
--   a published card says what a hole measures and not where it is, and a tee
--   invented from a clubhouse point is exactly the thing being replaced here.
--   The rows are stamped D_UNVERIFIED_COMMUNITY / UNVERIFIED for that reason —
--   the numbers are good, the map is still absent — and `source` names the page
--   so this is never confused with the seed's invention.
--
--   Stroke index does not go on `holes`: that table has no column for it, and
--   rightly, because the index belongs to the card and not to the đường — hole
--   3 of A is a different index on the A+B card than on A+C. So this also
--   publishes a scorecard for the unit, one segment long, carrying the pars
--   and the indexes the club prints. Replacing the card of the same name, so a
--   re-run corrects rather than duplicates.
--
-- USAGE
--
--   Rows are hole:par:index:yards, comma separated. Index may be 0 when the
--   club does not print one.
--
--     SET vsp.course_id = '1351';
--     SET vsp.source = 'club-website:longbiengolf.vn/san-golf.html';
--     SET vsp.rows = '1:4:3:473,2:4:5:449,3:4:7:381,4:3:8:188,5:5:2:543,
--                     6:3:6:199,7:4:9:383,8:4:1:480,9:5:4:539';
--     SET vsp.par_total = '36';
--     SET vsp.yards_total = '3635';
--     \i scripts/dev/load_published_card.sql
--
--   Existing holes on that course are replaced, so re-running with a corrected
--   card fixes it rather than duplicating it.

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_course_id   bigint := current_setting('vsp.course_id', true)::bigint;
    v_source      text   := current_setting('vsp.source', true);
    v_rows        text   := current_setting('vsp.rows', true);
    v_par_total   int    := current_setting('vsp.par_total', true)::int;
    v_yards_total int    := current_setting('vsp.yards_total', true)::int;
    v_publisher   text;
    v_entry       text;
    v_parts       text[];
    v_hole        int;
    v_par         int;
    v_index       int;
    v_yards       int;
    v_par_sum     int := 0;
    v_yard_sum    int := 0;
    v_count       int := 0;
    v_indexes     int[] := ARRAY[]::int[];
    v_deleted     int;
    v_facility_id bigint;
    v_course_name text;
    v_scorecard_id bigint;
BEGIN
    IF v_course_id IS NULL OR v_rows IS NULL OR v_source IS NULL
       OR v_par_total IS NULL OR v_yards_total IS NULL THEN
        RAISE EXCEPTION
            'Set vsp.course_id, vsp.source, vsp.rows, vsp.par_total and vsp.yards_total first.';
    END IF;

    SELECT f.name INTO v_publisher
    FROM courses c JOIN golf_facilities f ON f.id = c.facility_id
    WHERE c.id = v_course_id;

    IF v_publisher IS NULL THEN
        RAISE EXCEPTION 'No course with id %.', v_course_id;
    END IF;

    -- Dropped first, not just on commit: loading several cards in one
    -- transaction is the normal case, and ON COMMIT DROP alone leaves this
    -- standing for the second call, which then fails on "card already exists"
    -- after the first has already written its holes.
    DROP TABLE IF EXISTS card;
    CREATE TEMP TABLE card(hole int, par int, stroke_index int, yards int) ON COMMIT DROP;

    FOREACH v_entry IN ARRAY string_to_array(replace(replace(v_rows, E'\n', ''), ' ', ''), ',')
    LOOP
        CONTINUE WHEN btrim(v_entry) = '';
        v_parts := string_to_array(btrim(v_entry), ':');
        IF array_length(v_parts, 1) <> 4 THEN
            RAISE EXCEPTION 'Row "%" is not hole:par:index:yards.', v_entry;
        END IF;
        v_hole  := v_parts[1]::int;
        v_par   := v_parts[2]::int;
        v_index := v_parts[3]::int;
        v_yards := v_parts[4]::int;

        IF v_par < 3 OR v_par > 6 THEN
            RAISE EXCEPTION 'Hole % says par %. A hole is a 3, 4, 5 or 6.', v_hole, v_par;
        END IF;

        INSERT INTO card VALUES (v_hole, v_par, v_index, v_yards);
        v_par_sum  := v_par_sum + v_par;
        v_yard_sum := v_yard_sum + v_yards;
        v_count    := v_count + 1;
        IF v_index > 0 THEN
            v_indexes := v_indexes || v_index;
        END IF;
    END LOOP;

    -- The club states each of these separately on the same page, so a
    -- transcription slip contradicts the club rather than passing silently.
    IF v_par_sum <> v_par_total THEN
        RAISE EXCEPTION 'Pars sum to % but the club states %. The card was read wrong.',
            v_par_sum, v_par_total;
    END IF;

    -- Zero everywhere means the club published pars and stroke indexes and no
    -- distances, which happens: Legend Valley's card on mscorecard has all
    -- eighteen indexes and not one yardage. The index is the number that
    -- decides a net score and exists nowhere else, so a card is worth loading
    -- without distances. A missing length reads as NULL, not as zero.
    IF v_yard_sum = 0 THEN
        RAISE NOTICE '  no distances on this card — pars and stroke indexes only.';
    ELSIF v_yard_sum <> v_yards_total THEN
        RAISE EXCEPTION 'Yardages sum to % but the club states %. The card was read wrong.',
            v_yard_sum, v_yards_total;
    END IF;

    IF array_length(v_indexes, 1) IS NOT NULL THEN
        IF array_length(v_indexes, 1) <> v_count THEN
            RAISE EXCEPTION 'Some holes have a stroke index and some do not — % of %.',
                array_length(v_indexes, 1), v_count;
        END IF;
        IF EXISTS (
            SELECT 1 FROM (SELECT unnest(v_indexes) AS i) t
            GROUP BY i HAVING count(*) > 1
        ) THEN
            RAISE EXCEPTION 'A stroke index is printed twice. Every hole gets its own.';
        END IF;
        -- 1..n for a card scored on its own, but a nine belonging to a 27-hole
        -- rotation carries its indexes from the eighteen it is played as half
        -- of: Sông Bé's Lotus runs 1,3,5..17 and Palm the evens. Both are the
        -- club's own numbering. So: n distinct values inside 1..2n.
        IF (SELECT min(i) FROM unnest(v_indexes) i) < 1
           OR (SELECT max(i) FROM unnest(v_indexes) i) > v_count * 2 THEN
            RAISE EXCEPTION 'Stroke indexes fall outside 1..%, which no card numbers past.',
                v_count * 2;
        END IF;
    END IF;

    -- A real card is not eighteen identical holes. Golfify carries placeholder
    -- rows for courses it has no card for — every hole par 4 and 300 yards,
    -- which sums to 72 over 5,400 and passes every check above because it is
    -- perfectly self-consistent. That is the same invention this script exists
    -- to replace, arriving from a different direction.
    IF (SELECT count(DISTINCT yards) FROM card) = 1
       AND (SELECT min(yards) FROM card) > 0
       AND (SELECT count(DISTINCT par) FROM card) = 1 THEN
        RAISE EXCEPTION
            'Every hole is par % over % yards. That is a placeholder, not a card.',
            (SELECT min(par) FROM card), (SELECT min(yards) FROM card);
    END IF;

    DELETE FROM holes WHERE course_id = v_course_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    INSERT INTO holes (
        course_id, hole_number, par, playing_length_meters,
        teeing_ground_location, green_location,
        accuracy_class, verification_status, confidence,
        source, publisher, license, effective_date, version,
        created_at, updated_at)
    SELECT
        v_course_id, c.hole, c.par,
        CASE WHEN c.yards > 0 THEN round(c.yards * 0.9144, 2) END,
        NULL, NULL,
        'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 60.0,
        v_source, v_publisher, 'club-published', CURRENT_DATE, 1,
        now(), now()
    FROM card c;

    UPDATE courses
    SET holes_count = v_count, par_total = v_par_total, updated_at = now()
    WHERE id = v_course_id;

    -- The card itself, so the stroke indexes have somewhere to live. Named for
    -- the unit rather than for a pairing: this is the nine as the club prints
    -- it, and a golfer pairing two of them gets a card per pairing later, from
    -- a photograph, with the indexes renumbered 1..18 the way the club does it.
    SELECT facility_id, name INTO v_facility_id, v_course_name FROM courses WHERE id = v_course_id;

    -- A card a golfer photographed beats one read off a website, and quietly.
    -- Kings Island ended up with both: the golfer's, carrying the course
    -- ratings and slopes that are printed on the card and exist nowhere else,
    -- and mine from Golfify with neither. Both had a segment on the same
    -- đường, so the tee picker offered nine tees for a course that has five.
    --
    -- The club card the operator photographs is the same evidence arriving by
    -- another door, and outranks a website for the same reasons, so it is
    -- refused here too.
    IF EXISTS (
        SELECT 1 FROM scorecards s
        JOIN scorecard_segments g ON g.scorecard_id = s.id
        WHERE g.course_id = v_course_id
          AND (s.source = 'golfer-submitted-scorecard'
               OR s.source LIKE '%photographed at the course%')
    ) THEN
        RAISE NOTICE '% / % : holes written; card left alone, a golfer already published one.',
            v_publisher, v_course_name;
        RETURN;
    END IF;

    DELETE FROM scorecards WHERE facility_id = v_facility_id AND name = v_course_name;

    INSERT INTO scorecards (
        facility_id, name, holes_count, par_total,
        source, publisher, license, accuracy_class, verification_status,
        effective_date, created_at, updated_at)
    VALUES (
        v_facility_id, v_course_name, v_count, v_par_total,
        v_source, v_publisher, 'club-published',
        'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED',
        CURRENT_DATE, now(), now())
    RETURNING id INTO v_scorecard_id;

    INSERT INTO scorecard_segments (scorecard_id, position, course_id)
    VALUES (v_scorecard_id, 1, v_course_id);

    INSERT INTO scorecard_holes (scorecard_id, hole_number, par, stroke_index)
    SELECT v_scorecard_id, c.hole, c.par, NULLIF(c.stroke_index, 0) FROM card c;

    RAISE NOTICE '% / % : % hole(s), par %, % yards (% invented hole(s) replaced), card #%. Source %.',
        v_publisher, v_course_name, v_count, v_par_total, v_yards_total,
        v_deleted, v_scorecard_id, v_source;
END
$$;
