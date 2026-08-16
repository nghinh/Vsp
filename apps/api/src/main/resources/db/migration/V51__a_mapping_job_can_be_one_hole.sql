-- A golfer standing on an unmapped hole asks for that hole, not the course.
--
-- Tracing eighteen holes because somebody opened the 7th is eighteen metered
-- model calls for one hole's worth of use. So a job can now name a hole, and
-- the same queue, worker and status endpoint carry both shapes: the admin's
-- whole-course run and the golfer's one-hole request.
--
-- The uniqueness rule follows the same idea. One course cannot be traced
-- twice at once, and neither can one hole — but a hole request must not be
-- blocked by another hole's request on the same course, which is what the
-- old course-wide unique index would have done.

ALTER TABLE course_mapping_job
    ADD COLUMN hole_number INTEGER;

COMMENT ON COLUMN course_mapping_job.hole_number IS
    'The single hole this run covers, or null for the whole course.';

DROP INDEX IF EXISTS uq_course_mapping_job_active;

-- Whole-course runs: one at a time per course.
CREATE UNIQUE INDEX uq_course_mapping_job_active_course
    ON course_mapping_job (course_id)
    WHERE hole_number IS NULL
      AND status IN ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING');

-- Single-hole runs: one at a time per hole.
CREATE UNIQUE INDEX uq_course_mapping_job_active_hole
    ON course_mapping_job (course_id, hole_number)
    WHERE hole_number IS NOT NULL
      AND status IN ('QUEUED', 'FETCHING_IMAGERY', 'ANALYSING');

-- What the daily limit counts: who asked, and when.
CREATE INDEX idx_course_mapping_job_requester
    ON course_mapping_job (requested_by, created_at DESC);
