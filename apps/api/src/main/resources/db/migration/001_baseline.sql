-- 001_baseline.sql
-- Creates PostGIS extension and schema_version table.
-- No domain tables are created in this baseline — those belong to later epics.

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Schema version tracking table (used by Flyway convention)
CREATE TABLE IF NOT EXISTS schema_version (
    version_rank INTEGER NOT NULL DEFAULT 0,
    installed_rank INTEGER NOT NULL DEFAULT 0,
    version VARCHAR(50) NOT NULL,
    description VARCHAR(200) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'SQL',
    checksum INTEGER,
    installed_by VARCHAR(100) NOT NULL,
    installed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_time INTEGER,
    success BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (version)
);
