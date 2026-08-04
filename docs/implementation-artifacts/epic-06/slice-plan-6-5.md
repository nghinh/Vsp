# Slice Plan: Story 6.5 — Place and Move a Target

## Story Summary
- **Story**: 6.5 — Place and Move a Target
- **Epic**: 6 — Location Acquisition
- **Status**: `ready-for-dev` → `in-progress`
- **Epic Run Folder**: `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

---

## Context Reconciliation

### Story File vs Sprint Status Discrepancy
| Source | Status |
|--------|--------|
| `6-5-place-and-move-a-target.md` | `ready-for-dev` |
| `sprint-status.yaml` | `backlog` |

**Resolution**: Story file is authoritative. Sprint status will be updated to `in-progress`.

### Dependency Status (Critical Blocker)
| Story | Title | Status | Implication for 6.5 |
|-------|-------|--------|---------------------|
| 6.1 | Acquire and Qualify Location | `backlog` | Provides GPS; needed for ball position |
| 6.2 | Detect Course and Hole | `backlog` | Provides current hole context |
| 6.3 | Render Strategic Hole Map | `ready-for-dev` | MapLibre view; no target layer yet |
| **6.4** | **Calculate Green and Hazard Distances** | **`ready-for-dev`** | **Pin position + distance calc output; DIRECT dependency** |
| 6.5 | Place and Move a Target | `ready-for-dev` | **This story** |

**Dependency Chain**: 6.4 must complete before 6.5 can build target-to-pin distance.  
**Parallelization**: 6.3 and 6.4 can proceed independently of each other; 6.5 waits on 6.4.

---

## Slice Definition

Story 6.5 has **3 acceptance criteria** that map to **3 slices**:

### Slice 1: Tap-to-Place Target
**AC**: "Tap places a target and displays ball-to-target and target-to-pin distance."

Scope:
- `TargetModel` domain entity (SRID 4326 point, confidence, source, timestamp)
- `TargetRepository` interface (local persistence)
- `TargetLocalStore` (SQLite, follows `RoundSyncStore` pattern, `vsp_target.db`)
- `TargetCubit` / `TargetState` (places target, emits distances)
- `TargetAnnotation` for MapLibre (circle + label symbol layer)
- `HoleMapScreen` integration: `onMapTap` callback places target annotation
- `TargetCard` widget: shows ball-to-target and target-to-pin in selected unit (m/yd)
- Distance calc: uses `ST_Distance` geography with SRID 4326 → meters → convert to unit
- Uses **existing** ball position from 6.1 (stubbed until 6.1 lands) and **existing** pin position from 6.4

File changes:
```
apps/mobile/lib/features/target/
  domain/target_model.dart          [NEW]
  domain/target_repository.dart     [NEW - interface]
  data/target_local_store.dart      [NEW - SQLite persistence]
  data/target_repository_impl.dart  [NEW]
  presentation/target_cubit.dart    [NEW]
  presentation/target_state.dart    [NEW]
  presentation/target_card.dart     [NEW - distance display widget]
  presentation/hole_map_screen_integration.dart [MODIFY - add target layer + tap handler]

packages/mobile-theme/lib/tokens/   [CHECK - ensure target pin icon token exists]

Test:
apps/mobile/test/features/target/
  target_model_test.dart
  target_cubit_test.dart
  target_local_store_test.dart
