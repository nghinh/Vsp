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

-- ─── Stroke index ───────────────────────────────────────────────────────────
--
-- Printed on the club's scorecard, present in no open dataset, and the last
-- thing standing between the app and net scoring. Nullable because it is
-- unknown for all 1,080 holes right now and will arrive one card at a time.

ALTER TABLE holes ADD COLUMN stroke_index INTEGER
    CONSTRAINT chk_holes_stroke_index CHECK (stroke_index BETWEEN 1 AND 18);

COMMENT ON COLUMN holes.stroke_index IS
    'Stroke index as printed on this đường''s own card. When two đường are '
    'combined the allocation is derived — odd to the first, even to the second.';

-- ─── Scorecards as a correction ─────────────────────────────────────────────
--
-- The review pipeline already exists: course_corrections carries reporter,
-- evidence, queue status and the approve / reject / request-info / convert
-- decisions, and the portal already renders it. What it cannot express is a
-- correction that is not geometric — every allowed type names a shape on the
-- ground. A scorecard is par and stroke index for a whole đường, submitted as
-- one photograph and reviewed as one decision.

ALTER TABLE course_corrections DROP CONSTRAINT chk_correction_type;
ALTER TABLE course_corrections ADD CONSTRAINT chk_correction_type CHECK (
    correction_type IN (
        'GEOMETRY', 'PIN_POSITION', 'BUNKER', 'WATER', 'OB',
        'CART_PATH', 'LANDMARK', 'COURSE_CONDITION', 'GREEN_SPEED',
        'SCORECARD', 'OTHER'
    )
);

ALTER TABLE course_corrections ADD COLUMN proposed_holes JSONB;

COMMENT ON COLUMN course_corrections.proposed_holes IS
    'SCORECARD corrections only: [{"hole":1,"par":4,"strokeIndex":7}, …] for '
    'the whole đường. One card, one queue item, one decision.';

-- A SCORECARD correction without its numbers is not reviewable, and a
-- geometric correction has no business carrying them.
ALTER TABLE course_corrections ADD CONSTRAINT chk_correction_scorecard_payload
    CHECK (
        (correction_type = 'SCORECARD' AND proposed_holes IS NOT NULL)
        OR (correction_type <> 'SCORECARD' AND proposed_holes IS NULL)
    );
