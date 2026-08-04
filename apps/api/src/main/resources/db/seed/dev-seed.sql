-- Dev-only seed data (runs after Hibernate creates the entity schema; Flyway is off in dev).
-- Idempotent: safe to run on every boot.

-- RBAC roles (Story 2.5). role_name is unique.
INSERT INTO roles (role_name, created_at, updated_at) VALUES
    ('SUPER_ADMIN',        now(), now()),
    ('COURSE_ADMIN',       now(), now()),
    ('GREENKEEPER',        now(), now()),
    ('TOURNAMENT_DIRECTOR', now(), now()),
    ('CADDIE_MASTER',      now(), now()),
    ('AUDITOR',            now(), now())
ON CONFLICT (role_name) DO NOTHING;
