-- The two ratings a card prints for one tee, and the two index rows.
--
-- WHAT WAS WRONG
--
--   A course is rated separately for men and for women — the handicap system
--   requires it, and a card that prints ratings prints both. `scorecard_tees`
--   had one course_rating and one slope_rating per tee and a UNIQUE
--   (scorecard_id, name), so a card rating its RED tee 68.2/118 for men and
--   72.4/128 for women could hold exactly one of them.
--
--   Worse, the loss was silent. The reader drops a tee row whose name it has
--   already seen, on the sound reasoning that a repeated name is the same
--   column read twice — and a card's two RED rows are not that. Whichever the
--   model happened to emit second went on the floor with no trace anywhere.
--
--   The stroke index has the same shape. Many Vietnamese cards print a second
--   index row for the ladies' tees, because the ranking of a hole's difficulty
--   changes with the distance played. `scorecard_holes` had one stroke_index.
--
-- WHAT THIS DOES
--
--   Adds `gender` to the tee row, so a card can carry both of its RED rows,
--   and widens the unique constraint to match. NOT NULL with an UNSPECIFIED
--   default rather than a nullable column: two NULLs are distinct to a unique
--   index in Postgres, so a nullable gender would let the same tee in twice
--   and quietly reintroduce the problem it is here to solve.
--
--   Adds `stroke_index_ladies` alongside `stroke_index`, rather than putting
--   gender into the hole's primary key. The card prints two rows against one
--   set of hole numbers; modelling it as two columns says that, and leaves
--   (scorecard_id, hole_number) meaning what it has always meant.
--
--   Every row that exists keeps its meaning: an existing rating was read off a
--   card without anyone recording whose it was, and UNSPECIFIED is the honest
--   name for that. It is not silently relabelled as men's.

ALTER TABLE scorecard_tees
    ADD COLUMN gender VARCHAR(16) NOT NULL DEFAULT 'UNSPECIFIED'
        CHECK (gender IN ('MEN', 'LADIES', 'UNSPECIFIED'));

ALTER TABLE scorecard_tees
    DROP CONSTRAINT uq_scorecard_tee_name;

ALTER TABLE scorecard_tees
    ADD CONSTRAINT uq_scorecard_tee_name UNIQUE (scorecard_id, name, gender);

ALTER TABLE scorecard_holes
    ADD COLUMN stroke_index_ladies INTEGER
        CHECK (stroke_index_ladies BETWEEN 1 AND 18);

COMMENT ON COLUMN scorecard_tees.gender IS
    'Whose rating this row carries. UNSPECIFIED where the card does not say, '
    'which is most of them — not a synonym for men.';

COMMENT ON COLUMN scorecard_holes.stroke_index_ladies IS
    'The ladies index row, where the card prints a second one. Null means the '
    'card printed one index row, not that women play the hole unranked.';
