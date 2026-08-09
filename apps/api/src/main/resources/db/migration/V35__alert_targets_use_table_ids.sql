-- Alert targets must be the ids the targeted tables actually have.
--
-- V22 declared facility_id, course_id and hole_id as UUID. The tables those
-- columns name have used BIGSERIAL keys since V16, so no value that could be
-- stored here has ever identified a facility, a course or a hole. Three of the
-- five targeting scopes were therefore unreachable: the portal's send form
-- asked an operator for a UUID that does not exist anywhere in the system, and
-- an alert saved with an invented one matched nothing on the way out.
--
-- flight_id and group_id stay UUID — flights really are keyed that way (V27).
--
-- No cast is needed or possible: the table is empty, and it could not have
-- held a meaningful value in the first place.

DROP INDEX IF EXISTS idx_course_alert_facility;
DROP INDEX IF EXISTS idx_course_alert_course;
DROP INDEX IF EXISTS idx_course_alert_hole;

ALTER TABLE course_alerts
    ALTER COLUMN facility_id TYPE BIGINT USING NULL,
    ALTER COLUMN course_id   TYPE BIGINT USING NULL,
    ALTER COLUMN hole_id     TYPE BIGINT USING NULL;

CREATE INDEX idx_course_alert_facility ON course_alerts(facility_id) WHERE facility_id IS NOT NULL;
CREATE INDEX idx_course_alert_course   ON course_alerts(course_id)   WHERE course_id   IS NOT NULL;
CREATE INDEX idx_course_alert_hole     ON course_alerts(hole_id)     WHERE hole_id     IS NOT NULL;

COMMENT ON COLUMN course_alerts.facility_id IS 'golf_facilities.id — BIGINT, see V35';
COMMENT ON COLUMN course_alerts.course_id   IS 'courses.id — BIGINT, see V35';
COMMENT ON COLUMN course_alerts.hole_id     IS 'holes.id — BIGINT, see V35';
