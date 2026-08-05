-- Golfer-submitted geometry corrections and community corroboration.
--
-- Extends `course_corrections` (V23) so a golfer standing on the course can
-- report that a specific geometry LAYER of a hole is wrong and hand us the
-- shape they believe is right — a drawn polygon, or the point where they are
-- standing. V23 only carried the reporter's own GPS fix, which says where the
-- reporter was, not what they claim the feature should be.
--
-- Aggregation: repeated independent reports for the same hole+layer that land
-- within 15 m of each other corroborate one another. `corroboration_count`
-- records the size of that cluster and `verification_status` is promoted to
-- PENDING_REVIEW once it reaches the threshold, which is what surfaces the
-- cluster to admins. Nothing is ever promoted to VERIFIED automatically —
-- that transition stays with a human reviewer.

ALTER TABLE course_corrections
    ADD COLUMN IF NOT EXISTS geometry_layer      VARCHAR(20),
    ADD COLUMN IF NOT EXISTS proposed_geometry   geometry(Geometry, 4326),
    ADD COLUMN IF NOT EXISTS gps_accuracy_meters DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS corroboration_count INTEGER NOT NULL DEFAULT 1;

-- V23 never created this column even though the entity and the Story 9.3
-- publish path have always written it; add it here so a Flyway-built schema
-- matches the Hibernate-built one the app actually runs on in dev.
ALTER TABLE course_corrections
    ADD COLUMN IF NOT EXISTS resulting_version_id BIGINT;

ALTER TABLE course_corrections
    ADD CONSTRAINT chk_correction_geometry_layer CHECK (
        geometry_layer IS NULL
        OR geometry_layer IN ('GREEN', 'FAIRWAY', 'BUNKER', 'WATER', 'OB')
    );

ALTER TABLE course_corrections
    ADD CONSTRAINT chk_correction_gps_accuracy CHECK (
        gps_accuracy_meters IS NULL
        OR (gps_accuracy_meters >= 0 AND gps_accuracy_meters <= 100)
    );

-- The corroboration query is always scoped to one hole and one layer first,
-- then filtered by distance, so this composite index bounds the candidate set.
CREATE INDEX IF NOT EXISTS idx_correction_hole_layer
    ON course_corrections (hole_id, geometry_layer)
    WHERE geometry_layer IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_correction_proposed_geometry
    ON course_corrections USING GIST (proposed_geometry);
