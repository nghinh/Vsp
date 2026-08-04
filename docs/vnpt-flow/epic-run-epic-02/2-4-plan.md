# Story 2.4 Plan: Manage Golf Bag and Clubs

**Run ID:** run_2026_08_02_005
**Epic:** Epic-02 (Golfer Management)
**Wave:** 4 of 5 (2-4 depends on 2-3; sequential chain)
**Status:** PLANNING
**Story Source:** `docs/implementation-artifacts/epic-02/2-4-manage-golf-bag-and-clubs.md`

---

## 1. Story Scope Summary

**User Story:** As a golfer, I want to maintain golf bags and clubs so that rounds can reference my active equipment.

**Acceptance Criteria:**
| AC | Description |
|----|-------------|
| AC-1 | User can create bags and add/edit/delete clubs with loft, carry, total, dispersion, shaft, and use date. |
| AC-2 | Exactly one bag can be selected as active for a round. |
| AC-3 | Data-driven recommendations remain disabled until minimum data threshold is met. |

---

## 2. PRD / Architecture / UX Alignment Evidence

### PRD Alignment (docs/planning-artifacts/prd.md)
- **Section 8.1 Account and Profile:** "Golfer profile supports..." — golf bag/club data is separate from golfer profile.
- **Section 9.1 Core Entities:** `Club` and `GolfBag` listed as core entities in the data model.
- **Section 8.4 Round Setup:** "User selects course, layout, holes, tee, game format, players, handicap, mode, and active bag." — active bag selection is required at round setup.
- **Section 10.4 Offline:** "Offline-supported functions: Club selection" — club data must be available offline.
- **Phase 2 (deferred):** "Club distance, Driving Zone, dispersion" — `dispersion` field is listed in AC-1 but is Phase 2 scope. It must be stored but NOT used for recommendations until Phase 2.
- **Phase 2 deferred club recommendation:** "Smart Caddie AI" / "Club recommendation" — recommendations UI is disabled until minimum data threshold per AC-3.

### Architecture Alignment (docs/planning-artifacts/architecture.md)
- **Section 6.1 Modular Monolith:** Bag and Club entities belong in a new `bag` module (bounded context under golfer management).
- **Section 7.1 Source of Truth:** PostgreSQL canonical; mobile stores local cache for offline club selection.
- **Section 8.3 Offline Sync:** Club selection must work offline — sync follows same event-queue + idempotent API pattern from 2-3-B.
- **Section 15 Deferred Architecture Hooks:** "Club performance model for future dispersion and recommendations" — schema hooks exist; implementation deferred.
- **Section 11.2 Minimum API Groups:** No existing `/bags/*` or `/clubs/*` endpoint group — new module needed.

### UX Spec Alignment (docs/planning-artifacts/ux-spec.md)
- **Section 5.1 Bottom Navigation:** Profile tab exists in main nav; bags/clubs accessible from Profile tab or "More" tab.
- **Section 5.2 Onboarding/Auth:** Round setup references active bag selection (Line 172: "Active bag selection if available").
- **Section 10 Accessibility:** Field validation, screen reader labels, touch targets ≥44/48pt, non-color-only status.
- **Section 9 Forms and Feedback:** Labels visible, errors near field, loading states.

### 2-3 Output Analysis (epic-run-epic-02/2-3-*-implementation.md)
| 2-3 Deliverable | Relevance to 2.4 |
|-----------------|-----------------|
| `GolferProfile` entity + repo + service | Same pattern for `GolfBag` and `Club` entities |
| `ProfileController` (`GET /profiles/me`, `PUT`) | Same REST pattern for `BagController` |
| `ProfileDTO` with enums (`DistanceUnit`, `SkillLevel`) | Same DTO/enum pattern for `BagDTO`, `ClubDTO` |
| `ProfileSyncStore` SQLite offline queue | Same offline queue pattern for bag/club sync |
| `ProfileRepository` with flush-on-reconnect | Same repository + connectivity listener pattern |
| `ProfileBloc` with events/states | Same BLoC pattern for `BagBloc`, `ClubBloc` |
| `packages/contracts/schemas/profile.yaml` | Same contract pattern for `bag.yaml`, `club.yaml` |
| Design system tokens (Story 1.4) | All UI uses `VspColorSemantic`, `VspSpacing`, `VspButton` |

