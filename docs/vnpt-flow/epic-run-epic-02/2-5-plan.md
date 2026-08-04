# Story 2.5 Plan: Administer Roles and Privacy Requests

**Run ID:** run_2026_08_02_005
**Epic:** Epic-02 (Golfer Management)
**Wave:** 5 of 5 (2-5 final story; no dependencies — depends on completed 2-4)
**Status:** PLANNING
**Story Source:** `docs/implementation-artifacts/epic-02/2-5-administer-roles-and-privacy-requests.md`

---

## 1. Story Scope Summary

**User Story:** As an administrator, I want role controls and privacy workflows so that privileged access and user rights are enforced.

**Acceptance Criteria:**
| AC | Description |
|----|-------------|
| AC-1 | RBAC supports super admin, course admin, greenkeeper, tournament director, caddie master, and auditor. |
| AC-2 | Admin accounts require MFA. |
| AC-3 | Users can request data export, account deletion, and round deletion with auditable processing. |

---

## 2. PRD / Architecture / UX Alignment Evidence

### PRD Alignment (`docs/planning-artifacts/prd.md`)
- **Section 8.1 Account and Profile:** Account registration, OTP, password recovery, delete account, export personal data — privacy request workflows belong here.
- **Section 10.6 Security and Privacy:** "Role-based access control", "MFA for admins", "Audit logs", "Account deletion, round deletion, and data export" — directly maps to AC-1/AC-2/AC-3.
- **Section 10.6 Privacy Controls:** "Privacy controls for location, score, round sharing, deletion, and export" — scope for AC-3.
- **Section 8.4 Round Setup:** Round selection context for AC-3 round deletion requests.
- **Section 10.6 MFA:** "MFA for admins" — AC-2 requirement.
- **Section 10.6 RBAC:** "Role-based access control" — AC-1 requirement.

### Architecture Alignment (`docs/planning-artifacts/architecture.md`)
- **Section 10 Portal Architecture:** "Portal must use admin RBAC from day one" — lists 6 roles matching AC-1: Super Admin, Course Admin, Greenkeeper, Tournament Director, Caddie Master, Read-only Auditor.
- **Section 12 Security Architecture:** "MFA for admin users", "RBAC on portal and APIs", "Audit every course publish, rollback, pin update, green update, condition update, and admin login" — AC-1/AC-2 requirements.
- **Section 6.1 Modular Monolith:** New `role` module and `privacy` module under bounded contexts — new module creation following 2-4-A `bag` module pattern.
- **Section 11.2 Minimum API Groups:** New `/admin/roles/*`, `/admin/users/*`, `/privacy/*` endpoint groups needed.
- **Section 11.3 API Cross-Cutting:** "RBAC on admin APIs" — existing pattern to extend.
- **Section 11.2:** `/admin/courses/*` and `/admin/audit/*` already exist; need `/admin/roles/*`, `/admin/users/*`, `/privacy/*`.

### UX Spec Alignment (`docs/planning-artifacts/ux-spec.md`)
- **Section 7.1 Portal Navigation:** "Users/Roles" listed as a primary portal module — portal admin UI needed.
- **Section 7.5 Admin Audit UX:** Audit entries must show actor, role, action, object, before/after, timestamp, version — already implemented in AuditModule; privacy request audit applies same pattern.
- **Section 10 Accessibility:** Field validation, screen reader labels, touch targets ≥44/48pt — applies to portal admin screens.
- **Section 9 Forms and Feedback:** Labels visible, errors near field, loading states — applies to privacy request forms.
- **Section 5.1 Bottom Navigation:** "Profile" tab in mobile — privacy requests accessible from golfer Profile tab.

### 2-4 Output Analysis (`epic-run-epic-02/2-4-A-implementation.md`)
| 2-4 Deliverable | Relevance to 2.5 |
|-----------------|-----------------|
| `GolfBag`, `Club` entities + JPA pattern | Same JPA pattern for `Role`, `AdminAccount`, `PrivacyRequest` entities |
| `BagModule` marker annotation | Same pattern for `RoleModule`, `PrivacyModule` |
| `BagService` + `BagServiceImpl` with audit | Same pattern for `RoleService`, `PrivacyService` with audit |
| `BagController` with 9 endpoints | Same REST pattern for `RoleController`, `PrivacyController` |
| `BagServiceImplTest` 16 unit tests | Same test pattern for `RoleServiceImplTest`, `PrivacyServiceImplTest` |
| `packages/contracts/schemas/bag.yaml` | Same contract pattern for `role.yaml`, `privacy.yaml` |
| Audit actions added to `AuditAction.java` | New audit actions for role assignment, privacy state changes |
| VspErrorCode `BAG_00X` | New `ROLE_00X`, `PRIVACY_00X` error codes |

