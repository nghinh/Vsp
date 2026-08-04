-- V11__admin_role_assignments.sql
-- Flyway migration: creates admin_role_assignments join table for RBAC.
-- Per Story 2.5 AC-1: Role-based access control with 6 role types.
-- Per Architecture §10 Portal Architecture and §12 Security: RBAC on portal and APIs.

CREATE TABLE admin_role_assignments (
    id                          BIGSERIAL PRIMARY KEY,
    admin_account_id            BIGINT NOT NULL REFERENCES admin_accounts(id) ON DELETE CASCADE,

    -- Role reference (denormalised VARCHAR for query simplicity — role_name validated by FK to roles table via trigger)
    role_name                   VARCHAR(50) NOT NULL,

    -- Assignment audit trail
    assigned_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by                 BIGINT REFERENCES admin_accounts(id),

    -- Constraints
    CONSTRAINT chk_assignment_role CHECK (
        role_name IN (
            'SUPER_ADMIN',
            'COURSE_ADMIN',
            'GREENKEEPER',
            'TOURNAMENT_DIRECTOR',
            'CADDIE_MASTER',
            'AUDITOR'
        )
    ),
    CONSTRAINT uk_admin_role UNIQUE (admin_account_id, role_name)
);

-- Indexes for fast lookup
CREATE INDEX idx_admin_roles_admin ON admin_role_assignments (admin_account_id);
CREATE INDEX idx_admin_roles_role ON admin_role_assignments (role_name);
CREATE INDEX idx_admin_roles_assigner ON admin_role_assignments (assigned_by);

COMMENT ON TABLE admin_role_assignments IS 'Join table: AdminAccount → Role. One admin may have multiple roles.';
COMMENT ON COLUMN admin_role_assignments.role_name IS 'One of: SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR.';