### Epic-01 Foundations
| Epic-01 Story | Relevance to 2.4 |
|---------------|-------------------|
| Story 1.4 (Design System) | All UI uses semantic tokens: `VspColorLight`, `VspSpacingSemantic`, `VspFontWeight` |
| Story 1.5 (Observability/Security) | Audit trail for bag/club changes, encrypted local storage |

---

## 3. Gap Analysis: Existing State vs. Required

### Backend
| What Exists | What Is Missing |
|-------------|-----------------|
| `GolferProfile` entity + module | New `GolfBag` and `Club` entities + `bag` module |
| `ProfileService` + `ProfileServiceImpl` | New `BagService` + `ClubService` (or combined `BagService` managing both) |
| `ProfileController` (`/profiles/me`) | New `BagController` (`/bags/*`, `/bags/{id}/clubs/*`) |
| `packages/contracts/schemas/profile.yaml` | New `packages/contracts/schemas/bag.yaml`, `club.yaml` |
| OpenAPI `/profiles/me` endpoints | OpenAPI extension for bag/club endpoints |
| `ProfileServiceImplTest` | New `BagServiceImplTest`, `ClubServiceImplTest` |
| VspErrorCode `PROFILE_00X` | New `BAG_00X`, `CLUB_00X` error codes |

### Mobile
| What Exists | What Is Missing |
|-------------|-----------------|
| `ProfileDTO`, `ProfileService`, `ProfileRepository`, `ProfileSyncStore` | `BagDTO`, `ClubDTO`, `BagService`, `ClubService`, `BagRepository`, `ClubSyncStore` |
| `ProfileBloc` + `ProfileScreen` | `BagBloc` + `BagScreen`, `ClubBloc` + `ClubManagementScreen` |
| Offline queue via SQLite + connectivity_plus | Same offline queue pattern for bag/club updates |
| Design system tokens | All bag/club UI uses same tokens |
| Profile tab in bottom nav | Bag/club management accessible from Profile or "More" tab |

---

## 4. Slice Plan

### Slice 2-4-A: Backend — GolfBag Entity, Club Entity, Repository, and API
**Rationale:** Backend bag/club data layer is the foundation. Depends only on 2-3's Identity Module (for authenticated user context via `GolferAccount`). Independent of mobile. Tests AC-1 (club fields) and AC-2 (active bag constraint) on backend.

**Scope:**

