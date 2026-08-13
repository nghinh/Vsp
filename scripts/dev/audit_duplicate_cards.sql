-- Which stored cards carry another course's pars and stroke indexes.
--
-- WHY THIS EXISTS
--
--   `load_operator_card.py` refuses an incoming card that matches one already
--   stored, but that check only guards the door. Nine fabricated cards were
--   loaded before anyone thought to compare the stored ones to each other, and
--   nothing in the tree could ask that question a second time. This asks it.
--
--   Every other check this project has tests a table against itself, and a
--   generated table passes all of them: the generator computes the totals from
--   the numbers it invented, so they agree perfectly. Twelve of the tables
--   supplied carried the same eighteen pars AND the same eighteen stroke
--   indexes as each other. Two real courses do not agree on all thirty-six of
--   those numbers, and a template does.
--
-- HOW TO READ THE OUTPUT
--
--   Section 1 empty is the answer you want. A row there names two or more
--   courses that cannot both be real, and the fix is to find which card is a
--   transcription and withdraw the rest — see 04e32a0 for what that took.
--
--   Section 2 is advisory and will not be empty. Real courses do share par
--   sequences: par is eighteen numbers drawn from {3,4,5}, and the seed wrote
--   one par card across every facility it created. A group here means only
--   "look", and a group whose members also share a stroke index row is already
--   in section 1.
--
-- USAGE
--
--   ssh ubuntu-docker "docker exec -i vsp-postgres psql -U vsp -d vsp" \
--     < scripts/dev/audit_duplicate_cards.sql

\pset footer off

CREATE TEMP VIEW card_signature AS
SELECT s.id,
       f.name || ' / ' || s.name                                        AS label,
       count(*)                                                         AS holes,
       string_agg(sh.par::text, ',' ORDER BY sh.hole_number)            AS pars,
       string_agg(sh.stroke_index::text, ',' ORDER BY sh.hole_number)
           FILTER (WHERE sh.stroke_index IS NOT NULL)                   AS indexes,
       count(sh.stroke_index)                                           AS index_count
FROM scorecards s
JOIN golf_facilities f ON f.id = s.facility_id
JOIN scorecard_holes sh ON sh.scorecard_id = s.id
GROUP BY s.id, f.name, s.name;

\echo
\echo '=== 1. Cards sharing a par sequence AND a stroke index sequence ==='
\echo '    (anything here is a template wearing two courses'' names)'
\echo

SELECT count(*)                                   AS courses,
       holes,
       string_agg(label, '; ' ORDER BY label)     AS sharing_this_card
FROM card_signature
-- A card with no index row cannot be compared this way, and par alone is far
-- too weak to condemn it on.
WHERE index_count = holes
GROUP BY pars, indexes, holes
HAVING count(*) > 1
ORDER BY count(*) DESC, holes;

\echo
\echo '=== 2. Cards sharing a par sequence only (advisory — look, do not act) ==='
\echo

SELECT count(*)                                   AS courses,
       holes,
       string_agg(label, '; ' ORDER BY label)     AS sharing_these_pars
FROM card_signature
GROUP BY pars, holes
HAVING count(*) > 1
ORDER BY count(*) DESC, holes;

\echo
\echo '=== 3. How much of the card set can be checked at all ==='
\echo

SELECT count(*)                                        AS cards,
       count(*) FILTER (WHERE index_count = holes)     AS with_a_full_index_row,
       count(*) FILTER (WHERE index_count = 0)         AS with_no_index_row,
       count(*) FILTER (WHERE index_count > 0
                          AND index_count < holes)     AS with_a_partial_index_row
FROM card_signature;
