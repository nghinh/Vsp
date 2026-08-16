-- Analysing a whole course from satellite imagery, one hole at a time.
--
-- A course is eighteen model calls, each of which takes seconds and costs
-- money. That is a background job, not a request a golfer waits on — and a
-- job that can be watched, resumed and counted, because the first question
-- after starting one is always "how far has it got".
--
-- The drafts themselves already have a home: draft_geometry_features, the
-- queue a golfer's geometry correction goes to. What they lacked is which
-- model drew them. When the next model version traces the same hole better,
-- the only way to tell the two apart — and to re-run the ones drawn by the
-- worse one — is to have written it down.

ALTER TABLE draft_geometry_features
    ADD COLUMN model_version VARCHAR(100),
    ADD COLUMN analysis_version INTEGER NOT NULL DEFAULT 1;

COMMENT ON COLUMN draft_geometry_features.model_version IS
    'Which vision model traced this, where it was traced rather than drawn by a human.';
COMMENT ON COLUMN draft_geometry_features.analysis_version IS
    'Which generation of this app''s analysis pipeline produced it.';

CREATE TABLE course_mapping_job (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id           BIGINT NOT NULL REFERENCES courses(id),
    status              VARCHAR(30) NOT NULL DEFAULT 'QUEUED',
    holes_total         INTEGER NOT NULL DEFAULT 0,
    holes_analysed      INTEGER NOT NULL DEFAULT 0,
    features_detected   INTEGER NOT NULL DEFAULT 0,
    holes_failed        INTEGER NOT NULL DEFAULT 0,
    model_version       VARCHAR(100),
    requested_by        VARCHAR(255) NOT NULL,
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,

    CONSTRAINT chk_course_mapping_job_status CHECK (status IN
        ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING', 'READY', 'FAILED'))
);

-- The poller claims the oldest queued job; the app asks for a course's most
-- recent one.
CREATE INDEX idx_course_mapping_job_queue
    ON course_mapping_job (status, created_at);
CREATE INDEX idx_course_mapping_job_course
    ON course_mapping_job (course_id, created_at DESC);

-- One course cannot be analysed twice at once: the second run would pay the
-- model again for the drafts the first is already writing.
CREATE UNIQUE INDEX uq_course_mapping_job_active
    ON course_mapping_job (course_id)
    WHERE status IN ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING');

COMMENT ON TABLE course_mapping_job IS
    'One satellite-analysis run over a course. Watchable, resumable, and countable — an 18-hole run is 18 metered model calls.';
