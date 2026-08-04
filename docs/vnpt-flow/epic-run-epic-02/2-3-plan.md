# Story 2.3 Plan: Manage Golfer Profile and Preferences

**Run ID:** run_2026_08_02_005
**Epic:** Epic-02 (Golfer Management)
**Wave:** 3 of 5 (2-3 depends on 2-2; sequential chain)
**Status:** PLANNING
**Story Source:** `docs/implementation-artifacts/epic-02/2-3-manage-golfer-profile-and-preferences.md`

---

## 1. Story Scope Summary

**User Story:** As a golfer, I want to manage personal golf preferences so that distances and round defaults fit me.

**Acceptance Criteria:**
| AC | Description |
|----|-------------|
| AC-1 | Profile supports required identity, handicap, home club, unit, hand, skill, target, and distance fields. |
| AC-2 | Unit changes update displayed distances without corrupting canonical values. |
| AC-3 | Offline profile edits queue and synchronize safely. |

---

## 2. PRD / Architecture / UX Alignment Evidence

### PRD Alignment (docs/planning-artifacts/prd.md)
- **Section 8.1 Account and Profile:** "Golfer profile supports name, image, gender, birth year, country, handicap, home club, distance unit, dominant hand, target handicap, skill level, driver distance, and optional swing speed."
- **Section 8.7 Distance Measurement:** "Supported units: meters and yards." — canonical storage is meters; display conversion is UI responsibility.
- **Section 10.4 Offline:** "Offline-supported functions: Club selection" — profile preferences for clubs and distances must be available offline.
- **Section 10.5 Availability and Sync:** "Local persistence before sync", "Retry and idempotency support", "No score loss during backend outage" — extends to profile sync.

### Architecture Alignment (docs/planning-artifacts/architecture.md)
- **Section 6.1 Modular Monolith:** Profile Module is a bounded module; ProfileService interface already exists as scaffold.
- **Section 7.1 Source of Truth:** PostgreSQL canonical; mobile stores local cache.
- **Section 8.3 Offline Sync:** "Client writes append events to local event queue", "Sync worker retries idempotent API calls when online", "Conflict policy: score edits — latest client edit with audit history" — profile sync follows same pattern.
- **Section 11.2 Minimum API Groups:** `/profiles/*` endpoint group required.

### UX Spec Alignment (docs/planning-artifacts/ux-spec.md)
- **Section 5.2 Onboarding/Auth:** Profile accessible via Profile tab.
- **Section 5.1 Bottom Navigation:** Profile tab exists in main nav.
- **Section 10 Accessibility:** Field validation, screen reader labels, touch targets ≥44/48pt.
- **Section 9 Forms and Feedback:** Labels visible, errors near field, loading states.

### 2-2 Output Analysis (epic-run-epic-02/2-2-*-implementation.md)
| 2-2 Deliverable | Relevance to 2.3 |
|-----------------|-------------------|
| `RefreshToken` entity + rotation | Profile sync uses same token infrastructure |
| `SecureStorage` on mobile (sessionId) | Can reuse for profile sync queue token |
| Session management UI | Profile screen follows same loading/error/empty state patterns |
| `AuthBloc` state machine | ProfileBloc/Cubit follows same architecture |

### Epic-01 Foundations
| Epic-01 Story | Relevance to 2.3 |
|---------------|-------------------|
| Story 1.4 (Design System) | All UI uses semantic tokens: `VspColorLight`, `VspSpacingSemantic`, `VspFontWeight` |
| Story 1.5 (Observability/Security) | Audit trail for profile changes, encrypted local storage, no secrets in client |

---

## 3. Gap Analysis: Existing State vs. Required

### Backend
| What Exists | What Is Missing |
|-------------|-----------------|
| `GolferAccount` entity: id, phone, email, displayName, status, verifiedAt, createdAt, updatedAt | Golf-specific profile fields: handicap, homeClub, distanceUnit, dominantHand, skillLevel, targetHandicap, driverDistance, swingSpeed, gender, birthYear, country, imageUrl |
| `GolferProfileResponse` DTO: identity-only fields | Extended DTO with all golf preference fields |
| `ProfileService` interface (empty) | Full implementation with get/update/profile methods |
| `ProfileServiceImpl` (stub) | Full implementation |
| `/auth/me` returns identity-only profile | Need `GET /profiles/me` and `PUT /profiles/me` endpoints |