```

### Slice 2: Drag Target Without Pan/Zoom Conflict
**AC**: "Drag behavior, if enabled, does not conflict with map pan/zoom."

Scope:
- `TargetDragMode`: enum `{none, dragging}`
- `AnnotationDragStart` / `AnnotationDragEnd` / `AnnotationDrag` events on MapLibre
- UX decision: drag initiated via **long-press** (300ms) to distinguish from pan/zoom
- While `TargetDragMode.dragging`: `MapLibreOptions(interactability: false)` or suppress pan/zoom gestures via `GestureSettings`
- On drag end: update `TargetModel.position`, recalculate distances, persist to SQLite

Verification:
- Dragging target moves annotation without panning map
- Releasing drag exits `TargetDragMode.dragging`, restores normal map gestures
- No interference with two-finger pinch-zoom or pan gestures

**Note**: If UX review at implementation time finds long-press-drag confusing, alternative is a dedicated "Edit Target" mode toggle button. Long-press is preferred per Google Maps precedent.

### Slice 3: Offline Target Persistence
**AC**: "Target remains visible and usable offline."

Scope:
- `TargetLocalStore` persists to SQLite: position, created_at, updated_at
- On round resume: load target from `TargetLocalStore` by round_id + hole_number
- Target survives app restart, round pause/resume
- No server sync required for MVP (target is ephemeral per-hole, not shared)
- If sync needed later: `TargetSyncOperation` added to `RoundSyncStore` event queue

Verification:
- Place target → kill app → relaunch → target restored at same position
- Place target → switch hole → switch back → target on previous hole restored
- Works with airplane mode from placement through retrieval

---

## Distance Calculation Contract

Since 6.4 provides `PinPosition` and distance calculation service, 6.5 consumes:

```dart
// 6.4 output (consumed by 6.5):
class GreenDistanceResult {
  final double distanceMeters;
  final GpsAccuracy accuracy;
  final String source;        // "official" | "estimated"
  final DateTime timestamp;
  final PinPosition pin;
}

// 6.5 needs:
class TargetDistances {
  final double ballToTargetMeters;
  final double targetToPinMeters;
  final DistanceUnit unit;    // meters | yards
  final GpsAccuracy accuracy;
  final DateTime timestamp;
}
```

**Calculation**:
- Ball-to-target: `ST_Distance(ball_point::geography, target_point::geography)` → meters → convert
- Target-to-pin: `ST_Distance(target_point::geography, pin_point::geography)` → meters → convert
- Conversion: `yards = meters * 1.09361`

---

## Cross-Cutting Concerns

| Concern | Implementation |
|---------|---------------|
| **Offline** | SQLite local store, no server dependency for target placement |
| **Accessibility** | Screen reader labels on target card; non-color-only distance display |
| **Confidence** | Propagate GPS accuracy from ball position to target distances |
| **Units** | Respect user's distance unit preference (m/yd) |
| **UX** | Fira Code for distances; primary orange for target pin; 44pt touch targets |
| **Performance** | Distance calc <50ms; annotation update <16ms (60fps) |

---

## Verification Plan

| AC | Verification Method |
|----|---------------------|
| Tap places target + shows distances | Unit test: `TargetCubit.placeTarget()` emits `TargetState` with correct distances |
| Drag doesn't conflict with pan/zoom | Widget test: long-press drag moves annotation, map stays centered |
| Target offline | Integration test: place → kill → relaunch → target restored |

---

## Technical Decisions

1. **Drag vs tap**: Long-press (300ms) initiates drag to clearly distinguish from map pan/zoom. Follows Google Maps / Apple Maps marker drag precedent.
2. **No server sync in MVP**: Target is per-hole, per-device. No multi-device sync requirement in PRD.
3. **Separate SQLite store**: `vsp_target.db` (not reusing `vsp_round.db`) to keep target lifecycle independent.
4. **Stub ball position**: Until 6.1 lands, `ball_position` parameter is stubbed with a fixed offset from pin. Tests use a fixture.
5. **Stub pin position**: Until 6.4 lands, `pin_position` is stubbed from course package manifest fixture.

---

## Implementation Order

1. **First**: Slice 1 (domain model, local store, cubit, map integration, distance display)
2. **Second**: Slice 2 (drag mode, long-press gesture handling)
3. **Third**: Slice 3 (offline persistence verification)

---

## Evidence

- PRD §8.8: Target interaction requirements
- Architecture §8: Mobile layers, local storage, offline-first
- UX Spec §6.2: Map interaction (tap to place, drag if enabled, target card)
- Mockup DESIGN.md: Target pin icon, distance panel Fira Code styling, primary orange color
- Existing patterns: `RoundSyncStore` (SQLite pattern), `ActiveRoundGuard` (sealed results), `ScoreEntry` (domain model)
- Sprint status: 6.4 `ready-for-dev`, 6.5 `ready-for-dev` — proceed in parallel with 6.4