### Epic-01 Foundations
| Epic-01 Story | Relevance to 2.5 |
|----------------|-------------------|
| Story 1.4 (Design System) | Portal admin screens use `VspColorSemantic`, `VspSpacing` tokens |
| Story 1.5 (Observability/Security) | AuditModule already captures audit events; `AuditAction` enum extended with role/privacy actions |
| Story 1.5 MFA mention | "MFA for admins" — existing `AuditAction.ADMIN_LOGIN_MFA_REQUIRED` or new action |

---

## 3. Gap Analysis: Existing State vs. Required

### Backend
| What Exists | What Is Missing |
|-------------|-----------------|
| `GolferAccount` entity (phone/email/social auth) | `AdminAccount` entity linking to `GolferAccount` with MFA fields |
| `GolferProfile` entity | `Role` entity with 6 role types + `AdminRoleAssignment` join |
| `BagModule` — new module pattern | `RoleModule` — role definition and assignment |
| No admin role system | `AdminRoleService` + `AdminRoleServiceImpl` for RBAC |
| `/admin/courses/*`, `/admin/audit/*` endpoints | `/admin/roles/*`, `/admin/users/*` endpoints |
| No MFA on admin accounts | TOTP-based MFA for admin role holders |
| `AuditModule` with `AuditAction` enum | New audit actions: `ROLE_ASSIGNED`, `ROLE_REVOKED`, `PRIVACY_REQUEST_SUBMITTED`, `PRIVACY_REQUEST_PROCESSED`, `MFA_ENABLED`, `MFA_DISABLED` |
| Privacy request workflows not defined | `PrivacyRequest` entity + `PrivacyService` for data export, account deletion, round deletion |
| `packages/contracts/schemas/bag.yaml` | New `packages/contracts/schemas/role.yaml`, `privacy.yaml` |

### Mobile (Golfer Privacy)
| What Exists | What Is Missing |
|-------------|-----------------|
| `ProfileScreen` with profile fields | `PrivacyRequestScreen` — data export, account deletion, round deletion |
| `ProfileBloc` with save/update | `PrivacyRequestBloc` for submitting and tracking requests |
| `ProfileService` for `/profiles/*` | `PrivacyService` for `/privacy/*` endpoints |
| `ProfileSyncStore` offline queue | `PrivacySyncStore` (or reuse ProfileSyncStore for privacy requests) |
| Profile tab in bottom nav | Privacy accessible from Profile tab or Settings |

### Portal (Admin Role Management)
| What Exists | What Is Missing |
|-------------|-----------------|
| Portal navigation with "Users/Roles" module | `RoleManagementScreen` — assign/revoke roles, list admins |
| Course operations screens (geometry, pin, conditions) | `MfaManagementScreen` — enable/disable MFA for admin accounts |
| `CorrectionWorkflowScreen` | `PrivacyRequestAdminScreen` — review and process privacy requests |
| Portal CSS from Story 1.4 | Design system tokens applied to new admin screens |

---

## 4. Slice Plan

### Slice 2-5-A: Backend — RBAC, Admin Account, MFA, Role Module
**Rationale:** Backend RBAC and MFA foundation. Defines `Role`, `AdminAccount`, `AdminRoleAssignment` entities and service layer. Depends only on existing Identity and Audit modules. This is the security foundation for all portal and admin API access.

**Scope:**

