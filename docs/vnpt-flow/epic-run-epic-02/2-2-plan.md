# Story 2.2 Plan: Manage Sessions Securely

**Run ID:** run_2026_08_02_005
**Epic:** Epic-02 (Golfer Management)
**Wave:** 2 of 5 (story 2-2 depends on 2-1; sequential chain)
**Status:** PLANNING
**Story Source:** `docs/implementation-artifacts/epic-02/2-2-manage-sessions-securely.md`

---

## 1. Story Scope Summary

**User Story:** As a golfer, I want secure device sessions so that I can control account access.

**Acceptance Criteria:**
| AC | Description |
|----|-------------|
| AC-1 | Access tokens are short-lived and refresh tokens rotate. |
| AC-2 | Tokens are stored in encrypted device storage. |
| AC-3 | User can list and revoke sessions; revoked sessions cannot refresh. |

---

## 2. PRD / Architecture / UX Alignment Evidence

### PRD Alignment (docs/planning-artifacts/prd.md)
- **Section 10.6 Security:** "Token expiration and refresh-token rotation", "Encrypted token storage on mobile"
- **Section 8.1 Account and Profile:** "Users can ... manage sessions"

### Architecture Alignment (docs/planning-artifacts/architecture.md)
- **Section 12 Security:** "OAuth/OIDC-compatible identity strategy", "Short-lived access tokens", "Refresh-token rotation", "Encrypted token storage on mobile"
- **Section 6.1 Modular Monolith:** Identity Module is the owning module for sessions

### UX Spec Alignment (docs/planning-artifacts/ux-spec.md)
- **Section 5.1 Onboarding/Auth:** session management context
- **Section 10 Accessibility:** session management must be accessible (screen reader labels, touch targets)

### 2-1 Output Analysis (epic-run-epic-02/2-1-*-implementation.md)
| 2-1 Deliverable | Relevance to 2.2 |
|-----------------|-------------------|
| `JwtService` for access/refresh token creation | Must be extended for rotation tracking |
| `POST /auth/login` returns access + refresh JWTs | Rotation requires persisted refresh token records |
| `POST /auth/refresh` (stub) | Must validate against session DB, mark old token revoked |
| `GolferAccount` entity | Sessions belong to golfer accounts |
| `IdentityService` | Session listing/revocation logic lives here |
| Mobile: no secure storage yet | flutter_secure_storage needed for AC-2 |

---

## 3. Slice Plan

### Slice 2-2-A: Backend — Session Management (Refresh Token Rotation + Revocation)
**Rationale:** Session management backend is the first deliverable. Depends only on 2-1's existing Identity Module + JWT infrastructure. Independent of mobile. Tests AC-1 (rotation) and AC-3 (list/revoke) on backend.

**Scope:**
- `apps/api/src/main/resources/db/migration/V5__refresh_tokens.sql` — `refresh_tokens` table (id, golfer_account_id, token_hash, device_info, user_agent, ip_address, created_at, expires_at, revoked_at, replaced_by_token_id)
- `apps/api/src/main/java/vnpt/vsp/module/identity/entity/RefreshToken.java` — entity with fields: id, golferAccount, tokenHash, deviceInfo, userAgent, ipAddress, createdAt, expiresAt, revokedAt, replacedByToken
- `apps/api/src/main/java/vnpt/vsp/module/identity/repository/RefreshTokenRepository.java`
- Update `apps/api/src/main/java/vnpt/vsp/module/identity/security/JwtService.java` — add `issueRefreshToken()` that stores token hash; add `rotateRefreshToken()` to mark old token replaced; add `revokeRefreshToken()`; add `getActiveSessions()` returning list of session metadata
- Update `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityService.java` — add `listSessions()`, `revokeSession()`, `rotateRefreshToken()` interface methods
- Update `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityServiceImpl.java` — implement session list (exclude revoked, join with golfer_account_id), revoke (set revoked_at, clear replaced_by), rotation (mark old revoked with new token id reference)
- Update `apps/api/src/main/java/vnpt/vsp/api/auth/AuthController.java` — extend `POST /auth/refresh` to validate refresh token against DB, mark old revoked, issue new pair; add `GET /auth/sessions` returning list of active sessions with device info/timestamp; add `DELETE /auth/sessions/{sessionId}` to revoke specific session
- `packages/contracts/openapi.yaml` — add `/auth/sessions` GET, `/auth/sessions/{sessionId}` DELETE; add `SessionResponse` schema (sessionId, deviceInfo, userAgent, ipAddress, createdAt, expiresAt)
- `packages/contracts/schemas/auth.yaml` — add `SessionResponse` schema
- Unit tests in `IdentityServiceImplTest.java`: rotation happy path, revoked session cannot refresh, revoked session cannot be re-rotated, list sessions excludes revoked, revoke sets revoked_at

