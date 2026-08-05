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

-- ─────────────────────────────────────────────────────────────────────────────
-- Dev admin account
--
--     email:    admin@vsp.local
--     password: Admin2026
--
-- Sign in through the ordinary golfer login — POST /auth/login with
-- {"identifier":"admin@vsp.local","password":"Admin2026"} — and send the
-- returned accessToken as `Authorization: Bearer …` to any /admin/** endpoint.
-- There is no separate admin login: an admin *is* a golfer_accounts row that
-- also has an admin_accounts row, and RoleServiceImpl.hasRole resolves the JWT
-- principal (a golfer account id) through admin_accounts to its role
-- assignments. Seeding only the roles table, as this file used to, left
-- admin_accounts empty, so every /admin/** call was answered
-- VSP-ERR-AUTH-005 and the admin half of the product could not be run at all.
--
-- The password hash is a literal because the seed has to be deterministic and
-- re-runnable, and because BCrypt salts every call differently — computing it
-- here is not an option. It is BCrypt cost 10, produced by the very encoder the
-- auth module verifies against (PasswordService → BCryptPasswordEncoder), so
-- login treats this row exactly like a registered account.
--
-- Dev only: this file is loaded from application-dev.yml and nothing else reads
-- it, so no other profile can grow an account with a published password.
INSERT INTO golfer_accounts (email, password_hash, display_name, status, verified_at, created_at, updated_at)
VALUES (
    'admin@vsp.local',
    '$2a$10$.GFQQpZvjdDOUAu8uM.RMen6lKkqif1T8mfW817kQFeYovv10V23G',  -- Admin2026
    'Dev Admin',
    'ACTIVE',
    now(), now(), now()
)
ON CONFLICT (email) DO NOTHING;

-- Promote it to an admin. mfa_enabled = false: MFA is enrolled through
-- /admin/mfa, and requiring it here would make the account unusable on the
-- first boot, which is the one thing this seed exists to prevent.
INSERT INTO admin_accounts (golfer_account_id, mfa_enabled, created_at, updated_at)
SELECT id, false, now(), now()
FROM golfer_accounts
WHERE email = 'admin@vsp.local'
ON CONFLICT (golfer_account_id) DO NOTHING;

-- Every role, deliberately. The /admin/** controllers gate on four different
-- roles (SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, AUDITOR) and no single role
-- opens all of them, so one account holding all six is what makes the whole
-- admin surface reachable from one login. Testing that a role is *denied*
-- something needs a second, narrower account — this one can do everything.
INSERT INTO admin_role_assignments (admin_account_id, role_name, assigned_at)
SELECT a.id, r.role_name, now()
FROM admin_accounts a
JOIN golfer_accounts g ON g.id = a.golfer_account_id
CROSS JOIN (VALUES
    ('SUPER_ADMIN'),
    ('COURSE_ADMIN'),
    ('GREENKEEPER'),
    ('TOURNAMENT_DIRECTOR'),
    ('CADDIE_MASTER'),
    ('AUDITOR')
) AS r(role_name)
WHERE g.email = 'admin@vsp.local'
ON CONFLICT (admin_account_id, role_name) DO NOTHING;
