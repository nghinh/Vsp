-- Đại Lải Star: đường C from the club's B+C card, and one correction to B.
--
-- WHERE THIS CAME FROM
--
--   The club's own B+C combination card, supplied by the operator: eighteen
--   holes labelled B1-B9 and C1-C9, four tees, and each tee's OUT, IN and
--   TOTAL printed beside it.
--
-- WHY IT IS TRUSTED
--
--   It checks against itself ten times over. Par sums to 36 out, 36 in, 72
--   total; and every one of the four tees sums to the OUT, IN and TOTAL the
--   card prints for it — Black 3,533 / 3,398 / 6,931, Blue 3,306 / 3,196 /
--   6,502, and the same for White and Red. A card that states its own totals
--   and adds up to them is the strongest evidence this project has, which is
--   why the OCR path was taught to ask for exactly these numbers.
--
--   It also agrees with what is already here. Đường B's nine pars match B1-B9
--   exactly, and its lengths match the Black tee to the metre: 358 against
--   357.5, 412 against 412.4, 534 against 534.0. Two independent sources — the
--   mscorecard export loaded earlier and this card — describing the same nine.
--
-- WHAT IT WRITES
--
--   Đường C, which had no holes at all: nine holes, par 36, four tees.
--
--   And one cell on đường B. Hole 6 off the White tee reads 376 here and 378
--   on the card. The card's own OUT of 3,082 agrees with 378 and not with 376,
--   so the stored value is the misread one.
--
-- WHAT IT DOES NOT WRITE
--
--   Stroke index for đường C. The card supplied prints no index row, and
--   đường A and B both carry the odd numbering, so C's cannot be inferred from
--   them — a nine's index depends on which eighteen it is played as half of.
--   Left null, which reads as "not known" rather than as a guess.
--
-- THE RED TEE
--
--   Recorded as LADIES, because the card labels it "Red (Nữ)". Every other tee
--   is UNSPECIFIED: the card does not say whose they are, and reading an
--   unlabelled rating as the men's would be a guess that looks like data.
--
-- USAGE
--
--   ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
--     psql -U vsp -d vsp -v ON_ERROR_STOP=1" < scripts/dev/load_dai_lai_bc.sql

\set ON_ERROR_STOP on

BEGIN;

-- ─── Đường B: the one cell the card contradicts ────────────────────────────

UPDATE scorecard_tee_yardages y SET yards = 378
FROM scorecard_tees t, scorecard_segments g
WHERE y.scorecard_tee_id = t.id
  AND t.scorecard_id = g.scorecard_id
  AND g.course_id = 1420
  AND t.name = 'White'
  AND y.hole_number = 6
  AND y.yards = 376;

-- ─── Đường C: everything ───────────────────────────────────────────────────

CREATE TEMP TABLE duong_c(hole int, par int, black int, blue int, white int, red int)
ON COMMIT DROP;
INSERT INTO duong_c VALUES
  (1, 5, 566, 542, 500, 481),
  (2, 4, 378, 355, 322, 301),
  (3, 3, 168, 149, 130, 106),
  (4, 4, 350, 329, 329, 326),
  (5, 4, 401, 380, 353, 326),
  (6, 3, 145, 126, 116, 112),
  (7, 4, 433, 410, 388, 348),
  (8, 4, 396, 372, 353, 330),
  (9, 5, 561, 533, 501, 482);

DO $$
DECLARE
    v_par int; v_black int; v_blue int; v_white int; v_red int;
BEGIN
    SELECT sum(par), sum(black), sum(blue), sum(white), sum(red)
    INTO v_par, v_black, v_blue, v_white, v_red FROM duong_c;

    -- The card's printed IN row, restated so a typo above contradicts the club
    -- rather than passing quietly.
    IF v_par <> 36 OR v_black <> 3398 OR v_blue <> 3196
       OR v_white <> 2992 OR v_red <> 2812 THEN
        RAISE EXCEPTION
            'Đường C reads par % / % / % / % / %, but the card prints 36 / 3398 / 3196 / 2992 / 2812.',
            v_par, v_black, v_blue, v_white, v_red;
    END IF;
END $$;

DELETE FROM holes WHERE course_id = 1421;

INSERT INTO holes (course_id, hole_number, par, playing_length_meters,
    accuracy_class, verification_status, confidence,
    source, publisher, license, effective_date, version, created_at, updated_at)
SELECT 1421, c.hole, c.par, round(c.black * 0.9144, 2),
    'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 60.0,
    'club B+C card; every tee sums to its printed OUT, IN and TOTAL',
    'Đại Lải Star Golf & Country Club', 'club-published',
    CURRENT_DATE, 1, now(), now()
FROM duong_c c;

UPDATE courses SET holes_count = 9, par_total = 36, updated_at = now() WHERE id = 1421;

DELETE FROM scorecards WHERE id IN (
    SELECT s.id FROM scorecards s JOIN scorecard_segments g ON g.scorecard_id = s.id
    WHERE g.course_id = 1421);

INSERT INTO scorecards (facility_id, name, holes_count, par_total,
    source, publisher, license, accuracy_class, verification_status,
    effective_date, created_at, updated_at)
SELECT c.facility_id, c.name, 9, 36,
    'club B+C card; every tee sums to its printed OUT, IN and TOTAL',
    'Đại Lải Star Golf & Country Club', 'club-published',
    'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', CURRENT_DATE, now(), now()
FROM courses c WHERE c.id = 1421;

INSERT INTO scorecard_segments (scorecard_id, position, course_id)
VALUES (currval('scorecards_id_seq'), 1, 1421);

-- Stroke index stays null: the card supplied prints no index row, and a nine's
-- ranking depends on the eighteen it is played as half of, so đường A's and
-- B's cannot be borrowed.
INSERT INTO scorecard_holes (scorecard_id, hole_number, par, stroke_index)
SELECT currval('scorecards_id_seq'), c.hole, c.par, NULL FROM duong_c c;

-- One tee row per column, and the Red one is the ladies' because the card
-- says so.
INSERT INTO scorecard_tees (scorecard_id, name, gender)
VALUES (currval('scorecards_id_seq'), 'Black', 'UNSPECIFIED');
INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)
SELECT currval('scorecard_tees_id_seq'), c.hole, c.black FROM duong_c c;

INSERT INTO scorecard_tees (scorecard_id, name, gender)
VALUES (currval('scorecards_id_seq'), 'Blue', 'UNSPECIFIED');
INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)
SELECT currval('scorecard_tees_id_seq'), c.hole, c.blue FROM duong_c c;

INSERT INTO scorecard_tees (scorecard_id, name, gender)
VALUES (currval('scorecards_id_seq'), 'White', 'UNSPECIFIED');
INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)
SELECT currval('scorecard_tees_id_seq'), c.hole, c.white FROM duong_c c;

INSERT INTO scorecard_tees (scorecard_id, name, gender)
VALUES (currval('scorecards_id_seq'), 'Red', 'LADIES');
INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)
SELECT currval('scorecard_tees_id_seq'), c.hole, c.red FROM duong_c c;

SELECT (SELECT count(*) FROM holes WHERE course_id = 1421) AS duong_c_holes,
       (SELECT count(*) FROM scorecard_tee_yardages y
          JOIN scorecard_tees t ON t.id = y.scorecard_tee_id
          JOIN scorecard_segments g ON g.scorecard_id = t.scorecard_id
        WHERE g.course_id = 1421) AS duong_c_yardages;

COMMIT;
