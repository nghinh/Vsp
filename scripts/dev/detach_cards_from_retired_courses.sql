-- A card cannot cover a course nobody is offered.
--
-- Kings Island's photographed card is segmented onto two eighteen-hole
-- courses: the seed's invented "— Championship" and the real Kings Course. An
-- eighteen-hole card therefore claimed to span thirty-six holes. Nothing
-- checked that until validate() learned to, and by then the row existed.
--
-- Now that the invented course is retired, the segment pointing at it is
-- straightforwardly wrong: it maps a golfer's card onto a course no golfer can
-- reach. Dropping it leaves the card on the one course it was printed for.
--
-- Only segments pointing at a retired course are dropped, and only where the
-- card still has another segment left — a card whose every segment is retired
-- would be left attached to nothing, which is worse than the inconsistency.
--
-- What this does NOT settle: whether the card's pars are right. It disagrees
-- with Kings Course on ten of eighteen holes, and Mountain View's and
-- Lakeside's cards match their courses exactly, so the fault is specific to
-- this one. Settling it needs the club's own card photographed, not a
-- migration.

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE detaching ON COMMIT DROP AS
SELECT g.scorecard_id, g.course_id, s.name AS card_name, c.name AS course_name
FROM scorecard_segments g
JOIN courses c ON c.id = g.course_id
JOIN scorecards s ON s.id = g.scorecard_id
WHERE c.expiry_date IS NOT NULL
  AND (SELECT count(*) FROM scorecard_segments g2
        JOIN courses c2 ON c2.id = g2.course_id
       WHERE g2.scorecard_id = g.scorecard_id
         AND c2.expiry_date IS NULL) >= 1;

SELECT card_name || ' → ' || course_name AS detached FROM detaching;

DELETE FROM scorecard_segments g
 USING detaching d
 WHERE g.scorecard_id = d.scorecard_id AND g.course_id = d.course_id;

-- Close the gap the delete leaves, so position still reads 1..n in order.
WITH renumbered AS (
    SELECT scorecard_id, course_id,
           row_number() OVER (PARTITION BY scorecard_id ORDER BY position) AS pos
    FROM scorecard_segments
    WHERE scorecard_id IN (SELECT scorecard_id FROM detaching)
)
UPDATE scorecard_segments g
   SET position = r.pos
  FROM renumbered r
 WHERE g.scorecard_id = r.scorecard_id AND g.course_id = r.course_id;

SELECT s.id, s.name, s.holes_count,
       string_agg(c.name, ' + ' ORDER BY g.position) AS now_covers
FROM scorecards s
JOIN scorecard_segments g ON g.scorecard_id = s.id
JOIN courses c ON c.id = g.course_id
WHERE s.id IN (SELECT scorecard_id FROM detaching)
GROUP BY s.id, s.name, s.holes_count;

COMMIT;