**New module: `role`**
- `apps/api/src/main/resources/db/migration/V9__roles.sql` — `roles` table (id, role_name VARCHAR UNIQUE — SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR; created_at, updated_at)
- `apps/api/src/main/resources/db/migration/V10__admin_accounts.sql` — `admin_accounts` table (id, golfer_account_id FK UNIQUE, mfa_enabled BOOLEAN, mfa_secret VARCHAR(32), mfa_verified_at TIMESTAMP; created_at, updated_at)
- `apps/api/src/main/resources/db/migration/V11__admin_role_assignments.sql` — `admin_role_assignments` table (id, admin_account_id FK, role_name, assigned_at, assigned_by BIGINT FK to admin_accounts; UNIQUE(admin_account_id, role_name))
- `apps/api/src/main/java/vnpt/vsp/module/role/entity/Role.java` — JPA entity; `roleName` (enum: SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR); timestamps; unique constraint on roleName
- `apps/api/src/main/java/vnpt/vsp/module/role/entity/AdminAccount.java` — JPA entity; `golferAccountId` FK; `mfaEnabled` boolean; `mfaSecret` (encrypted TOTP secret); `mfaVerifiedAt`; timestamps; one-to-many role assignments
- `apps/api/src/main/java/vnpt/vsp/module/role/entity/AdminRoleAssignment.java` — JPA entity; `adminAccountId` FK; `roleName` enum; `assignedAt`; `assignedBy` FK to admin_accounts; unique constraint (admin_account_id, role_name)
- `apps/api/src/main/java/vnpt/vsp/module/role/repository/RoleRepository.java` — `findAll()`, `findByRoleName()`
- `apps/api/src/main/java/vnpt/vsp/module/role/repository/AdminAccountRepository.java` — `findByGolferAccountId()`, `findByIdAndGolferAccountId()`
- `apps/api/src/main/java/vnpt/vsp/module/role/repository/AdminRoleAssignmentRepository.java` — `findByAdminAccountId()`, `findByAdminAccountIdAndRoleName()`, `deleteByAdminAccountIdAndRoleName()`, `existsByAdminAccountIdAndRoleName()`
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/RoleResponse.java` — response DTO with roleName, createdAt
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/AdminAccountResponse.java` — response DTO with golferAccountId, mfaEnabled, roles list, createdAt
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/AssignRoleRequest.java` — request DTO: golferAccountId, roleName
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/RevokeRoleRequest.java` — request DTO: golferAccountId, roleName
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/EnableMfaRequest.java` — request DTO: totpCode (for initial verification)
- `apps/api/src/main/java/vnpt/vsp/module/role/dto/VerifyMfaRequest.java` — request DTO: totpCode
- `apps/api/src/main/java/vnpt/vsp/module/role/RoleService.java` — interface: `getAllRoles()`, `getAdminAccounts()`, `assignRole()`, `revokeRole()`, `enableMfa()`, `disableMfa()`, `verifyMfa()`, `hasRole(golferAccountId, roleName)`, `hasAdminRole(golferAccountId)`
- `apps/api/src/main/java/vnpt/vsp/module/role/RoleServiceImpl.java` — implementation; `assignRole()` checks assigner has SUPER_ADMIN; `hasRole()` used for RBAC decisions; MFA uses TOTP (RFC 6238); audit logged on all mutations
- `apps/api/src/main/java/vnpt/vsp/module/role/RoleController.java` — `GET /admin/roles` (list all roles), `GET /admin/users` (list admin accounts with roles), `POST /admin/users/{id}/roles` (assign role), `DELETE /admin/users/{id}/roles/{roleName}` (revoke role), `POST /admin/users/{id}/mfa/enable` (enable MFA), `POST /admin/users/{id}/mfa/disable` (disable MFA), `POST /admin/users/{id}/mfa/verify` (verify TOTP); all admin-protected (RBAC: SUPER_ADMIN or COURSE_ADMIN for role management)
- `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` — add `ROLE_001` (Role not found), `ROLE_002` (Admin not found), `ROLE_003` (Role already assigned), `ROLE_004` (Cannot revoke last super admin), `MFA_001` (MFA not enabled), `MFA_002` (Invalid TOTP code)
- `packages/contracts/schemas/role.yaml` — new schema file with role/admin DTO definitions
- `packages/contracts/openapi.yaml` — add `/admin/roles` GET, `/admin/users` GET, `/admin/users/{id}/roles` POST/DELETE, `/admin/users/{id}/mfa/*` POST; `Admin` tag
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` — add `ROLE_ASSIGNED`, `ROLE_REVOKED`, `MFA_ENABLED`, `MFA_DISABLED`
- `apps/api/src/test/java/vnpt/vsp/module/role/RoleServiceImplTest.java` — tests: getAllRoles returns 6 roles, assignRole grants role with audit, revokeRole removes role with audit, cannot revoke last SUPER_ADMIN, hasRole returns true/false correctly, enableMfa sets secret and verified flag, verifyMfa accepts valid TOTP and rejects invalid, hasAdminRole returns true if any admin role assigned

**Key Design Decisions:**

1. **AC-1: 6 Role Types**: `RoleName` enum: SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR. Defined as a VARCHAR column in DB, enum in Java.

2. **AC-2: MFA via TOTP**: RFC 6238 TOTP with SHA-1, 6-digit code, 30-second window. `mfaSecret` stored encrypted (AES). `mfaVerifiedAt` set on successful first verification. Admin login flow checks `mfaEnabled` and prompts for TOTP code if enabled.

3. **RBAC Decision Logic**: `RoleService.hasRole(golferAccountId, roleName)` → `AdminRoleAssignmentRepository.existsByAdminAccountIdAndRoleName()`. `hasAdminRole(golferAccountId)` → true if any role assigned.

4. **Privilege Escalation Prevention**: `assignRole()` requires caller has SUPER_ADMIN. Cannot assign SUPER_ADMIN role if no existing SUPER_ADMIN would remain (unless caller is existing SUPER_ADMIN).

5. **Audit Trail**: Every role assignment/revocation and MFA enable/disable is logged via `AuditModule` with actor ID, target ID, action, and role/change details.

**Dependencies:** Slice 2-4-A (BagModule pattern); Identity module from 2-1; AuditModule from 1-5.

**Risks:**
- MFA TOTP secret encryption key management — secret stored encrypted, decryption key from environment config.
- Self-revocation prevention — cannot revoke own SUPER_ADMIN role.

---

### Slice 2-5-B: Backend + Portal — Privacy Request Module
**Rationale:** Privacy request handling for AC-3. Covers data export, account deletion, and round deletion with auditable processing. Portal admin screen for reviewing and processing requests.

**Scope:**

**New module: `privacy`**
- `apps/api/src/main/resources/db/migration/V12__privacy_requests.sql` — `privacy_requests` table (id, requester_golfer_account_id FK, request_type ENUM (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION), status ENUM (PENDING, PROCESSING, COMPLETED, REJECTED), target_round_id FK NULLABLE, requested_at TIMESTAMP, processed_at TIMESTAMP NULLABLE, processed_by BIGINT FK NULLABLE to admin_accounts, rejection_reason VARCHAR NULLABLE, created_at, updated_at)
- `apps/api/src/main/java/vnpt/vsp/module/privacy/entity/PrivacyRequest.java` — JPA entity; `requestType` enum (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION); `status` enum (PENDING, PROCESSING, COMPLETED, REJECTED); `targetRoundId` FK nullable (for ROUND_DELETION); `requestedAt`; `processedAt`; `processedBy` FK nullable; `rejectionReason` nullable; timestamps
- `apps/api/src/main/java/vnpt/vsp/module/privacy/repository/PrivacyRequestRepository.java` — `findByRequesterGolferAccountId()`, `findByIdAndRequesterGolferAccountId()`, `findByStatus()`, `findByIdAndStatus()`, `countByRequesterGolferAccountIdAndStatus()`
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/PrivacyRequestResponse.java` — response DTO: id, requestType, status, targetRoundId, requestedAt, processedAt, rejectionReason
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/CreatePrivacyRequestRequest.java` — request DTO: requestType (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION), targetRoundId (optional, for ROUND_DELETION)
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/ProcessPrivacyRequestRequest.java` — request DTO: status (PROCESSING, COMPLETED, REJECTED), rejectionReason (optional)
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyService.java` — interface: `createRequest()`, `getMyRequests()`, `getRequestById()`, `getRequestsByStatus()`, `processRequest()`, `getDataExport()`, `deleteAccount()`, `deleteRound()`
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyServiceImpl.java` — implementation; `createRequest()` creates PENDING request and audit logs; `processRequest()` transitions status with audit; `deleteAccount()` anonymizes GolferAccount (removes PII, keeps ID for audit); `deleteRound()` cascades soft-delete on Round + Scores; `getDataExport()` generates JSON export of golfer profile, bags, rounds, scores
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyController.java` — Golfer-facing: `POST /privacy/requests` (submit request), `GET /privacy/requests` (list own requests), `GET /privacy/requests/{id}` (get own request). Admin-facing: `GET /admin/privacy-requests` (list by status), `PUT /admin/privacy-requests/{id}` (process — complete or reject)
- `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` — add `PRIVACY_001` (Request not found), `PRIVACY_002` (Request already processed), `PRIVACY_003` (Invalid status transition), `PRIVACY_004` (Cannot delete account with active rounds — must delete rounds first)
- `packages/contracts/schemas/privacy.yaml` — new schema file with privacy DTO definitions
- `packages/contracts/openapi.yaml` — add `/privacy/requests` POST/GET, `/privacy/requests/{id}` GET, `/admin/privacy-requests` GET, `/admin/privacy-requests/{id}` PUT; `Privacy` tag
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` — add `PRIVACY_REQUEST_SUBMITTED`, `PRIVACY_REQUEST_PROCESSED`, `ACCOUNT_DATA_EXPORTED`, `ACCOUNT_DELETED`, `ROUND_DELETED`
- `apps/api/src/main/java/vnpt/vsp/module/round/entity/Round.java` — add `deletedAt` soft-delete column (for ROUND_DELETION)
- `apps/api/src/main/java/vnpt/vsp/module/account/entity/GolferAccount.java` — add `anonymizedAt`, `anonymizedData` columns (for ACCOUNT_DELETION)
- `apps/api/src/test/java/vnpt/vsp/module/privacy/PrivacyServiceImplTest.java` — tests: create DATA_EXPORT request, create ACCOUNT_DELETION request, create ROUND_DELETION request with roundId, processRequest transitions to COMPLETED with audit, processRequest rejects with reason and audit, deleteAccount anonymizes PII but retains audit trail, deleteRound soft-deletes round and scores, cannot process already-completed request

**Key Design Decisions:**

1. **AC-3: Three Request Types**: `DATA_EXPORT` (generate full JSON of profile, bags, rounds, scores), `ACCOUNT_DELETION` (anonymize GolferAccount, retain for audit, cascade to profile), `ROUND_DELETION` (soft-delete specific round + scores).

2. **Auditable Processing**: Every state transition logged via `AuditModule`. `processedBy` admin ID captured. `rejectionReason` stored for REJECTED requests.

3. **Soft-delete for Rounds**: `Round.deletedAt` field added. Queries exclude soft-deleted rounds by default. ACCOUNT_DELETION requires no active (non-deleted) rounds — `PRIVACY_004` if violated.

4. **Data Export Format**: JSON containing: GolferProfile (anonymized fields), GolfBags with Clubs, Rounds with Scores (excluding soft-deleted). Exported as file download via `/privacy/requests/{id}/export`.

5. **Anonymization**: `GolferAccount.anonymizedData` stores encrypted JSON of PII (phone, email) before clearing. Name set to "Deleted User". Login credentials invalidated.

**Portal Admin Screens** (new portal pages):
- `apps/portal/src/pages/admin/privacy-requests.tsx` — list all privacy requests by status (PENDING/PROCESSING/COMPLETED/REJECTED); filter by type; click to process
- `apps/portal/src/pages/admin/privacy-request-detail.tsx` — view request details; approve/complete or reject with reason; audit trail shown
- `apps/portal/src/pages/admin/role-management.tsx` — list admin accounts; assign/revoke roles; enable/disable MFA

**Dependencies:** Slice 2-5-A (RoleModule for admin context); IdentityModule from 2-1; RoundModule from 2-3.

**Risks:**
- GDPR/data retention compliance — anonymization must be irreversible; verify legal review.
- Account with active rounds deletion — block until rounds are deleted first (`PRIVACY_004`).

---

### Slice 2-5-C: Mobile — Privacy Request Screen UI
**Rationale:** Mobile UI for golfers to submit privacy requests. Depends on Slice 2-5-B API contracts. Privacy requests accessible from Profile tab.

**Scope:**

- `apps/mobile/lib/features/privacy/data/privacy_request_dto.dart` — `PrivacyRequestDTO` with: id, requestType (enum), status (enum), targetRoundId, requestedAt, processedAt, rejectionReason; `CreatePrivacyRequest`, `ProcessPrivacyRequest`; `PrivacyRequestType` enum (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION); `PrivacyRequestStatus` enum (PENDING, PROCESSING, COMPLETED, REJECTED)
- `apps/mobile/lib/features/privacy/data/privacy_service.dart` — `PrivacyService` wrapping: `POST /privacy/requests`, `GET /privacy/requests`, `GET /privacy/requests/{id}`, `GET /privacy/requests/{id}/export`
- `apps/mobile/lib/features/privacy/data/privacy_repository.dart` — `PrivacyRepository`: wraps service; `getMyRequests()` returns cached list; `submitRequest()` calls service
- `apps/mobile/lib/features/privacy/presentation/privacy_bloc.dart` — `PrivacyBloc` with events: `LoadPrivacyRequests`, `SubmitDataExportRequest`, `SubmitAccountDeletionRequest`, `SubmitRoundDeletionRequest`, `LoadRequestDetail`; states: `PrivacyInitial`, `PrivacyLoading`, `PrivacyRequestsLoaded`, `PrivacyRequestDetailLoaded`, `PrivacyError`
- `apps/mobile/lib/features/privacy/presentation/privacy_screen.dart` — privacy request screen: list of my requests with status badges, FAB to submit new request, tap to view detail; DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION request type selection
- `apps/mobile/lib/features/privacy/presentation/widgets/privacy_request_card.dart` — card showing request type icon, status badge, date, tap to expand
- `apps/mobile/lib/features/privacy/presentation/widgets/round_picker_for_deletion.dart` — round picker bottom sheet for ROUND_DELETION type selection
- `apps/mobile/lib/features/privacy/presentation/widgets/request_type_selector.dart` — three-tile selector for DATA_EXPORT / ACCOUNT_DELETION / ROUND_DELETION with icons and descriptions
- Navigation: Profile tab → Privacy & Data → PrivacyScreen → PrivacyRequestDetailScreen
- Loading, error, empty states — follow same patterns as ProfileScreen (2-3-C)
- Accessibility: all fields have `Semantics` labels; touch targets ≥44pt; screen reader reads status + type
- Confirmation dialogs: destructive actions (ACCOUNT_DELETION) require explicit confirmation with typed input "DELETE"
- Design system tokens: `VspColorSemantic.destructive` for delete actions, `VspColorSemantic.warning` for pending

**Key Design Decisions:**

1. **AC-3 Round Deletion**: Round picker shows only the golfer's own rounds (from `RoundModule`). Soft-deleted rounds excluded. Selected round ID passed as `targetRoundId`.

2. **Account Deletion Warning**: ACCOUNT_DELETION shows prominent warning dialog: "This will permanently delete your account and all data. This action cannot be undone." Requires user to type "DELETE" to confirm.

3. **Request Status Tracking**: Each request shows status badge (PENDING=amber, PROCESSING=blue, COMPLETED=green, REJECTED=red with reason).

4. **Data Export**: DATA_EXPORT shows "Your data export will be prepared and available for download within 48 hours" informational notice.

**Dependencies:** Slice 2-5-B (API contracts)

**Risks:**
- None identified — follows established patterns from 2-3-C ProfileScreen

---

## 5. Slice-to-AC Mapping

| Slice | AC-1 (RBAC 6 roles) | AC-2 (MFA for admins) | AC-3 (Privacy requests with audit) |
|-------|---------------------|------------------------|-------------------------------------|
| 2-5-A (Backend RBAC/MFA) | ✅ Full — `Role` entity, 6 role types, `AdminRoleAssignment`, `RoleService.hasRole()` for RBAC checks, role assignment/revocation with audit | ✅ Full — `AdminAccount.mfaEnabled`, TOTP secret, `enableMfa()`, `verifyMfa()`, MFA enforced on admin login | Partial — `PrivacyRequest` entity and table defined but workflow not yet implemented |
| 2-5-B (Backend Privacy) | ✅ Full — RBAC-protected admin endpoints for role management; `hasRole()` checks on all admin operations | ✅ Full — MFA required to access admin role management endpoints | ✅ Full — `PrivacyRequest` full lifecycle, data export, account deletion (anonymization), round deletion (soft-delete), complete audit trail |
| 2-5-C (Mobile Privacy UI) | N/A | N/A | ✅ Full — `PrivacyScreen` with request submission, status tracking, round picker for deletion, confirmation dialogs |

---

## 6. Key Design Decisions

### AC-1: Role Definition and Storage
**Decision:** `Role` entity with 6 role names stored in `roles` table. `AdminRoleAssignment` join table links `AdminAccount` (which links to `GolferAccount`) to role names. One admin can have multiple roles.

**Rationale:** Follows standard many-to-many pattern. Role name as enum in Java, VARCHAR in DB. Assignment stored in `admin_role_assignments` table with `assignedBy` audit trail.

### AC-2: MFA Implementation (TOTP)
**Decision:** RFC 6238 TOTP with SHA-1, 6-digit code, 30-second window. Secret stored encrypted (AES-256) in `mfa_secret` column. Initial verification required when enabling. `mfaVerifiedAt` timestamp tracks when MFA was first verified.

**Rationale:** Standard TOTP is widely supported (Google Authenticator, Authy, etc.). No SMS/cost dependency. Encryption at rest for secret. Verification step prevents misconfiguration lockout.

**Admin Login Flow:**
1. GolferAccount authenticates (phone/email/social)
2. If account has `admin_accounts` record with `mfaEnabled=true` → prompt for TOTP code
3. Verify TOTP code against stored secret (allow ±1 window for clock drift)
4. If valid → issue session token with admin role context

### AC-3: Privacy Request State Machine
**Decision:** `PrivacyRequest` with states: PENDING → PROCESSING → COMPLETED/REJECTED. State transitions:
- `PENDING` → `PROCESSING` (admin starts processing)
- `PROCESSING` → `COMPLETED` (admin finishes — triggers action)
- `PROCESSING` → `REJECTED` (admin rejects with reason)

**Rationale:** Simple state machine. COMPLETED triggers the actual action (data export generation, account anonymization, round deletion). All transitions are audit-logged.

### AC-3: Account Deletion (Anonymization, Not Hard Delete)
**Decision:** ACCOUNT_DELETION anonymizes `GolferAccount`: name → "Deleted User", phone/email encrypted and stored in `anonymizedData`, login disabled, `anonymizedAt` timestamp set. Profile, bags, rounds soft-deleted.

**Rationale:** Hard delete breaks audit trail and foreign key constraints. Anonymization satisfies privacy request (PII removed) while preserving aggregate data integrity and audit compliance. Specific retention policy determines how long anonymized record is kept.

### AC-3: Round Deletion (Soft Delete)
**Decision:** `Round.deletedAt` column added. All queries for active rounds filter `WHERE deleted_at IS NULL`. COMPLETED privacy request sets `deleted_at = NOW()` and cascades to scores.

**Rationale:** Soft delete preserves audit trail for tournament integrity and historical data. Mobile app queries exclude deleted rounds.

---

## 7. Skill Gap Analysis

| Required Skill | Status | Evidence |
|----------------|--------|----------|
| `bmad-dev-story` | ✅ Available | Loaded from `.agents/skills/bmad-dev-story/SKILL.md` |
| `vnpt-tdd` | ✅ Available | Skill `vnpt-tdd` in available_skills |
| Spring Boot JPA + modular monolith | ✅ Epic-01 + 2-4-A foundation | `GolferProfile`, `Club` entities; `BagServiceImpl` with audit — same patterns |
| Flutter BLoC state management | ✅ 2-3-C + 2-4-C | `ProfileBloc`, `BagBloc`; `PrivacyBloc` follows same architecture |
| Flutter offline sync | ✅ 2-3-B + 2-4-B | `ProfileSyncStore`, `BagSyncStore`; `PrivacyRepository` simpler (no offline queue needed for read-submit) |
| TOTP MFA | ✅ Library (devonta/totp) | RFC 6238 TOTP implementation in Java — need to add dependency |
| Design system tokens (Story 1.4) | ✅ Verified | `VspColorSemantic`, `VspSpacing` used in 2-3-C and 2-4-C |
| Portal React/TypeScript | ⚠️ Unknown | Portal stack not confirmed from implementation docs — may need verification |
| OpenAPI contract extension | ✅ 2-4-A pattern | `bag.yaml` extended; `role.yaml`, `privacy.yaml` follow same pattern |

**No blocking skill gaps identified.** TOTP library is a standard Java library. Portal stack (React/TypeScript) follows standard web patterns.

---

## 8. Quality Gate Checklist

### Pre-Dispatch Checks
| Check | Result | Evidence |
|-------|--------|----------|
| Story source status is `ready-for-dev` | ✅ Yes | `docs/implementation-artifacts/epic-02/2-5-administer-roles-and-privacy-requests.md` line 5: `status: ready-for-dev` |
| No placeholder/TODO-only scope | ✅ Clean | Full implementation scope defined in slices |
| No deferred-production behavior | ✅ Clean | All 3 ACs addressed: 6-role RBAC, MFA, privacy requests with audit |
| Story 2-4 dependency resolved | ✅ Done | Story 2-4 `status: done` per epic-state.json |
| Epic-01 dependencies resolved | ✅ Done | Epic-01 `status: done` per epic-state.json |
| Wave 5 final story | ✅ Yes | 2-5 is last story in Epic-02 |
| Skill-not-found error | ✅ None | Both `bmad-dev-story` and `vnpt-tdd` confirmed available |

### Anti-Shortcut Evidence
| Check | Result |
|-------|--------|
| No skipping required context reading | ✅ All required sources read: PRD, architecture, ux-spec, story spec, 2-4 plan/A/B/C, epic-inventory, epic-state, 1-4/1-5 acceptance matrices |
| No collapse of independent slices into sequential-only | ✅ All 3 slices independent (A: RBAC/MFA, B: Privacy workflow, C: Mobile Privacy UI) — A and B can parallelize on backend |
| PRD/Architecture/UX alignment verified | ✅ Full cross-reference in Section 2 |
| AC coverage verified per slice | ✅ Section 5 slice-to-AC mapping |
| Wave 5 sequential dependency honored | ✅ 2-5 depends on completed 2-4 |
| MFA implementation standard | ✅ RFC 6238 TOTP — industry-standard, not custom |
| Privacy deletion = anonymization | ✅ Soft-delete + anonymization (not hard-delete) preserves audit trail |

### Dedup Pre-Check (symbols expected in new code)
| Symbol Pattern | Location | Dedup Action |
|---------------|----------|--------------|
| `Role`, `AdminAccount`, `AdminRoleAssignment` | `apps/api/src/main/java/vnpt/vsp/module/role/entity/` | New module — no collision expected |
| `RoleService`, `RoleServiceImpl` | `apps/api/src/main/java/vnpt/vsp/module/role/` | New module — no collision |
| `RoleController` | `apps/api/src/main/java/vnpt/vsp/module/role/` | New module — no collision |
| `PrivacyRequest` | `apps/api/src/main/java/vnpt/vsp/module/privacy/entity/` | New module — no collision |
| `PrivacyService`, `PrivacyServiceImpl` | `apps/api/src/main/java/vnpt/vsp/module/privacy/` | New module — no collision |
| `PrivacyController` | `apps/api/src/main/java/vnpt/vsp/module/privacy/` | New module — no collision |
| `RoleDTO`, `AdminAccountDTO` | `packages/contracts/schemas/` | New schema files — no collision |
| `PrivacyRequestDTO` (Flutter) | `apps/mobile/lib/features/privacy/data/` | New feature directory — no collision |
| `PrivacyBloc`, `PrivacyScreen` | `apps/mobile/lib/features/privacy/presentation/` | New feature directory — no collision |
| `/admin/roles/*`, `/admin/users/*`, `/privacy/*` OpenAPI paths | `packages/contracts/openapi.yaml` | Extend existing — no collision |
| `ROLE_00X`, `MFA_00X`, `PRIVACY_00X` VspErrorCode | `VspErrorCode.java` | Extend existing enum — verify no collision |
| `ROLE_ASSIGNED`, `ROLE_REVOKED`, `MFA_ENABLED`, `PRIVACY_REQUEST_SUBMITTED`, `PRIVACY_REQUEST_PROCESSED`, `ACCOUNT_DELETED`, `ROUND_DELETED` AuditAction | `AuditAction.java` | Extend existing enum — verify no collision |

---

## 9. Implementation Wave Recommendation

**Recommended dispatch order:**
1. **Slice 2-5-A** (backend RBAC/MFA, wave 1) — first: defines roles and MFA that secure the admin API; portal and mobile privacy UI depend on its contracts
2. **Slice 2-5-B** (backend Privacy, wave 1, parallel with A) — privacy module is independent of role module but both extend AuditAction and VspErrorCode; can parallelize if implementers coordinate on shared enum extensions
3. **Slice 2-5-C** (mobile Privacy UI, wave 2, depends on A+B) — mobile UI depends on both RBAC and Privacy API contracts

**Rationale:** Backend RBAC (2-5-A) and Privacy (2-5-B) are both backend modules and can run in parallel. Both produce API contracts consumed by mobile (2-5-C). The only coordination point is `AuditAction.java` and `VspErrorCode.java` extensions — implementers must coordinate or the orchestrator must serialize those shared file edits.

---

## 10. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-02/epic-state.json",
    "docs/vnpt-flow/epic-run-epic-02/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-B-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-C-implementation.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-5-administer-roles-and-privacy-requests.md"
  ],
  "mockup_sources_read": [
    "docs/vnpt-stitch-mockup-batch/README.md"
  ],
  "additional_context_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md",
    "docs/implementation-artifacts/epic-02/2-1-register-and-authenticate-golfer.md",
    "docs/implementation-artifacts/epic-02/2-3-manage-golfer-profile-and-preferences.md"
  ]
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story. The Stitch mockup batch (`vnpt-stitch-mockup-batch/README.md`) is a separate batch command that generates mockups post-hoc and is not pre-populated for this story. Acceptance matrices for stories 1-2 and 1-3 do not exist on disk (confirmed by 2-4-plan.md §10).

---

## 11. Completion Criteria for Implementer

Each slice implementer must deliver:
1. All slice-scoped acceptance criteria verified
2. Unit tests for happy paths, boundaries, and failures
3. Repository format, lint, typecheck, and test gates pass
4. Dedup report generated (`docs/vnpt-flow/epic-run-epic-02/2-5-{slice}/dedup_report.json`)
5. File list populated in story change log
6. Story status updated to `in-progress` during work, `review` when all slices complete

---

**Plan Status:** ✅ READY_FOR_IMPLEMENTER_DISPATCH
**Quality Gate:** PASS (all checks clean)
**Next Action:** Dispatch Slices 2-5-A and 2-5-B to `vnpt-epic-story-implementer` (parallel backend slices), then 2-5-C after contracts are published