**Dependencies:** Slice 2-1-A (JWT infrastructure, Identity Module)

**Risks:**
- None identified — 2-1 already established JWT and Identity Module boundaries

---

### Slice 2-2-B: Mobile — Encrypted Token Storage + Session Management UI
**Rationale:** Mobile UI for viewing/revoking sessions and secure storage for tokens. Depends on Slice 2-2-A's API contracts (session list/revoke endpoints). Independent of mobile auth UI (2-1-C/D) — builds on top.

**Scope:**
- `apps/mobile/` — Flutter app
- Add `flutter_secure_storage` dependency to `pubspec.yaml`
- `lib/data/repositories/secure_session_repository.dart` — wraps flutter_secure_storage; stores/retrieves access_token, refresh_token, session_id; exposes `saveTokens()`, `getAccessToken()`, `getRefreshToken()`, `clearTokens()`
- Update `lib/application/auth/auth_cubit.dart` or `AuthBloc` — integrate `SecureSessionRepository`; on login: store tokens; on refresh: store new tokens; on logout: clear tokens
- `lib/presentation/screens/session_management_screen.dart` — screen listing active sessions
  - Each session row: device icon, device_info string, created_at timestamp, "Revoke" button
  - Current session marked with "This device" label
  - Pull-to-refresh
  - Loading, error, empty states
- `lib/presentation/widgets/session_card.dart` — card widget for one session row
- Update `lib/presentation/screens/profile_screen.dart` or add to settings — link/navigation to session management
- `lib/core/constants/api_endpoints.dart` — add SESSION_LIST, SESSION_REVOKE constants
- `lib/data/datasources/remote/auth_remote_datasource.dart` — add `listSessions()`, `revokeSession()` methods
- `lib/application/auth/repositories/auth_repository.dart` — add `listSessions()`, `revokeSession()` methods
- Loading states, error handling with retry
- Accessibility: screen reader labels for session rows and revoke buttons

**Dependencies:** Slice 2-2-A (API endpoints + contracts)

**Risks:**
- None identified — flutter_secure_storage is well-established Flutter package

---

## 4. Slice-to-AC Mapping

| Slice | AC-1 (Short-lived + rotating refresh) | AC-2 (Encrypted storage) | AC-3 (List + revoke sessions) |
|-------|---------------------------------------|------------------------|-------------------------------|
| 2-2-A (Backend) | ✅ Full — rotation logic, revoked tokens cannot refresh | N/A | ✅ Full — GET/DELETE /auth/sessions |
| 2-2-B (Mobile) | ✅ Full — secure storage integration | ✅ Full — flutter_secure_storage | ✅ Full — session list/revoke UI |

---

## 5. Skill Gap Analysis

| Required Skill | Status | Evidence |
|----------------|--------|----------|
| `bmad-dev-story` | ✅ Available | Loaded from `.agents/skills/bmad-dev-story/SKILL.md` |
| `vnpt-tdd` | ✅ Available | Skill `vnpt-tdd` in available_skills |
| Spring Boot security/JWT | ✅ Epic-01 + 2-1 foundation | `JwtService`, `JwtAuthenticationFilter` in Identity Module |
| Flutter secure storage | ✅ flutter_secure_storage | Standard Flutter package |
| Mobile session management UI | ✅ Flutter best practices | Uses existing auth state management (AuthBloc/Cubit) |

**No skill gaps identified. All required skills and stack patterns are available.**

---

## 6. Quality Gate Checklist

