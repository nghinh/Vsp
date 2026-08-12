-- The tee rows of a club's card.
--
-- A score only means something against the tee it was played from: the same
-- 82 is a different round off 7,311 yards than off 5,631. Course rating and
-- slope are what turn it into a handicap differential at all. None of it is
-- in the database today — `tee_sets` carries a name and a par and nothing
-- else, and `tee_boxes` holds geometry, so a card's five tee rows, their
-- yardages and their ratings have had nowhere to go.
--
-- They are attached to the card rather than to the course because that is
-- where they are printed and how they are read: one photograph, one review,
-- one row per tee. A club that reprints its card with new ratings replaces
-- the card, and the tees go with it.

CREATE TABLE scorecard_tees (
    id            BIGSERIAL PRIMARY KEY,
    scorecard_id  BIGINT       NOT NULL REFERENCES scorecards(id) ON DELETE CASCADE,
    name          VARCHAR(60)  NOT NULL,

    -- Both nullable: plenty of cards print yardages and no ratings at all,
    -- and a card read from a photograph may have had the rating table cut
    -- off. The ranges are what a rated course can actually carry.
    course_rating NUMERIC(4,1) CHECK (course_rating BETWEEN 60.0 AND 80.0),
    slope_rating  INTEGER      CHECK (slope_rating BETWEEN 55 AND 155),

    CONSTRAINT uq_scorecard_tee_name UNIQUE (scorecard_id, name)
);

CREATE TABLE scorecard_tee_yardages (
    scorecard_tee_id BIGINT  NOT NULL REFERENCES scorecard_tees(id) ON DELETE CASCADE,
    hole_number      INTEGER NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
    yards            INTEGER NOT NULL CHECK (yards BETWEEN 60 AND 700),
    PRIMARY KEY (scorecard_tee_id, hole_number)
);

COMMENT ON TABLE scorecard_tees IS
    'One tee row of a printed card: its name, its rating, and its yardages. '
    'Attached to the card because that is where a club publishes them.';