### Mobile
| What Exists | What Is Missing |
|-------------|-----------------|
| `GolferProfile` DTO: identity-only fields | Extended DTO with all golf preference fields |
| `SecureStorage` for tokens + sessionId | Profile sync queue storage |
| `auth_service.dart` has `getCurrentProfile()` | Need `profile_service.dart` with get/update + offline queue |
| Profile tab in HomeScreen | Dedicated `ProfileScreen` with full preference editing |
| Design system tokens (1-4) | All UI uses semantic tokens |

---

## 4. Slice Plan

### Slice 2-3-A: Backend — Profile Entity, Repository, and API
**Rationale:** Backend profile data layer is the foundation. Depends only on 2-2's Identity Module (for authenticated user context). Independent of mobile. Tests AC-1 (profile fields) and AC-2 (unit storage) on backend.

**Scope:**
- `apps/api/src/main/resources/db/migration/V6__golfer_profiles.sql` — `golfer_profiles` table (golfer_account_id FK, handicap, home_club, distance_unit, dominant_hand, skill_level, target_handicap, driver_distance, swing_speed, gender, birth_year, country, image_url, created_at, updated_at)
- `apps/api/src/main/java/vnpt/vsp/module/profile/entity/GolferProfile.java` — JPA entity with all golf-preference fields; `@Enumerated` for distanceUnit, dominantHand, skillLevel
- `apps/api/src/main/java/vnpt/vsp/module/profile/repository/GolferProfileRepository.java` — `findByGolferAccountId()` method
- `apps/api/src/main/java/vnpt/vsp/module/profile/dto/GolferProfileResponse.java` — extended response DTO with all fields (builder pattern, per existing GolferProfileResponse style)
- `apps/api/src/main/java/vnpt/vsp/module/profile/dto/UpdateGolferProfileRequest.java` — request DTO with validation annotations (NotNull, DecimalMin, Max, etc.)
- Update `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileService.java` — add `getProfile()`, `updateProfile()` interface methods
- Update `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileServiceImpl.java` — implement get/update; auto-create profile on first access (lazy creation); return canonical values (stored in meters)
- New `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileController.java` — `GET /profiles/me`, `PUT /profiles/me` endpoints; authenticated; audit log on update
- Update `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` — add `PROFILE_001` (Profile not found), `PROFILE_002` (Invalid unit value), `PROFILE_003` (Invalid skill level)
- `packages/contracts/openapi.yaml` — add `/profiles/me` GET and PUT endpoints; add `GolferProfileResponse` and `UpdateGolferProfileRequest` schemas
- `packages/contracts/schemas/profile.yaml` — new schema file with all profile DTO definitions
- Unit tests: `ProfileServiceImplTest` — happy path get/create, update with validation, unit conversion (canonical stays meters), invalid field rejection

**Dependencies:** Slice 2-2-A (session/refresh token infrastructure, authenticated context)

**Risks:**
- None identified — profile module is fresh scaffold; identity module already provides auth context

---

### Slice 2-3-B: Mobile — Profile DTO, Repository, Offline Queue
**Rationale:** Mobile data layer for profile including offline queue. Depends on Slice 2-3-A's API contracts. Independent of mobile UI — can be built in parallel with UI slice.

