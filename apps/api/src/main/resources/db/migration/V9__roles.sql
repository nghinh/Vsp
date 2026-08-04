-- V9__roles.sql
-- Flyway migration: creates roles table for RBAC.
-- Per Story 2.5 AC-1: 6 role types for portal RBAC.
-- Per Architecture §10 Portal Architecture: Super Admin, Course Admin, Greenkeeper,
--   Tournament Director, Caddie Master, Read-only Auditor.
-- Per PRD §10.6 Security: MFA for admins, RBAC on portal and APIs.

CREATE TABLE roles (
    id                      BIGSERIAL PRIMARY KEY,
    role_name               VARCHAR(50) NOT NULL UNIQUE,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_role_name CHECK (
        role_name IN (
            'SUPER_ADMIN',
            'COURSE_ADMIN',
            'GREENKEEPER',
            'TOURNAMENT_DIRECTOR',
            'CADDIE_MASTER',
            'AUDITOR'
        )
    )
);

-- Index for fast lookup by role name
CREATE UNIQUE INDEX idx_roles_name ON roles (role_name);

-- Seed the 6 defined roles
INSERT INTO roles (role_name) VALUES
    ('SUPER_ADMIN'),
    ('COURSE_ADMIN'),
    ('GREENKEEPER'),
    ('TOURNAMENT_DIRECTOR'),
    ('CADDIE_MASTER'),
    ('AUDITOR');

COMMENT ON TABLE roles IS 'RBAC role definitions. Per Story 2.5 AC-1: 6 roles.';
COMMENT ON COLUMN roles.role_name IS 'One of: SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR.';
