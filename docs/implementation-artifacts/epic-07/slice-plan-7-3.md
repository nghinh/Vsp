# Slice Plan: Story 7.3 — Display Official Pin and Course Conditions

**Epic Run Folder**: `docs/vnpt-flow/epic-run-run_2026_08_02_010/`
**Story Status**: `ready-for-dev` → `in-progress`
**Planner**: `vnpt-epic-story-runner`
**Date**: 2026-08-02

---

## 1. Context Reading Evidence

| Doc | Key Sections Used |
|-----|-----------------|
| `prd.md` (551 lines) | §8.9 Weather/Wind, §8.11 Course Ops Portal, §9.1 Core Entities (PinPosition, CourseCondition, GreenCondition), §9.3 Data Quality Fields, §9.4 Accuracy Classes |
| `architecture.md` (390 lines) | §7 Data Architecture (versioning, effective/expiry), §8 Mobile Architecture (local-first, offline), §9 Map Architecture (pin in package), §11 API Architecture |
| `ux-spec.md` (492 lines) | §6 Active Round UX (Conditions screen), §4.2 Color tokens (official=green, estimated=amber, stale=red/gray) |
| `epics.md` (748 lines) | Epic 7 story 7.3 ACs + Epic 8 §8.5 Manage Pins/Green Speed/Conditions |
| `story-7.3.md` (58 lines) | ACs, Tasks, Dev Context, Dependencies (7.2) |
| `story-7.2.md` (58 lines) | Dependency — wind/conditions surface pattern |
| `conditions_section.dart` (186 lines) | Existing conditions UI — needs extension |
| `pin_entity.dart` (63 lines) | Existing pin entity — needs effective/expiry |
| `condition_entry.dart` (119 lines) | Existing condition entry — needs source/confidence/expiry |
| `data_freshness.dart` (103 lines) | Has `isStale` (>30 days), needs expiry DateTime field |

---

## 2. AC Gap Analysis

| AC | Current State | Required |
|----|--------------|----------|
| **AC1**: Official status, source, effective/expiry, confidence, stale state | `ConditionEntry` has severity+accuracyClass; `PinEntity` has source+confidence; no expiry DateTime; no stale DateTime | Add `expiryDate` to `PinEntity` and `ConditionEntry`; add `source` field to `ConditionEntry`; add `isStale` computed to both; display all 5 in UI |
| **AC2**: Expired exact pin never shown as current official | `PinEntity` has no expiry; no business logic to filter expired | Add `expiryDate`; add `PinPositionService` or repository method that filters expired pins; never route expired official pins to the display layer |
| **AC3**: Cached conditions offline with timestamp | `ConditionEntry` has `effectiveDate`; no offline caching behavior in conditions_section.dart | ConditionsSection must read from local SQLite/cache; show `cachedAt` timestamp; offline badge when network unavailable |

---

## 3. Anti-Shortcut Evidence

- **Do NOT** use stale weather data for pin display — pin has independent effective/expiry
- **Do NOT** display expired pins even if they are the latest in the database — expiry check is mandatory
- **Do NOT** fabricate confidence values — confidence must come from backend or be null
- **Do NOT** skip offline caching — MVP requires offline conditions access per PRD §10.3

---

## 4. Existing Code Reuse

| File | Role | Change Needed |
|------|------|--------------|
| `pin_entity.dart` | Domain entity for pin positions | Add `effectiveDate`, `expiryDate`, `isExpired` computed, extend `source` semantics |
| `condition_entry.dart` | Domain entity for conditions | Add `source`, `confidence`, `expiryDate`, `isExpired`; extend `ConditionType` |
| `data_freshness.dart` | Has `isStale` (>30d) but uses days count — needs `expiryDate` field for pin-specific expiry | Add `expiryDate: DateTime?` field; update `isStale` to check expiry first |
| `conditions_section.dart` | UI for conditions in CourseDetail | Extend to show source badge, confidence %, expiry, stale warning, offline badge |
| `pin_marker.dart` | UI for pin on hole map | Extend to show expiry/stale indicator; add semantic label for screen readers |

---

## 5. Implementation Slices

### Slice 1: Domain Layer — Pin and Condition Models

**Scope**: Extend domain entities with AC-required fields. No UI, no persistence.

**Files**:
- `apps/mobile/lib/domain/models/pin_entity.dart` — Add `effectiveDate`, `expiryDate`, `isExpired`, `isActive` computed
- `apps/mobile/lib/domain/models/condition_entry.dart` — Add `source`, `confidence`, `expiryDate`, `isExpired`
- `apps/mobile/lib/domain/models/data_freshness.dart` — Add `expiryDate` field

**Criteria**:
- All new fields are nullable with sensible defaults
- `isExpired` returns true when `expiryDate != null && DateTime.now().isAfter(expiryDate)`
- `PinEntity` with `isOfficial && isExpired` must NOT be treated as current official

### Slice 2: Infrastructure Layer — Repository/Persistence Contracts