### Pre-Dispatch Checks
| Check | Result | Evidence |
|-------|--------|----------|
| Story source status is `ready-for-dev` | ✅ Yes | `docs/implementation-artifacts/epic-02/2-2-manage-sessions-securely.md` line 5: `status: ready-for-dev` |
| No placeholder/TODO-only scope | ✅ Clean | Full implementation scope defined in slices |
| No deferred-production behavior | ✅ Clean | All 3 ACs addressed: rotation, encrypted storage, list/revoke |
| Skill-not-found error | ✅ None | Both `bmad-dev-story` and `vnpt-tdd` confirmed available |
| Story 2-1 dependency resolved | ✅ Done | Story 2-1 `status: done` per epic-state.json |
| Epic-01 dependencies resolved | ✅ Done | Epic-01 `status: done` per epic-state.json |

### Anti-Shortcut Evidence
| Check | Result |
|-------|--------|
| No skipping required context reading | ✅ All 11 required source groups read (PRD, architecture, UX spec, story spec, 2-1 plan, 2-1-A/B impl, epic-state, epic-inventory, epic-manifest, mockup readme) |
| No collapse of independent slices into sequential-only | ✅ 2-2-A and 2-2-B can run in parallel (backend vs mobile independent) |
| PRD/Architecture/UX alignment verified | ✅ Full cross-reference in Section 2 |
| AC coverage verified per slice | ✅ Section 4 slice-to-AC mapping |
| Wave 2 sequential dependency honored | ✅ 2-2 depends on 2-1 completed |

### Dedup Pre-Check (symbols expected in new code)
| Symbol Pattern | Location | Dedup Action |
|----------------|----------|--------------|
| `RefreshToken` (entity, repository) | `apps/api/` | Serena exact-match before creating; if found with matching signature → reuse |
| `JwtService.rotateRefreshToken()`, `JwtService.revokeRefreshToken()` | `apps/api/` | Serena exact-match; if found → add as overload or extend existing |
| `GET /auth/sessions`, `DELETE /auth/sessions/{id}` | `apps/api/` | OpenAPI extension; Serena for controller naming |
| `SecureSessionRepository` | `apps/mobile/` | Serena for mobile naming conflict |
| `SessionManagementScreen`, `SessionCard` | `apps/mobile/` | Serena for widget naming conflict |

---

## 7. Implementation Wave Recommendation

**Recommended dispatch order:**
1. **Slice 2-2-A** (backend, wave 1) — first: mobile depends on its API contracts
2. **Slice 2-2-B** (mobile, wave 2, depends on A) — parallel with A is possible since backend can be developed independently; mobile waits for contracts but both slices are independent workstreams

**Rationale:** Backend session management establishes the API contracts (session list/revoke schemas). Mobile then implements against those contracts. Both layers can proceed in parallel once contracts are defined — mobile UI can be built against mock/stub data until backend is ready.

---

## 8. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-02/epic-state.json",
    "docs/vnpt-flow/epic-run-epic-02/epic-story-manifest.json",
    "docs/vnpt-flow/epic-run-epic-02/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-02/2-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-1-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-1-B-implementation.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-2-manage-sessions-securely.md"
  ],
  "mockup_sources_read": [
    "docs/vnpt-stitch-mockup-batch/README.md"
  ],
  "additional_context_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ]
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story. The Stitch mockup batch (`vnpt-stitch-mockup-batch.README.md`) is a separate batch command that generates mockups post-hoc and is not pre-populated for this story.

---

## 9. Completion Criteria for Implementer

Each slice implementer must deliver:
1. All slice-scoped acceptance criteria verified
2. Unit tests for happy paths, boundaries, and failures
3. Repository format, lint, typecheck, and test gates pass
4. Dedup report generated (`docs/vnpt-flow/epic-run-epic-02/2-2-{slice}/dedup_report.json`)
5. File list populated in story change log
6. Story status updated to `in-progress` during work, `review` when all slices complete

---

**Plan Status:** ✅ READY_FOR_IMPLEMENTER_DISPATCH
**Quality Gate:** PASS (all checks clean)
**Next Action:** Dispatch Slice 2-2-A to `vnpt-epic-story-implementer`