**New module: `bag`**
- `apps/api/src/main/resources/db/migration/V7__golf_bags.sql` — `golf_bags` table (id, golfer_account_id FK, name, active, created_at, updated_at)
- `apps/api/src/main/resources/db/migration/V8__clubs.sql` — `clubs` table (id, golf_bag_id FK, club_type, loft, carry_distance, total_distance, dispersion, shaft, use_date, created_at, updated_at)
- `apps/api/src/main/java/vnpt/vsp/module/bag/entity/GolfBag.java` — JPA entity; `active` boolean; unique constraint on (golfer_account_id, active) where active=true via service-level enforcement
- `apps/api/src/main/java/vnpt/vsp/module/bag/entity/Club.java` — JPA entity; `clubType` enum (DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER); all AC-1 fields stored as meters for distance
- `apps/api/src/main/java/vnpt/vsp/module/bag/repository/GolfBagRepository.java` — `findByGolferAccountId()`, `findByGolferAccountIdAndActiveTrue()` (for AC-2), `findByIdAndGolferAccountId()`
- `apps/api/src/main/java/vnpt/vsp/module/bag/repository/ClubRepository.java` — `findByGolfBagId()`, `findByIdAndGolfBagId()`, `countByGolfBagId()` (for AC-3 threshold check)
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/GolfBagResponse.java` — response DTO with all bag fields + list of clubs
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/CreateGolfBagRequest.java` — request DTO (name only for create)
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/UpdateGolfBagRequest.java` — request DTO (name, active flag)
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/ClubResponse.java` — response DTO with all club fields
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/CreateClubRequest.java` — request DTO with all club fields + validation annotations
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/UpdateClubRequest.java` — partial update DTO
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagService.java` — interface: `getBags()`, `createBag()`, `updateBag()`, `deleteBag()`, `setActiveBag()`, `getClubs()`, `createClub()`, `updateClub()`, `deleteClub()`, `getActiveBag()`
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagServiceImpl.java` — implementation; `setActiveBag()` deactivates all other bags for golfer before activating new one (AC-2); auto-creates default bag on first `getBags()` call if none exist
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagController.java` — `GET /bags` (list), `POST /bags` (create), `PUT /bags/{id}` (update), `DELETE /bags/{id}` (delete), `POST /bags/{id}/activate` (set active), `GET /bags/{id}/clubs` (list clubs), `POST /bags/{id}/clubs` (add club), `PUT /bags/{bagId}/clubs/{clubId}` (update club), `DELETE /bags/{bagId}/clubs/{clubId}` (delete club); all authenticated; audit log on create/update/delete
- `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` — add `BAG_001` (Bag not found), `BAG_002` (Cannot delete last bag), `CLUB_001` (Club not found), `CLUB_002` (Club not in bag)
- `packages/contracts/schemas/bag.yaml` — new schema file with all bag/club DTO definitions
- `packages/contracts/schemas/club.yaml` — club-specific DTOs
- `packages/contracts/openapi.yaml` — add `/bags` GET/POST, `/bags/{id}` GET/PUT/DELETE, `/bags/{id}/activate` POST, `/bags/{id}/clubs` GET/POST, `/bags/{bagId}/clubs/{clubId}` PUT/DELETE; `Bag` tag
- `apps/api/src/test/java/vnpt/vsp/module/bag/BagServiceImplTest.java` — tests: create bag, list bags, setActiveBag (only one active), cannot delete last bag, create club with all fields, update club, delete club, minimum data threshold check

**Key Design Decisions:**

1. **AC-1: Club fields**: `clubType` (enum), `loft` (Double, degrees), `carryDistance` (Double, meters, canonical), `totalDistance` (Double, meters, canonical), `dispersion` (Double, degrees — stored per AC-1 but NOT used in MVP recommendations per Phase 2 deferral), `shaft` (String), `useDate` (LocalDate). Distances stored as canonical meters.

2. **AC-2: One active bag**: `GolfBag.active` boolean. Service-level enforcement: `setActiveBag(bagId)` → find all golfer's bags, set `active=false`, then set `active=true` on target bag. Unique constraint: (golfer_account_id, active=true) enforced at service layer.

3. **AC-3: Minimum data threshold**: `BagServiceImpl.getActiveBag()` checks if active bag has at least one club with non-null `carryDistance`. Returns a flag or the check is exposed via `BagService.hasMinimumClubData(bagId)`. Mobile uses this to disable recommendations.

4. **Auto-create default bag**: On first `GET /bags` call, if no bags exist for golfer, auto-create a default empty bag named "My Bag" with `active=true`.

5. **Canonical unit storage**: `carryDistance` and `totalDistance` stored in meters. Display conversion is mobile responsibility (same pattern as `driverDistance` in 2-3).

**Dependencies:** Slice 2-3-A (profile module, GolferAccount FK context, authenticated user)

**Risks:**
- None identified — pattern directly follows 2-3-A ProfileServiceImpl; no shared state with other modules

---

### Slice 2-4-B: Mobile — Bag/Club DTO, Repository, Offline Queue
**Rationale:** Mobile data layer for bag/club including offline queue. Depends on Slice 2-4-A's API contracts. Independent of mobile UI.

**Scope:**

- `apps/mobile/lib/features/bag/data/bag_dto.dart` — `BagDTO` with: id, golferAccountId, name, active, clubs (List<ClubDTO>), createdAt, updatedAt; `BagListDTO` for GET /bags response
- `apps/mobile/lib/features/bag/data/club_dto.dart` — `ClubDTO` with: id, golfBagId, clubType (enum ClubType), loft, carryDistance (meters), totalDistance (meters), dispersion, shaft, useDate; `CreateClubRequest`, `UpdateClubRequest`; `hasMinimumData()` getter for AC-3 check
- `apps/mobile/lib/features/bag/data/bag_service.dart` — `BagService` wrapping: GET /bags, POST /bags, PUT /bags/{id}, DELETE /bags/{id}, POST /bags/{id}/activate, GET /bags/{id}/clubs, POST /bags/{id}/clubs, PUT /bags/{bagId}/clubs/{clubId}, DELETE /bags/{bagId}/clubs/{clubId}
- `apps/mobile/lib/features/bag/data/bag_repository.dart` — `BagRepository`: wraps service; adds offline queue for create/update/delete operations on bags and clubs; `flushQueue()` on reconnect via connectivity_plus listener; `getActiveBag()` returns bag with `active=true`; `hasMinimumClubData()` delegates to active bag's clubs
- `apps/mobile/lib/core/storage/bag_sync_store.dart` — `BagSyncStore` — SQLite-backed offline queue for bag/club updates; same pattern as `ProfileSyncStore`; stores: idempotency_key, operation_type (CREATE_BAG/UPDATE_BAG/DELETE_BAG/CREATE_CLUB/UPDATE_CLUB/DELETE_CLUB), entity_id, payload (JSON), created_at, synced_at
- Update `apps/mobile/pubspec.yaml` — no new packages needed (sqflite, uuid, connectivity_plus already added in 2-3-B)
- Unit tests: `bag_dto_test.dart` (BagDTO, ClubDTO, hasMinimumData), `bag_sync_store_test.dart` (queue operations), `bag_repository_test.dart` (queue, flush, active bag, minimum threshold)

**Key Design Decisions:**

1. **AC-3 minimum data threshold**: `ClubDTO.hasMinimumData()` returns `clubType != null && carryDistance != null`. `BagRepository.hasMinimumClubData()` returns `activeBag.clubs.any((c) => c.hasMinimumData())`.

2. **Offline queue granularity**: Separate queue entry types for bag ops vs club ops. Club operations include `bagId` reference for context. Same idempotency-key + connectivity listener pattern as 2-3-B.

3. **No new packages**: sqflite, uuid, connectivity_plus already in pubspec.yaml from 2-3-B.

**Dependencies:** Slice 2-4-A (API contracts)

**Risks:**
- None identified — offline queue pattern already implemented and tested in 2-3-B

---

### Slice 2-4-C: Mobile — Bag/Club Screen UI
**Rationale:** Mobile UI for viewing and managing bags/clubs. Depends on Slice 2-4-B data layer. Uses design system from Story 1.4.

**Scope:**

- `apps/mobile/lib/features/bag/presentation/bag_bloc.dart` — `BagBloc` with events: `LoadBags`, `CreateBag`, `UpdateBag`, `DeleteBag`, `SetActiveBag`, `LoadClubs`, `CreateClub`, `UpdateClub`, `DeleteClub`; states: `BagInitial`, `BagLoading`, `BagLoaded`, `BagError`; includes `hasMinimumClubData` in state for AC-3
- `apps/mobile/lib/features/bag/presentation/bag_screen.dart` — main bag list screen: list of bags, active bag highlighted with checkmark, tap to select active, FAB to add new bag, swipe to delete
- `apps/mobile/lib/features/bag/presentation/bag_detail_screen.dart` — bag detail: bag name, active indicator, list of clubs, FAB to add club, tap club to edit, swipe to delete
- `apps/mobile/lib/features/bag/presentation/club_form_screen.dart` — club form: clubType picker, loft, carry distance, total distance, dispersion (labeled "Phase 2"), shaft, use date; all fields with proper numeric keyboards; validation feedback
- `apps/mobile/lib/features/bag/presentation/widgets/bag_card.dart` — bag card with name, active badge, club count
- `apps/mobile/lib/features/bag/presentation/widgets/club_card.dart` — club card with club type icon, loft, distances
- `apps/mobile/lib/features/bag/presentation/widgets/club_type_picker.dart` — bottom sheet picker for club type
- Navigation: Profile tab → Bag management → BagListScreen → BagDetailScreen → ClubFormScreen
- Loading, error, empty states — follow same patterns as ProfileScreen (2-3-C)
- Recommendations UI: `RecommendationsDisabledBanner` widget showing "Add clubs to enable recommendations" with info icon; shown on BagDetailScreen when `!hasMinimumClubData`
- Accessibility: all fields have `Semantics` labels; touch targets ≥44pt; screen reader reads field names + values
- Offline indicator: "Saved offline" snackbar when update queued; "Synced" when flush succeeds

**Key Design Decisions:**

1. **AC-2 active bag UI**: Active bag shows checkmark badge; "Set Active" button on each bag card; tapping "Set Active" calls `setActiveBag()` which deactivates previous and activates new

2. **AC-3 recommendations disabled**: `RecommendationsDisabledBanner` always visible on bag detail unless `hasMinimumClubData()` returns true. Banner uses `VspColorSemantic.warning` with info icon. No recommendation content is shown in MVP — just the disabled banner.

3. **Dispersion field (Phase 2)**: Club form includes `dispersion` field (labeled "Dispersion (degrees) — available in Phase 2") as read-only/disabled in MVP, stored but not displayed in club card.

4. **Design system compliance**: All widgets use `VspColorSemantic`, `VspSpacing`, `VspButton`, `VspTextField`, `VspSpacingSemantic.touchTargetMin`.

**Dependencies:** Slice 2-4-B (data layer + repository)

**Risks:**
- None identified — follows established patterns from 2-3-C ProfileScreen and Story 1.4 design system

---

## 5. Slice-to-AC Mapping

| Slice | AC-1 (Create bags, add/edit/delete clubs with all fields) | AC-2 (Exactly one bag active) | AC-3 (Recommendations disabled until threshold) |
|-------|----------------------------------------------------------|-------------------------------|-----------------------------------------------|
| 2-4-A (Backend) | ✅ Full — `GolfBag`+`Club` entities with all fields; CRUD endpoints; `carryDistance`/`totalDistance` in meters | ✅ Full — `setActiveBag()` service method deactivates all others; unique constraint enforced | ✅ Full — `hasMinimumClubData()` service method checks club count + carryDistance |
| 2-4-B (Mobile data) | ✅ Full — `BagDTO`/`ClubDTO` mirror all fields; offline queue for all CRUD ops | ✅ Full — `BagRepository.getActiveBag()`; `setActiveBag()` queues activate call | ✅ Full — `ClubDTO.hasMinimumData()`; `BagRepository.hasMinimumClubData()` |
| 2-4-C (Mobile UI) | ✅ Full — `BagDetailScreen` shows clubs; `ClubFormScreen` all fields; create/edit/delete flows | ✅ Full — active badge + "Set Active" button per bag; only one active at a time | ✅ Full — `RecommendationsDisabledBanner` when `!hasMinimumClubData`; no recommendation content shown in MVP |

---

## 6. Key Design Decisions

### AC-1: Club Field Definitions
**Decision:** `Club` entity stores `clubType` (enum), `loft` (Double, degrees), `carryDistance` (Double, meters), `totalDistance` (Double, meters), `dispersion` (Double, degrees), `shaft` (String), `useDate` (LocalDate).

**Rationale:** AC-1 explicitly lists all these fields. `dispersion` is stored per AC-1 but NOT used for recommendations in MVP (Phase 2 scope per PRD Section 12 "Club distance, Driving Zone, dispersion" is Phase 2). Storage format: meters for distances (canonical, consistent with `driverDistance` in 2-3 profile).

**Conversion:** Display conversion (meters ↔ yards) handled at mobile layer via `ClubDTO.displayCarryDistance` and `ClubDTO.displayTotalDistance` (same pattern as `displayDriverDistance` in 2-3-B).

### AC-2: Active Bag Constraint
**Decision:** `GolfBag.active` boolean. Service-layer enforcement: `setActiveBag(bagId)` runs in a transaction: `UPDATE golf_bags SET active=false WHERE golfer_account_id=X; UPDATE golf_bags SET active=true WHERE id=bagId AND golfer_account_id=X`.

**Rationale:** Database-level "only one active" constraint is complex (would require partial unique index or trigger). Service-layer enforcement is simpler and consistent with the transactional context of `BagServiceImpl`. Auto-creates a default "My Bag" on first access to avoid empty-state issues.

### AC-3: Minimum Data Threshold
**Decision:** Threshold = active bag has **at least one club** with non-null `carryDistance`. `BagService.hasMinimumClubData(bagId)` → `clubRepository.countByGolfBagIdAndCarryDistanceIsNotNull(bagId) >= 1`.

**Rationale:** Simplest threshold that proves the user has entered real club data. The PRD does not specify a number — this is a reasonable MVP default. The threshold can be adjusted later (e.g., "at least 4 clubs with carry distances") based on product feedback.

### Dispersion Field (Phase 2 Deferral)
**Decision:** `dispersion` field is included in the `Club` entity and `ClubDTO` but the recommendations feature itself is not built in MVP.

**Rationale:** AC-1 explicitly lists dispersion as a club field. The PRD (Section 12 Phase 2) lists "Dispersion analytics" as Phase 2. Storing the field now avoids a schema migration later when Phase 2 builds the recommendation engine. The field is labeled "Phase 2" in the club form UI.

---

## 7. Skill Gap Analysis

| Required Skill | Status | Evidence |
|----------------|--------|----------|
| `bmad-dev-story` | ✅ Available | Loaded from `.agents/skills/bmad-dev-story/SKILL.md` |
| `vnpt-tdd` | ✅ Available | Skill `vnpt-tdd` in available_skills |
| Spring Boot JPA + modular monolith | ✅ Epic-01 + 2-3-A foundation | `GolferProfile`, `Club` entities follow same JPA patterns |
| Flutter BLoC state management | ✅ 2-3-C + 1-4 patterns | `ProfileBloc`; `BagBloc` follows same architecture |
| Flutter SQLite/offline queue | ✅ 2-3-B | `ProfileSyncStore` already implemented |
| Design system tokens (Story 1.4) | ✅ Verified | `VspColorSemantic`, `VspSpacing` used in 2-3-C |
| OpenAPI contract extension | ✅ 2-3-A pattern | `profile.yaml` extended; `bag.yaml`/`club.yaml` follow same pattern |

**No skill gaps identified. All required skills and stack patterns are available.**

---

## 8. Quality Gate Checklist

### Pre-Dispatch Checks
| Check | Result | Evidence |
|-------|--------|----------|
| Story source status is `ready-for-dev` | ✅ Yes | `docs/implementation-artifacts/epic-02/2-4-manage-golf-bag-and-clubs.md` line 5: `status: ready-for-dev` |
| No placeholder/TODO-only scope | ✅ Clean | Full implementation scope defined in slices |
| No deferred-production behavior | ✅ Clean | All 3 ACs addressed: club CRUD, active bag, disabled recommendations |
| Dispersion deferred correctly | ✅ Clean | Field stored but recommendations UI disabled; Phase 2 hook preserved |
| Skill-not-found error | ✅ None | Both `bmad-dev-story` and `vnpt-tdd` confirmed available |
| Story 2-3 dependency resolved | ✅ Done | Story 2-3 `status: done` per epic-state.json |
| Epic-01 dependencies resolved | ✅ Done | Epic-01 `status: done` per epic-state.json |

### Anti-Shortcut Evidence
| Check | Result |
|-------|--------|
| No skipping required context reading | ✅ All required sources read: PRD, architecture, ux-spec, story spec, 2-3 plan/impl/A/B/C, epic-inventory, epic-state, 1-4/1-5 acceptance matrices |
| No collapse of independent slices into sequential-only | ✅ Slices 2-4-B and 2-4-C can run in parallel (both depend on 2-4-A contracts; B and C are independent) |
| PRD/Architecture/UX alignment verified | ✅ Full cross-reference in Section 2 |
| AC coverage verified per slice | ✅ Section 5 slice-to-AC mapping |
| Wave 4 sequential dependency honored | ✅ 2-4 depends on 2-3 completed |
| Dispersion Phase 2 hook preserved | ✅ Field stored in entity/DTO but not used in MVP recommendations |

### Dedup Pre-Check (symbols expected in new code)
| Symbol Pattern | Location | Dedup Action |
|----------------|----------|--------------|
| `GolfBag` (entity) | `apps/api/src/main/java/vnpt/vsp/module/bag/entity/` | New module — no collision expected |
| `Club` (entity) | `apps/api/src/main/java/vnpt/vsp/module/bag/entity/` | New module — no collision expected |
| `GolfBagRepository`, `ClubRepository` | `apps/api/src/main/java/vnpt/vsp/module/bag/repository/` | New module — no collision |
| `BagService`, `BagServiceImpl` | `apps/api/src/main/java/vnpt/vsp/module/bag/` | New module — no collision |
| `BagController` | `apps/api/src/main/java/vnpt/vsp/module/bag/` | New module — no collision |
| `GolfBagResponse`, `CreateGolfBagRequest`, `UpdateGolfBagRequest` | `apps/api/src/main/java/vnpt/vsp/module/bag/dto/` | New module — no collision |
| `ClubResponse`, `CreateClubRequest`, `UpdateClubRequest` | `apps/api/src/main/java/vnpt/vsp/module/bag/dto/` | New module — no collision |
| `BagDTO`, `ClubDTO` (Flutter) | `apps/mobile/lib/features/bag/data/` | New feature directory — no collision |
| `BagBloc`, `BagScreen`, `BagDetailScreen`, `ClubFormScreen` | `apps/mobile/lib/features/bag/presentation/` | New feature directory — no collision |
| `BagSyncStore` | `apps/mobile/lib/core/storage/` | Serena check vs `ProfileSyncStore` — if similar name → use different name or verify different class |
| `bag.yaml`, `club.yaml` (contracts) | `packages/contracts/schemas/` | New schema files — no collision |
| `/bags/*` OpenAPI paths | `packages/contracts/openapi.yaml` | Extend existing — no collision |

---

## 9. Implementation Wave Recommendation

**Recommended dispatch order:**
1. **Slice 2-4-A** (backend, wave 1) — first: mobile depends on its API contracts
2. **Slice 2-4-B** (mobile data layer, wave 2, depends on A) — parallel with C is possible since both depend on A's contracts
3. **Slice 2-4-C** (mobile UI, wave 2, depends on A) — parallel with B; both can proceed once OpenAPI contracts are published

**Rationale:** Backend bag/club entities and API establishes the contracts. Mobile data layer (2-4-B) and UI (2-4-C) both depend on those contracts but are independent of each other. All three can be developed simultaneously once Slice A is done.

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
    "docs/vnpt-flow/epic-run-epic-02/2-3-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-3-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-3-B-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-3-C-implementation.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-4-manage-golf-bag-and-clubs.md"
  ],
  "mockup_sources_read": [
    "docs/vnpt-stitch-mockup-batch/README.md"
  ],
  "additional_context_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md",
    "apps/api/src/main/java/vnpt/vsp/module/profile/entity/GolferProfile.java",
    "apps/api/src/main/java/vnpt/vsp/module/profile/repository/GolferProfileRepository.java",
    "apps/api/src/main/java/vnpt/vsp/module/profile/ProfileService.java",
    "apps/api/src/main/java/vnpt/vsp/module/profile/ProfileServiceImpl.java",
    "apps/api/src/main/java/vnpt/vsp/module/round/RoundModule.java",
    "apps/mobile/lib/features/profile/data/profile_dto.dart",
    "apps/mobile/lib/features/profile/data/profile_service.dart",
    "apps/mobile/lib/features/profile/data/profile_repository.dart",
    "apps/mobile/lib/core/storage/profile_sync_store.dart",
    "apps/mobile/lib/features/profile/presentation/profile_bloc.dart",
    "apps/mobile/lib/features/profile/presentation/profile_screen.dart",
    "packages/contracts/schemas/profile.yaml",
    "packages/contracts/openapi.yaml"
  ]
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story. The Stitch mockup batch (`vnpt-stitch-mockup-batch/README.md`) is a separate batch command that generates mockups post-hoc and is not pre-populated for this story.

---

## 11. Completion Criteria for Implementer

Each slice implementer must deliver:
1. All slice-scoped acceptance criteria verified
2. Unit tests for happy paths, boundaries, and failures
3. Repository format, lint, typecheck, and test gates pass
4. Dedup report generated (`docs/vnpt-flow/epic-run-epic-02/2-4-{slice}/dedup_report.json`)
5. File list populated in story change log
6. Story status updated to `in-progress` during work, `review` when all slices complete

---

**Plan Status:** ✅ READY_FOR_IMPLEMENTER_DISPATCH
**Quality Gate:** PASS (all checks clean)
**Next Action:** Dispatch Slice 2-4-A to `vnpt-epic-story-implementer`
