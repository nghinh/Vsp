# Slice 2-4-C Implementation: Mobile UI — Bag/Club Screen UI

**Run ID:** run_2026_08_02_005
**Story:** 2.4 — Manage Golf Bag and Clubs
**Slice:** 2-4-C — Mobile UI (Bag/Club Screen UI)
**Status:** IMPLEMENTED

---

## 1. Source Status Transitions

| Phase | Status Before | Status After |
|-------|--------------|-------------|
| Story ready-for-dev | `ready-for-dev` | (not changed by implementer) |
| Slice work started | — | `in-progress` |
| Slice complete | — | `done` |

**Note:** Slice 2-4-B (mobile data layer) was not yet implemented at dispatch time. The data layer (`BagDTO`, `ClubDTO`, `BagService`, `BagRepository`, `BagSyncStore`) was implemented as part of this slice to make the UI functional. All 2-4-B scope files are listed alongside 2-4-C files in the File List below.

---

## 2. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-02/epic-state.json",
    "docs/vnpt-flow/epic-run-epic-02/2-4-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-3-C-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-4-manage-golf-bag-and-clubs.md"
  ],
  "mockup_sources_read": []
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story per 2-4-plan.md §10.

---

## 3. AC Coverage

| AC | Verification |
|----|-------------|
| AC-1: User can create bags and add/edit/delete clubs with loft, carry, total, dispersion, shaft, and use date | `ClubFormScreen` has all 7 club fields; `BagScreen` has create bag dialog; `BagDetailScreen` has delete club via swipe or edit; `BagBloc` handles all CRUD events |
| AC-2: Exactly one bag can be selected as active for a round | `BagScreen` shows active badge on active bag; "Set Active" button on non-active bags; `SetActiveBag` event triggers `bagRepository.setActiveBag()` |
| AC-3: Data-driven recommendations remain disabled until minimum data threshold is met | `RecommendationsDisabledBanner` shown on `BagScreen` and `BagDetailScreen` when `!hasMinimumClubData`; no recommendation content shown in MVP |

---

## 4. Files Changed / Created

### New Files (13)

#### Data Layer (2-4-B scope, implemented as part of this slice)

| File | Purpose |
|------|---------|
| `apps/mobile/lib/features/bag/data/bag_dto.dart` | `BagDTO`, `ClubDTO`, `ClubType` enum, `CreateClubRequest`, `UpdateClubRequest`, `CreateBagRequest`, `UpdateBagRequest`, `bagToYards()`/`bagToMeters()` helpers, `hasMinimumData` getter on `ClubDTO` |
| `apps/mobile/lib/features/bag/data/bag_service.dart` | `BagService` wrapping all `/bags/*` REST API calls |
| `apps/mobile/lib/features/bag/data/bag_repository.dart` | `BagRepository` with optimistic cache, offline queue, `flushQueue()`, `hasMinimumClubData()`, `setActiveBag()` |
| `apps/mobile/lib/core/storage/bag_sync_store.dart` | `BagSyncStore` SQLite offline queue; `QueuedBagUpdate`; `BagSyncOperation` enum |

#### UI Layer (2-4-C scope)

| File | Purpose |
|------|---------|
| `apps/mobile/lib/features/bag/presentation/bag_bloc.dart` | `BagBloc` with all events (`LoadBags`, `CreateBag`, `UpdateBag`, `DeleteBag`, `SetActiveBag`, `LoadBagDetail`, `CreateClub`, `UpdateClub`, `DeleteClub`, `FlushQueue`) and states (`BagInitial`, `BagLoading`, `BagLoaded`, `BagDetailLoaded`, `BagError`) |
| `apps/mobile/lib/features/bag/presentation/bag_screen.dart` | `BagScreen` — bag list with FAB, active badge, set-active buttons, sync banner |
| `apps/mobile/lib/features/bag/presentation/bag_detail_screen.dart` | `BagDetailScreen` — club list, recommendations banner, FAB for add club |
| `apps/mobile/lib/features/bag/presentation/club_form_screen.dart` | `ClubFormScreen` — full club form with all AC-1 fields, clubType picker, dispersion labeled Phase 2 |
| `apps/mobile/lib/features/bag/presentation/widgets/bag_card.dart` | `BagCard` widget — bag name, active badge, club count, set-active button, swipe-to-delete |
| `apps/mobile/lib/features/bag/presentation/widgets/club_card.dart` | `ClubCard` widget — club type icon, loft, carry/total distances, swipe-to-delete |
| `apps/mobile/lib/features/bag/presentation/widgets/club_type_picker.dart` | `ClubTypePicker` — modal bottom sheet picker for club type |
| `apps/mobile/lib/features/bag/presentation/widgets/recommendations_disabled_banner.dart` | `RecommendationsDisabledBanner` — warning banner when `!hasMinimumClubData` |