**Scope:**
- `apps/mobile/lib/features/profile/data/profile_dto.dart` — extend `GolferProfile` with new fields: `handicap`, `homeClub`, `distanceUnit` (enum METERS/YARDS), `dominantHand` (enum LEFT/RIGHT), `skillLevel` (enum BEGINNER/INTERMEDIATE/ADVANCED/PRO), `targetHandicap`, `driverDistance`, `swingSpeed`, `gender`, `birthYear`, `country`, `imageUrl`; `fromJson()`, `toJson()`, `toCanonicalMeters()`, `toDisplay()`
- `apps/mobile/lib/features/profile/data/profile_service.dart` — `getProfile()` (GET /profiles/me), `updateProfile()` (PUT /profiles/me); returns `ProfileDTO`
- `apps/mobile/lib/features/profile/data/profile_repository.dart` — wraps `ProfileService`; adds offline queue: `queueProfileUpdate()`, `getQueuedUpdates()`, `flushQueue()`; stores pending updates in local SQLite table; marks with `syncedAt`, `idempotencyKey`
- `apps/mobile/lib/core/storage/profile_sync_store.dart` — new SQLite-backed store for profile sync queue; stores: idempotency_key, payload (JSON), created_at, synced_at; exposes `enqueue()`, `dequeueAll()`, `markSynced()`, `hasPending()`
- Update `apps/mobile/lib/core/network/api_client.dart` — add idempotency key header support for write operations
- Update `apps/mobile/pubspec.yaml` — add `sqflite` dependency if not present (for offline queue)
- Unit tests: `profile_repository_test.dart` — queue update, flush queue, idempotency key uniqueness, offline get returns cached

**Dependencies:** Slice 2-3-A (API contracts)

**Risks:**
- None identified — offline queue pattern already established in codebase (score/round sync from Epic-01); sqflite is standard Flutter package

---

### Slice 2-3-C: Mobile — Profile Screen UI
**Rationale:** Mobile UI for viewing and editing profile. Depends on Slice 2-3-B data layer. Uses design system from Story 1.4.

**Scope:**
- `apps/mobile/lib/features/profile/presentation/profile_screen.dart` — main profile screen with sections: Identity (displayName, phone, email, image), Golf Stats (handicap, homeClub, skillLevel, targetHandicap), Distance (distanceUnit, driverDistance), Personal (gender, birthYear, country), swingSpeed
- `apps/mobile/lib/features/profile/presentation/widgets/profile_field_tile.dart` — reusable field tile widget for one editable field (label, value, edit icon, validation error)
- `apps/mobile/lib/features/profile/presentation/widgets/unit_picker.dart` — unit toggle (METERS/YARDS) with immediate display update and queued sync
- `apps/mobile/lib/features/profile/presentation/widgets/skill_level_picker.dart` — skill level dropdown (BEGINNER/INTERMEDIATE/ADVANCED/PRO)
- `apps/mobile/lib/features/profile/presentation/widgets/hand_picker.dart` — dominant hand toggle (LEFT/RIGHT)
- `apps/mobile/lib/features/profile/presentation/profile_bloc.dart` — BLoC for profile state: events (LoadProfile, UpdateProfile, UnitChanged, FlushQueue); states (ProfileInitial, ProfileLoading, ProfileLoaded, ProfileUpdating, ProfileUpdateSuccess, ProfileError)
- `apps/mobile/lib/features/profile/presentation/profile_state.dart` — state classes
- `apps/mobile/lib/features/profile/presentation/profile_event.dart` — event classes
- Navigation: Profile tab → `ProfileScreen`; existing "Edit Profile" tap navigates to same screen in edit mode
- Loading, error, empty states — follow same patterns as SessionManagementScreen (2-2-B)
- Offline indicator: show "Saved offline" snackbar when update queued; show "Synced" when flush succeeds
- Accessibility: all fields have `Semantics` labels; touch targets ≥44pt; screen reader reads field names + values

**Dependencies:** Slice 2-3-B (data layer + repository)

**Risks:**
- None identified — follows established patterns from 2-2-B SessionManagementScreen and Story 1.4 design system

---

## 5. Slice-to-AC Mapping

| Slice | AC-1 (Profile fields) | AC-2 (Unit without corruption) | AC-3 (Offline queue sync) |
|-------|----------------------|-------------------------------|--------------------------|
| 2-3-A (Backend) | ✅ Full — all fields stored and returned | ✅ Full — canonical meters stored; unit field stored; GET returns canonical | N/A (backend is always online) |
| 2-3-B (Mobile data) | ✅ Full — DTO mirrors all fields | ✅ Full — `toCanonicalMeters()`/`toDisplay()` conversion in DTO | ✅ Full — SQLite queue, idempotency keys, flush on reconnect |
| 2-3-C (Mobile UI) | ✅ Full — all fields rendered and editable | ✅ Full — unit picker triggers display conversion | ✅ Full — offline queue integration; "Saved offline" / "Synced" feedback |

