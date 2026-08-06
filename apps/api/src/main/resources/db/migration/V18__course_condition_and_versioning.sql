-- V18: Course Condition and Versioning Tables
-- Per Story 3.1 GEO-4: append-versioned course data state and audit.

-- Course conditions
CREATE TABLE course_conditions (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    condition_type VARCHAR(100),
    severity VARCHAR(50),
    description TEXT,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_course_conditions_course ON course_conditions(course_id);
CREATE INDEX idx_course_conditions_effective ON course_conditions(effective_date);
CREATE INDEX idx_course_conditions_expiry ON course_conditions(expiry_date);

-- Data versions (append-only: DRAFT -> PUBLISHED -> ARCHIVED)
CREATE TABLE data_versions (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    published_at TIMESTAMPTZ,
    published_by VARCHAR(255),
    publish_note TEXT,
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_course_version UNIQUE (course_id, version_number)
);
CREATE INDEX idx_data_versions_course ON data_versions(course_id);
CREATE INDEX idx_data_versions_status ON data_versions(status);

-- Data licenses
CREATE TABLE data_licenses (
    id BIGSERIAL PRIMARY KEY,
    data_version_id BIGINT NOT NULL REFERENCES data_versions(id) ON DELETE CASCADE,
    license_type VARCHAR(100),
    licensee VARCHAR(255),
    license_key VARCHAR(255),
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_data_licenses_version ON data_licenses(data_version_id);
CREATE INDEX idx_data_licenses_effective ON data_licenses(effective_date);

COMMENT ON TABLE data_versions IS 'Append-only course data versions: DRAFT -> PUBLISHED -> ARCHIVED. Per architecture §7.3';