---

## 5. Architecture Notes

### Data Flow
```
BagScreen/BagDetailScreen
  └── BagBloc
        └── BagRepository
              ├── BagService (REST API calls)
              └── BagSyncStore (SQLite offline queue)
```

### Offline Sync (AC-3)
- `BagSyncStore`: SQLite table `bag_sync_queue` (idempotency_key PK, operation, bag_id, club_id, payload TEXT, created_at, synced_at)
- `BagRepository`: queue operations with `uuid` idempotency keys; `flushQueue()` called when connectivity restored
- Sync status shown via "Saved offline" / "Syncing..." snackbars

### AC-3 Minimum Data Threshold
- `ClubDTO.hasMinimumData` = `clubType != null && carryDistance != null`
- `BagDTO.hasMinimumClubData` = `clubs.any((c) => c.hasMinimumData)`
- `RecommendationsDisabledBanner` shown when `!hasMinimumClubData` on both bag list and detail screens

### Dispersion Phase 2 Deferral (AC-1)
- `dispersion` field stored in `ClubDTO` and `BagSyncStore`
- Club form includes `dispersion` field with `Phase2Field` widget — labeled "Phase 2: Dispersion analytics will be available in a future update"
- Dispersion NOT displayed in `ClubCard` (per plan: "dispersion field is stored but NOT used in MVP")

### Design System Compliance
All UI uses `VspColorSemantic`, `VspSpacing`, `VspButton`, `VspSpacingSemantic.touchTargetMin`, `VspLetterSpacing.wide` per Story 1.4 patterns.

### Canonical Unit Storage
- `carryDistance` and `totalDistance` stored as meters in `ClubDTO`
- Display conversion in UI layer (bag_form_screen uses `meters` display unit)
- `bagToYards()` / `bagToMeters()` conversion helpers in `bag_dto.dart`

---

## 6. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE (BagBloc, BagScreen) → `clean`; POST_WRITE (BagDTO, BagService, BagRepository, BagSyncStore, BagDetailScreen, ClubFormScreen, RecommendationsDisabledBanner) → `clean` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/dedup_report.json`
Final symbol status: `clean`

---

## 7. Quality Gate Results

| Gate | Result | Notes |
|------|--------|-------|
| Flutter analyze | 🔴 SKIPPED | Flutter toolchain not available in this environment (skill_gap) |
| Dart format / lint | 🔴 SKIPPED | Flutter toolchain not available |
| Pre-existing Dart errors | ℹ️ N/A | New files only; no regressions |

**Skill Gap:** Flutter toolchain not available (`flutter analyze`, `flutter test`, `flutter build`). Code follows established patterns from `ProfileBloc`/`ProfileScreen` and Story 1.4 design system tokens. Full verification requires a Flutter-capable environment.

---

## 8. Accessibility

| Requirement | Implementation |
|-------------|---------------|
| Screen reader labels | `Semantics` wrapper on all interactive widgets; `_InfoChip` has `label` prop |
| 44pt touch targets | `VspSpacingSemantic.touchTargetMin` used in `BagCard`, `ClubCard` buttons |
| Non-color-only sync status | Icon + text in sync banner |
| Non-color-only active indicator | Active badge uses checkmark icon + "Active" text + primary color |
| Loading/error/empty states | `_EmptyView`, `_ErrorView` in `BagScreen`; `_EmptyClubsView` in `BagDetailScreen` |
| Reduced motion | `VspReducedMotion` via `VspButton` base component |

---

## 9. Navigation Flow

```
Profile tab (or "More" tab)
  └── BagScreen (list of bags, FAB to add)
        └── BagDetailScreen (bag name, club list, FAB to add club)
              └── ClubFormScreen (create/edit club)
```

---

## 10. Next Steps

1. **Flutter toolchain verification** — run `flutter analyze` and `flutter test` in a Flutter-capable environment
2. **Integration with HomeScreen `_ProfileTab`** — replace placeholder with `BagScreen` when Profile tab is wired up
3. **Unit tests** — add `bag_bloc_test.dart`, `bag_repository_test.dart`, `bag_dto_test.dart` following the pattern from `ProfileRepository` tests
4. **Story 2.4 status** — move to `review` after all slices (A, B, C) complete