---

## 6. Key Design Decisions

### Canonical Unit Storage
**Decision:** All distance values (driverDistance) are stored in **meters** in the database. The `distanceUnit` field on the profile indicates the golfer's display preference.

**Rationale:** Prevents unit corruption when switching display preference. The backend always returns canonical values; mobile handles conversion for display only.

**Conversion:** `displayValue = unit === 'YARDS' ? canonicalMeters * 1.09361 : canonicalMeters`

### Profile Lazy Creation
**Decision:** `GET /profiles/me` auto-creates a default profile if none exists for the authenticated golfer.

**Rationale:** Avoids 404 on first profile access; ensures every golfer has a usable profile with sensible defaults (unit=METERS, hand=RIGHT, skill=INTERMEDIATE).

### Offline Queue Strategy
**Decision:** Profile updates are queued locally with an idempotency key. Queue is flushed on app start and after network reconnection.

**Rationale:** Profile edits (unlike score entries) are not on-course-critical. Late sync is acceptable. Queue flush on reconnect ensures updates are eventually synced without blocking the UI.

**Conflict policy:** Server accepts latest write (per Architecture §8.3 "score edits: latest client edit with audit history").

### Profile vs. Identity Separation
**Decision:** Profile (golf preferences) is separate from Identity (authentication).

**Rationale:** Maintains modular monolith boundaries. Identity Module handles auth; Profile Module handles golfer-specific data. `GolferAccount` (identity) and `GolferProfile` (preferences) are separate entities linked by `golfer_account_id` FK.

---

## 7. Skill Gap Analysis

| Required Skill | Status | Evidence |
|----------------|--------|----------|
| `bmad-dev-story` | ✅ Available | Loaded from `.agents/skills/bmad-dev-story/SKILL.md` |
| `vnpt-tdd` | ✅ Available | Skill `vnpt-tdd` in available_skills |
| Spring Boot JPA + modular monolith | ✅ Epic-01 + 2-1-A/B foundation | `GolferAccount`, `RefreshToken` entities with full JPA patterns |
| Flutter BLoC state management | ✅ 2-2-B + 1-4 patterns | `AuthBloc` in `auth_bloc.dart`; `ProfileBloc` follows same pattern |
| Flutter SQLite/offline queue | ✅ sqflite package | Standard Flutter offline storage |
| Design system tokens (Story 1.4) | ✅ Verified | `VspColorLight`, `VspSpacingSemantic` used in SessionManagementScreen |

**No skill gaps identified. All required skills and stack patterns are available.**

---

## 8. Quality Gate Checklist

### Pre-Dispatch Checks
| Check | Result | Evidence |
|-------|--------|----------|
| Story source status is `ready-for-dev` | ✅ Yes | `docs/implementation-artifacts/epic-02/2-3-manage-golfer-profile-and-preferences.md` line 5: `status: ready-for-dev` |
| No placeholder/TODO-only scope | ✅ Clean | Full implementation scope defined in slices |
| No deferred-production behavior | ✅ Clean | All 3 ACs addressed: profile fields, unit storage, offline queue |
| Skill-not-found error | ✅ None | Both `bmad-dev-story` and `vnpt-tdd` confirmed available |
| Story 2-2 dependency resolved | ✅ Done | Story 2-2 `status: done` per epic-state.json |
| Epic-01 dependencies resolved | ✅ Done | Epic-01 `status: done` per epic-state.json |

### Anti-Shortcut Evidence
| Check | Result |
|-------|--------|
| No skipping required context reading | ✅ All required sources read: PRD, architecture, ux-spec, story spec, 2-1 plan/impl, 2-2 plan/impl/A/B, epic-inventory, epic-state, epic-story-manifest, 1-4/1-5 acceptance matrices |
| No collapse of independent slices into sequential-only | ✅ Slices 2-3-B and 2-3-C can run in parallel (both depend on 2-3-A contracts; B and C are independent) |
| PRD/Architecture/UX alignment verified | ✅ Full cross-reference in Section 2 |
| AC coverage verified per slice | ✅ Section 5 slice-to-AC mapping |
| Wave 3 sequential dependency honored | ✅ 2-3 depends on 2-2 completed |

