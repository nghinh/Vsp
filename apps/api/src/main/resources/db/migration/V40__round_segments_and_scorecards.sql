-- A round is played on đường, and a club may have more than one.
--
-- Long Biên has đường A, B and C; Đại Lải the same; Kings Island has three
-- full eighteens. The database has carried one course per facility since the
-- nationwide seed, named "<facility> — Championship" and eighteen holes long,
-- so there has never been anywhere to say which nine a golfer walked.
--
-- That is not only a missing feature. `ScoreServiceImpl.resolvePar` looks par
-- up as `holes.find(course_id, hole_number)` — the round's hole number IS the
-- course's hole number — so the moment a 27-hole club is entered honestly,
-- hole 10 of an A+C round resolves to hole 10 of the 27, which belongs to B.
-- The wrong par lands in `score_entries.par` and every statistic derived from
-- it is quietly wrong. No error, no log line.
--
-- This migration adds the places to put the truth. Nothing reads them yet:
-- every existing round gets exactly one segment, which resolves to the same
-- hole it resolves to today.

-- ─── Which đường were played, in order ──────────────────────────────────────

CREATE TABLE round_segments (
    round_id  UUID     NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    position  SMALLINT NOT NULL CHECK (position BETWEEN 1 AND 4),
    course_id BIGINT   NOT NULL REFERENCES courses(id),
    PRIMARY KEY (round_id, position)
);

CREATE INDEX idx_round_segments_course ON round_segments (course_id);

COMMENT ON TABLE round_segments IS
    'The đường a round was played on, in playing order. One row for a round on '
    'a single eighteen, two for a 27-hole club''s A+B. Par for round hole N is '
    'resolved by walking these in order against each course''s holes_count.';

-- Every round already names a course, so none is left behind.
INSERT INTO round_segments (round_id, position, course_id)
SELECT id, 1, course_id FROM rounds WHERE course_id IS NOT NULL;

-- ─── The club's printed card ────────────────────────────────────────────────
--
-- Par could live on the hole, and does. Stroke index cannot: a club with
-- đường A, B and C prints a card per pairing, and the index on it runs 1..18
-- across the two nines it was printed for. Hole 3 of đường A is index 7 on the
-- A+B card and something else entirely on A+C. An index column on `holes`
-- would be storing one card's numbers and claiming they are the hole's.
--
-- So the card itself is the row. A scorecard names the pairing it was printed
-- for and carries eighteen numbered lines. A club with a single eighteen has
-- one card with one segment, which is the same shape with nothing special
-- about it.

CREATE TABLE scorecards (
    id           BIGSERIAL PRIMARY KEY,
    facility_id  BIGINT       NOT NULL REFERENCES golf_facilities(id) ON DELETE CASCADE,
    name         VARCHAR(255) NOT NULL,          -- 'A + B', "King's Course"
    holes_count  INTEGER      NOT NULL CHECK (holes_count IN (9, 18)),
    par_total    INTEGER,

    -- Same provenance columns every course table carries: a card typed in from
    -- a photograph is not the same claim as one from the club's own sheet.
    source              VARCHAR(255),
    publisher           VARCHAR(255) NOT NULL,
    license             VARCHAR(100),
    accuracy_class      VARCHAR(30),
    verification_status VARCHAR(20),
    effective_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_scorecard_facility_name UNIQUE (facility_id, name)
);

CREATE TABLE scorecard_segments (
    scorecard_id BIGINT   NOT NULL REFERENCES scorecards(id) ON DELETE CASCADE,
    position     SMALLINT NOT NULL CHECK (position BETWEEN 1 AND 2),
    course_id    BIGINT   NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (scorecard_id, position),
    CONSTRAINT uq_scorecard_segment_course UNIQUE (scorecard_id, course_id)
);

CREATE INDEX idx_scorecard_segments_course ON scorecard_segments (course_id);

CREATE TABLE scorecard_holes (
    scorecard_id BIGINT  NOT NULL REFERENCES scorecards(id) ON DELETE CASCADE,
    hole_number  INTEGER NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
    par          INTEGER NOT NULL CHECK (par BETWEEN 3 AND 6),
    stroke_index INTEGER CHECK (stroke_index BETWEEN 1 AND 18),
    PRIMARY KEY (scorecard_id, hole_number),
    -- An index is handed out once per card. Two holes sharing one is a typo,
    -- and a typo here misallocates strokes for every net score on that card.
    CONSTRAINT uq_scorecard_stroke_index UNIQUE (scorecard_id, stroke_index)
);

COMMENT ON TABLE scorecards IS
    'A card as the club prints it, for one pairing of đường. Stroke index is '
    'meaningful only against the pairing it was printed for, which is why it '
    'lives here and not on holes.';

-- ─── Scorecards arrive as corrections ───────────────────────────────────────
--
-- The review pipeline already exists: course_corrections (V23) carries
-- reporter, evidence, queue status and the approve / reject / request-info /
-- convert decisions, and the portal already renders it. What it cannot express
-- is a correction that is not geometric — every allowed type names a shape on
-- the ground. A card is par and stroke index for a whole pairing, submitted as
-- one photograph and reviewed as one decision.

ALTER TABLE course_corrections DROP CONSTRAINT chk_correction_type;
ALTER TABLE course_corrections ADD CONSTRAINT chk_correction_type CHECK (
    correction_type IN (
        'GEOMETRY', 'PIN_POSITION', 'BUNKER', 'WATER', 'OB',
        'CART_PATH', 'LANDMARK', 'COURSE_CONDITION', 'GREEN_SPEED',
        'SCORECARD', 'OTHER'
    )
);

-- The proposed card, exactly as the golfer read it off the photograph:
--   {"name":"A + B",
--    "segmentCourseIds":[12,13],
--    "holes":[{"hole":1,"par":4,"strokeIndex":7}, …]}
-- Approving turns this into a scorecards row and its eighteen lines.
ALTER TABLE course_corrections ADD COLUMN proposed_scorecard JSONB;

COMMENT ON COLUMN course_corrections.proposed_scorecard IS
    'SCORECARD corrections only: the pairing and its numbered lines, as read '
    'off one photograph. One card, one queue item, one decision.';

ALTER TABLE course_corrections ADD CONSTRAINT chk_correction_scorecard_payload
    CHECK (
        (correction_type = 'SCORECARD' AND proposed_scorecard IS NOT NULL)
        OR (correction_type <> 'SCORECARD' AND proposed_scorecard IS NULL)
    );