**Scope**: Define repository interfaces for fetching official pin/conditions with expiry filtering. Persist to SQLite for offline use.

**Files** (new):
- `apps/mobile/lib/features/conditions/data/conditions_repository.dart` — interface with `getConditions()`, `getActivePin()`, `cacheConditions()`
- `apps/mobile/lib/features/conditions/data/conditions_local_datasource.dart` — SQLite persistence for offline

**Criteria**:
- Repository methods filter expired official data before returning
- `getActivePin()` returns only non-expired official pins
- `cacheConditions()` stores with `cachedAt` timestamp

### Slice 3: Presentation Layer — Conditions Screen Extension

**Scope**: Update ConditionsSection to show AC1 fields. Add stale warning and offline badge. Update PinMarker to show expiry state.

**Files**:
- `apps/mobile/lib/features/course_detail/presentation/widgets/conditions_section.dart` — Full AC1 display: official badge, source, effective/expiry, confidence, stale
- `apps/mobile/lib/features/hole_map/presentation/widgets/pin_marker.dart` — Add expiry/stale indicator; update semantic label

**Criteria**:
- All 5 AC1 elements visible: official status (badge), source, effective/expiry, confidence, stale state
- Stale warning shown when data is expired or >30 days old
- Offline badge when device is offline
- Screen reader semantics: all badges and states have semantic labels

### Slice 4: Offline Behavior — Conditions Cache

**Scope**: Wire conditions to use local-first with offline timestamp.

**Files**:
- `apps/mobile/lib/features/conditions/data/conditions_local_datasource.dart` — Implement
- Any repository that fetches conditions — must fall back to cache when offline

**Criteria**:
- Offline shows cached conditions with `cachedAt` timestamp
- Offline badge visible on conditions panel
- Expired cache still shown with stale warning (not hidden — user should know what's available)

### Slice 5: Verification and Tests

**Scope**: Unit tests for `isExpired`, repository filtering, and widget tests for conditions_section.

**Files** (new):
- `apps/mobile/test/domain/models/pin_entity_test.dart`
- `apps/mobile/test/domain/models/condition_entry_test.dart`
- `apps/mobile/test/features/conditions/conditions_section_test.dart`

---

## 6. Dependency Order

```
Story 7.1 (weather) → Story 7.2 (wind relative to shot line) → Story 7.3 (this)
                                                                  ↓
                                                         Slice 1 (domain models)
                                                                  ↓
                                                         Slice 2 (repository contracts)
                                                                  ↓
                                                         Slice 3 (UI extensions)
                                                                  ↓
                                                         Slice 4 (offline wiring)
                                                                  ↓
                                                         Slice 5 (tests)
```

**Note**: Story 7.2 is `backlog` (not yet implemented). Story 7.3 is blocked on 7.2's *output* which is the conditions surface and wind display pattern. Story 7.3 should proceed with its own slices in parallel with 7.2 or after 7.2's domain model is available.

---

## 7. Verification Gates Per AC

| AC | Verification |
|----|-------------|
| **AC1** | Manual: ConditionsSection shows all 5 elements; stale warning appears for >30d data; screen reader check |
| **AC2** | Unit test: `PinEntity` with `expiryDate = yesterday` returns `isExpired = true`; repository filter excludes expired official pins |
| **AC3** | Manual: Airplane mode → conditions still visible with "Cached" label + timestamp; compare timestamp with last sync time |

---

## 8. Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Story 7.2 not done — conditions surface not available | Build conditions_section as standalone widget first; integrate with 7.2's weather/conditions surface later |
| Backend doesn't send expiryDate for pins | Make field nullable; show "source only" when no expiry; treat missing expiry as "no expiration" |
| Offline caching requires new SQLite schema | Reuse existing `CoursePackageService` cache pattern from story 4.x |
| Stale definition differs between conditions and pins | Conditions: >30d stale from data_freshness; Pins: explicit expiryDate; show both mechanisms |

---

## 9. File Summary

| Action | File |
|--------|------|
| MODIFY | `apps/mobile/lib/domain/models/pin_entity.dart` |
| MODIFY | `apps/mobile/lib/domain/models/condition_entry.dart` |
| MODIFY | `apps/mobile/lib/domain/models/data_freshness.dart` |
| MODIFY | `apps/mobile/lib/features/course_detail/presentation/widgets/conditions_section.dart` |
| MODIFY | `apps/mobile/lib/features/hole_map/presentation/widgets/pin_marker.dart` |
| CREATE | `apps/mobile/lib/features/conditions/data/conditions_repository.dart` |
| CREATE | `apps/mobile/lib/features/conditions/data/conditions_local_datasource.dart` |
| CREATE | `apps/mobile/test/domain/models/pin_entity_test.dart` |
| CREATE | `apps/mobile/test/domain/models/condition_entry_test.dart` |
| CREATE | `apps/mobile/test/features/conditions/conditions_section_test.dart` |

---

## 10. Status Transitions

```
ready-for-dev → in-progress (after this plan)
in-progress → review (after all slices implemented + tests pass)
```