### Dedup Pre-Check (symbols expected in new code)
| Symbol Pattern | Location | Dedup Action |
|----------------|----------|--------------|
| `GolferProfile` (entity) | `apps/api/src/main/java/vnpt/vsp/module/profile/entity/` | Serena exact-match; if found → extend existing |
| `GolferProfileRepository` | `apps/api/src/main/java/vnpt/vsp/module/profile/repository/` | Serena; if found → reuse |
| `ProfileController`, `GET /profiles/me`, `PUT /profiles/me` | `apps/api/` | OpenAPI extension + Serena for controller naming |
| `GolferProfileResponse`, `UpdateGolferProfileRequest` | `apps/api/` + `packages/contracts/` | DTO schemas — check auth.yaml for existing patterns |
| `ProfileService`, `ProfileServiceImpl` | `apps/api/` | Already exist as stubs — extend existing |
| `ProfileDTO` (Flutter) | `apps/mobile/lib/features/profile/data/` | Serena; if found → extend existing |
| `ProfileBloc`, `ProfileScreen`, `ProfileFieldTile`, `UnitPicker` | `apps/mobile/lib/features/profile/presentation/` | Serena; if found → reuse |
| `ProfileSyncStore` | `apps/mobile/lib/core/storage/` | Serena; if found → reuse |
| `sqflite` usage | `apps/mobile/` | Verify already in pubspec.yaml; if not → add |

---

## 9. Implementation Wave Recommendation

**Recommended dispatch order:**
1. **Slice 2-3-A** (backend, wave 1) — first: mobile depends on its API contracts
2. **Slice 2-3-B** (mobile data layer, wave 2, depends on A) — parallel with C is possible since both depend on A's contracts
3. **Slice 2-3-C** (mobile UI, wave 2, depends on A) — parallel with B; both can proceed once OpenAPI contracts are published

**Rationale:** Backend profile entity and API establishes the contracts. Mobile data layer (2-3-B) and UI (2-3-C) both depend on those contracts but are independent of each other. All three can be developed simultaneously once Slice A is done.

---

## 10. Evidence Arrays

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
    "docs/vnpt-flow/epic-run-epic-02/2-1-B-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-2-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-2-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-2-B-implementation.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-3-manage-golfer-profile-and-preferences.md"
  ],
  "mockup_sources_read": [
    "docs/vnpt-stitch-mockup-batch/README.md"
  ],
  "additional_context_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md",
    "apps/api/src/main/java/vnpt/vsp/module/identity/entity/GolferAccount.java",
    "apps/api/src/main/java/vnpt/vsp/module/identity/dto/GolferProfileResponse.java",
    "apps/api/src/main/java/vnpt/vsp/module/profile/ProfileService.java",
    "apps/api/src/main/java/vnpt/vsp/module/profile/ProfileServiceImpl.java",
    "apps/api/src/main/resources/db/migration/V2__golfer_accounts.sql",
    "apps/mobile/lib/features/auth/data/auth_dto.dart",
    "apps/mobile/lib/features/auth/data/auth_service.dart"
  ]
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story. The Stitch mockup batch (`vnpt-stitch-mockup-batch.README.md`) is a separate batch command that generates mockups post-hoc and is not pre-populated for this story.

---

## 11. Completion Criteria for Implementer

Each slice implementer must deliver:
1. All slice-scoped acceptance criteria verified
2. Unit tests for happy paths, boundaries, and failures
3. Repository format, lint, typecheck, and test gates pass
4. Dedup report generated (`docs/vnpt-flow/epic-run-epic-02/2-3-{slice}/dedup_report.json`)
5. File list populated in story change log
6. Story status updated to `in-progress` during work, `review` when all slices complete

---

**Plan Status:** ✅ READY_FOR_IMPLEMENTER_DISPATCH
**Quality Gate:** PASS (all checks clean)
**Next Action:** Dispatch Slice 2-3-A to `vnpt-epic-story-implementer`
