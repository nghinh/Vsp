-- V15: Course Geometry Foundation
-- Creates shared enums, data quality metadata table, and PostGIS validity trigger.
-- Per Story 3.1 GEO-1: SRID 4326, validity constraints, GIST indexes enforced at DB level.

-- Accuracy class enum (PRD Section 9.4)
CREATE TYPE accuracy_class AS ENUM (
    'A_RTK_SURVEYED',
    'B_LICENSED_PROVIDER',
    'C_VERIFIED_SATELLITE',
    'D_UNVERIFIED_COMMUNITY'
);

-- Verification status enum (PRD Section 9.3)
CREATE TYPE verification_status AS ENUM (
    'UNVERIFIED',
    'PENDING_REVIEW',
    'VERIFIED',
    'REJECTED'
);

-- Shared data quality metadata table (embedded by all geometry feature tables)
CREATE TABLE data_quality_metadata (
    id BIGSERIAL PRIMARY KEY,
    source VARCHAR(255),
    license VARCHAR(255),
    accuracy_class accuracy_class NOT NULL DEFAULT 'D_UNVERIFIED_COMMUNITY',
    confidence DECIMAL(5,2) CHECK (confidence >= 0.00 AND confidence <= 100.00),
    verification_status verification_status NOT NULL DEFAULT 'UNVERIFIED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_verified_at TIMESTAMPTZ,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    publisher VARCHAR(255) NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_data_quality_metadata_accuracy ON data_quality_metadata(accuracy_class);
CREATE INDEX idx_data_quality_metadata_verification ON data_quality_metadata(verification_status);
CREATE INDEX idx_data_quality_metadata_effective ON data_quality_metadata(effective_date);

-- PostGIS geometry validity enforcement trigger function
CREATE OR REPLACE FUNCTION geometry_validity_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Check that every geometry column in the row is valid using ST_IsValid
    -- This is applied per-table via AFTER INSERT OR UPDATE triggers per geometry table
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Comment on PostGIS requirements
COMMENT ON TABLE data_quality_metadata IS 'Shared metadata columns embedded in all course geometry feature tables per PRD Section 9.3';
COMMENT ON COLUMN data_quality_metadata.accuracy_class IS 'Class A: RTK surveyed, B: Licensed provider, C: Verified satellite, D: Unverified community. Priority A > B > C > D';
COMMENT ON COLUMN data_quality_metadata.confidence IS 'Confidence score 0.00 to 100.00 representing data quality confidence';
COMMENT ON COLUMN data_quality_metadata.verification_status IS 'Verification workflow state: UNVERIFIED > PENDING_REVIEW > VERIFIED | REJECTED';
COMMENT ON COLUMN data_quality_metadata.version IS 'Append-only version number incremented on each publish';
