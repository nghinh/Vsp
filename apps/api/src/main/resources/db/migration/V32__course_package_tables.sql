-- V32: Course package tables (Epic 4 — Offline Course Packages)
--
-- The package build/manifest entities (vnpt.vsp.module.pkg.entity.*) existed but
-- had no Flyway migration; unit tests masked this via Hibernate ddl-auto=create-drop
-- on H2. With Flyway-owned schema on PostgreSQL (ddl-auto=none) the tables were missing,
-- causing "relation \"package_build_job\" does not exist" at startup (job recovery in
-- PackageModuleConfig) and failures on any package API call.

-- ── Async package build jobs (Story 4.2) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS package_build_job (
    id                 UUID PRIMARY KEY,
    course_id          BIGINT NOT NULL,
    data_version_id    BIGINT NOT NULL,
    manifest_version   VARCHAR(255),
    status             VARCHAR(255) NOT NULL
        CHECK (status IN ('QUEUED','VALIDATING','BUILDING','ASSEMBLING',
                          'UPLOADING','PUBLISHING','COMPLETED','FAILED')),
    created_at         TIMESTAMPTZ NOT NULL,
    started_at         TIMESTAMPTZ,
    completed_at       TIMESTAMPTZ,
    error_code         VARCHAR(255),
    error_message      VARCHAR(255),
    error_detail       VARCHAR(255),
    triggered_by       VARCHAR(255) NOT NULL,
    build_duration_ms  BIGINT
);
CREATE INDEX IF NOT EXISTS idx_job_course_created ON package_build_job (course_id, created_at);
CREATE INDEX IF NOT EXISTS idx_job_status ON package_build_job (status);

-- ── Published course package manifest (Story 4.1) ────────────────────────────
CREATE TABLE IF NOT EXISTS course_package_manifest (
    id                       UUID PRIMARY KEY,
    course_id                BIGINT NOT NULL,
    data_version_id          BIGINT NOT NULL,
    version                  VARCHAR(255) NOT NULL,
    package_size_bytes       BIGINT NOT NULL,
    checksum                 VARCHAR(255) NOT NULL,
    effective_from           TIMESTAMPTZ NOT NULL,
    expires_at               TIMESTAMPTZ,
    minimum_client_version   VARCHAR(255) NOT NULL,
    tiles_format             VARCHAR(255) NOT NULL,
    tiles_url                VARCHAR(255) NOT NULL,
    geo_json_url             VARCHAR(255) NOT NULL,
    scorecard_url            VARCHAR(255),
    rules_url                VARCHAR(255),
    conditions_url           VARCHAR(255),
    metadata_url             VARCHAR(255),
    generated_at             TIMESTAMPTZ NOT NULL,
    generated_by             VARCHAR(255) NOT NULL,
    accuracy_class           VARCHAR(255),
    confidence               DOUBLE PRECISION,
    pin_snapshot_date        TIMESTAMPTZ,
    conditions_snapshot_date TIMESTAMPTZ,
    weather_snapshot_date    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_manifest_course ON course_package_manifest (course_id);
CREATE INDEX IF NOT EXISTS idx_manifest_course_version ON course_package_manifest (course_id, version);

-- ── Package file inventory (child of manifest) ───────────────────────────────
CREATE TABLE IF NOT EXISTS package_file_entry (
    id            UUID PRIMARY KEY,
    manifest_id   UUID NOT NULL REFERENCES course_package_manifest (id) ON DELETE CASCADE,
    path          VARCHAR(255) NOT NULL,
    checksum      VARCHAR(255) NOT NULL,
    size_bytes    BIGINT NOT NULL,
    content_type  VARCHAR(255) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_file_entry_manifest ON package_file_entry (manifest_id);

-- ── Package license (child of manifest) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS package_license (
    id            UUID PRIMARY KEY,
    manifest_id   UUID NOT NULL REFERENCES course_package_manifest (id) ON DELETE CASCADE,
    name          VARCHAR(255) NOT NULL,
    url           VARCHAR(255),
    spdx_id       VARCHAR(255)
);
CREATE INDEX IF NOT EXISTS idx_license_manifest ON package_license (manifest_id);
