-- V1__audit_entries.sql
-- Flyway migration: creates audit_entries table for admin/course-data mutation audit logging.
-- Per NFR10: 7-year retention (2555 days) enforced via scheduled job, not DB constraint.
-- Per §13 Observability Architecture: correlation IDs link audit entries to request traces.

CREATE TABLE IF NOT EXISTS audit_entries (
    id              BIGSERIAL PRIMARY KEY,
    actor           VARCHAR(255) NOT NULL,          -- user id or 'SYSTEM'
    role            VARCHAR(100),                     -- RBAC role at time of action (nullable for system)
    action          VARCHAR(50)  NOT NULL,            -- AuditAction enum value
    object_type     VARCHAR(100) NOT NULL,            -- e.g. 'Course', 'Pin', 'Correction'
    object_id       VARCHAR(255),                     -- identifier of the affected entity
    before_json     TEXT,                             -- JSON snapshot before mutation (nullable)
    after_json      TEXT,                             -- JSON snapshot after mutation (nullable)
    metadata_json   TEXT,                             -- extra context: IP, user-agent, reason, etc.
    correlation_id  VARCHAR(100),                    -- request trace ID from MDC
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version         INTEGER NOT NULL DEFAULT 1       -- schema version for future migrations
);

-- Index for looking up all audit events on a given object (e.g. course history)
CREATE INDEX idx_audit_object ON audit_entries (object_type, object_id);

-- Index for querying audit trail by actor (e.g. "show all actions by this admin")
CREATE INDEX idx_audit_actor  ON audit_entries (actor, timestamp);

-- Index for querying audit trail by action type (e.g. "show all COURSE_PUBLISH events")
CREATE INDEX idx_audit_action ON audit_entries (action, timestamp);

-- Index for correlating audit entries with request traces
CREATE INDEX idx_audit_correlation ON audit_entries (correlation_id);

-- GIST index on bounding box (PostGIS geometry) for spatial audit queries if needed.
-- Requires PostGIS extension which is created in 001_baseline.sql.
-- Commented out so this migration runs even when PostGIS is not yet enabled.
-- CREATE INDEX idx_audit_location ON audit_entries USING GIST (ST_MakePoint(0, 0));
