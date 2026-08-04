# Slice Plan — Story 6.3: Render Strategic Hole Map

**Epic:** 6 — Location Acquisition
**Story:** 6.3
**Planner:** vnpt-epic-story-runner
**Date:** 2026-08-02
**Status:** `in-progress`

---

## 1. Context Summary

### Story ACs
1. **AC1**: MapLibre renders required course layers, pin, golfer, target, wind, and rings from local package data.
2. **AC2**: High-contrast style remains readable in sunlight and supports safe areas and large text.
3. **AC3**: Cached hole map loads in under 2 seconds on target devices.

### Dependency Analysis
| Story | Title | Status | Dependency Relationship |
|-------|-------|--------|------------------------|
| 6.2 | Detect Course and Hole | backlog | Provides golfer position + detected hole → hole map needs this to center on current hole |
| 3.1 | Model Course and Golf Geometry | backlog | Provides PostGIS schema + GeoJSON geometry for tee, fairway, rough, green, bunker, water, OB, cart path, landmarks |

### Gap Analysis
- `maplibre_gl` package **not yet in** `pubspec.yaml`
- `packages/map-style/style.json` is an **empty shell** (no sources, no layers)
- `packages/course-package/` has manifest schema but **no Dart package** for local package access
- **No hole map screen** exists in `apps/mobile/lib/features/round/`
- No `hole_map` feature directory under round or a dedicated `hole_map` feature

### Assumptions
- Stories 6.2 and 3.1 will be implemented before full end-to-end hole map data flow is complete
- Slice 1 (MapLibre + style foundation) can proceed independently
- Full AC satisfaction requires 6.2 + 3.1 outputs; slice 1-5 are enabling infrastructure

---

## 2. Slice Plan

### Slice 1: MapLibre Infrastructure + Style Foundation
**Scope**: Add MapLibre Flutter package, create hole_map feature structure, wire MapLibre into app, create high-contrast outdoor style JSON with golf layer definitions (fill/line/circle/symbol).

**Files**:
- `apps/mobile/pubspec.yaml` — add `maplibre_gl: ^0.18.0` (or latest stable)
- `packages/map-style/style.json` — replace shell with full high-contrast golf style: sources (vector tile URL or GeoJSON placeholder), fill layers (fairway, rough, green, bunker, water, OB), line layers (cart path, hazard boundaries), circle layers (pin, golfer position), symbol layers (landmarks, tee boxes), distance ring line layer, wind arrow symbol layer, glyphs/sprite pointing to bundled or CDN assets
- `apps/mobile/lib/features/hole_map/hole_map.dart` — feature barrel export
- `apps/mobile/lib/features/hole_map/presentation/hole_map_screen.dart` — scaffold MapLibre widget, DarkModeClause wrapper, SafeArea, high-contrast theme
- `apps/mobile/lib/features/hole_map/presentation/hole_map_bloc.dart` — BLoC with states: HoleMapInitial, HoleMapLoading, HoleMapReady, HoleMapError; events: LoadHoleMap, UpdateGolferPosition, UpdateTarget
- `apps/mobile/lib/features/hole_map/presentation/hole_map_state.dart` — state classes
- `apps/mobile/lib/features/hole_map/presentation/hole_map_event.dart` — event classes

**AC Addressed**: AC2 (high-contrast + safe area), partial AC1 (style foundation)

---

### Slice 2: Course Geometry Data Layer (Local Package Access)
**Scope**: Create `packages/course-package/` as a Dart package with manifest schema, create `CoursePackageRepository` in mobile app that reads local course geometry from downloaded package files (SQLite or JSON files on disk).

**Files**:
- `packages/course-package/lib/course_package.dart` — package barrel
- `packages/course-package/lib/src/manifest.dart` — `CoursePackageManifest` model (version, checksum, holes list)
- `packages/course-package/lib/src/hole_geometry.dart` — `HoleGeometry` model with GeoJSON FeatureCollection for each hole's layers (tee, fairway, rough, green, bunker, water, penalty area, OB, cart path, landmark)
- `packages/course-package/lib/src/course_package_repository.dart` — `CoursePackageRepository` interface + `LocalCoursePackageRepository` implementation reading from app documents directory
- `apps/mobile/lib/features/hole_map/data/hole_geometry_dto.dart` — DTOs for hole geometry from local package
- `apps/mobile/lib/features/hole_map/data/hole_map_repository.dart` — repository wrapping `LocalCoursePackageRepository`

**AC Addressed**: AC1 (data source), AC3 (local package → fast load)

---

### Slice 3: Hole Map Domain Models
**Scope**: Create domain entities for hole map rendering: `HoleMapEntity`, `MapLayerEntity`, `PinEntity`, `TargetEntity`, `WindEntity`, `GolferPositionEntity`.

**Files**:
- `apps/mobile/lib/features/hole_map/domain/hole_map_entity.dart` — aggregate root
- `apps/mobile/lib/features/hole_map/domain/map_layer.dart` — layer type enum (fairway, rough, green, bunker, water, penalty_area, ob, cart_path, landmark, pin, golfer, target, wind, distance_ring), layer geometry, style properties
- `apps/mobile/lib/features/hole_map/domain/pin_entity.dart` — position, confidence, source
- `apps/mobile/lib/features/hole_map/domain/target_entity.dart` — user-placed target position
- `apps/mobile/lib/features/hole_map/domain/wind_entity.dart` — direction, speed, source, timestamp
- `apps/mobile/lib/features/hole_map/domain/golfer_position_entity.dart` — lat/lng, accuracy, timestamp, confidence
- `apps/mobile/lib/features/hole_map/domain/distance_ring_entity.dart` — center, radius, label

**AC Addressed**: AC1 (domain models for all rendered entities)

---

### Slice 4: Hole Map Presentation — Map Widget + Overlays
**Scope**: Build the actual map UI with MapLibre widget, distance rings, golfer position marker, pin marker, wind arrow overlay, target marker, layer visibility toggles.

**Files**:
- `apps/mobile/lib/features/hole_map/presentation/widgets/hole_map_view.dart` — main MapLibre map view widget
- `apps/mobile/lib/features/hole_map/presentation/widgets/golfer_position_marker.dart` — animated GPS dot with accuracy circle
- `apps/mobile/lib/features/hole_map/presentation/widgets/pin_marker.dart` — pin flag marker with official/estimated badge
- `apps/mobile/lib/features/hole_map/presentation/widgets/target_marker.dart` — draggable target marker
- `apps/mobile/lib/features/hole_map/presentation/widgets/wind_arrow_overlay.dart` — wind direction arrow with speed label
- `apps/mobile/lib/features/hole_map/presentation/widgets/distance_ring_overlay.dart` — concentric distance rings (100m, 150m, 200m)
- `apps/mobile/lib/features/hole_map/presentation/widgets/layer_toggle_panel.dart` — collapsible panel to toggle layer visibility
- `apps/mobile/lib/features/hole_map/presentation/widgets/map_loading_skeleton.dart` — skeleton UI while map loads
- `apps/mobile/lib/features/hole_map/presentation/widgets/map_error_view.dart` — error state with retry

**AC Addressed**: AC1 (all overlays), AC2 (high-contrast markers, safe area)

---

### Slice 5: Performance + Accessibility
**Scope**: Performance optimization for <2s load, accessibility for screen readers, large text support, reduced motion.

**Files**:
- `apps/mobile/lib/features/hole_map/hole_map.dart` — add `Semantics` labels to markers and controls
- `apps/mobile/lib/features/hole_map/presentation/widgets/hole_map_view.dart` — optimize: pre-load visible tiles, use `RepaintBoundary`, cache layer paint objects
- Add `accessibility_hints.md` under hole_map feature (e.g., "Double tap to place target", "Pinch to zoom")
- Add performance notes to BLoC: pre-load hole geometry on round start, cache parsed GeoJSON

**AC Addressed**: AC2 (accessibility), AC3 (performance <2s)

---

### Slice 6: Integration + Story 6.2/3.1 Hookup
**Scope**: Connect hole map to round state, wire in golfer position from GPS (story 6.1) and hole detection from story 6.2, wire in course geometry from story 3.1, add to round navigation.

**Files**:
- `apps/mobile/lib/features/round/presentation/round_screen.dart` — add Map tab alongside Score/Target/Conditions tabs during active round (per UX spec bottom nav)
- `apps/mobile/lib/features/hole_map/hole_map.dart` — export `HoleMapScreen` as routable page
- Update `apps/mobile/lib/features/hole_map/presentation/hole_map_bloc.dart` — add `HoleDetected` event + state transition from story 6.2 output
- Add test stubs for full integration tests (integration with 6.2 and 3.1 — marked pending until dependencies ship)

**AC Addressed**: All ACs — end-to-end from local package data through hole detection

---

## 3. Wave Mapping

| Wave | Slices | Blocking | Notes |
|------|--------|----------|-------|
| Wave 1 | Slices 1, 2, 3 | No | Infrastructure + data + domain — can be built without 6.2/3.1 |
| Wave 2 | Slices 4, 5 | Yes (needs 1,2,3) | Presentation widgets built on top of data layer |
| Wave 3 | Slice 6 | Yes (needs 6.2, 3.1) | Integration — requires dependency stories to complete |

**Independent work**: Wave 1 is unblocked and can proceed now. Slices 1-3 do not depend on 6.2 or 3.1 since they build the infrastructure, data access pattern, and domain models.

---

## 4. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Map package | `maplibre_gl: ^0.18.0` | Latest stable, supports vector layers, offline regions |
| State management | `flutter_bloc` (existing pattern) | Consistent with codebase |
| Local geometry storage | JSON/GeoJSON files in app documents | No SQLite schema change needed for MVP geometry |
| Style format | MapLibre GL JSON style | Standard, supports runtime updates |
| Layer types | Fill + Line + Circle + Symbol | Covers all golf geometry + markers |
| Distance rings | Line layers with circle geometry | Per architecture §9.1 |
| High-contrast | Dark base (`#0F172A`) + vivid accent | Per UX tokens, sunlight-readable |
| Performance | `RepaintBoundary` + pre-load | Per PRD §10.2 performance target |
| Accessibility | `Semantics` on all markers | Per UX spec §10 + accessibility AC |

---

## 5. Verification Plan

| AC | Verification Method |
|----|---------------------|
| AC1 (renders all layers) | Unit test: verify all 10+ layer types can be added to style; Widget test: render map and assert layers present |
| AC1 (from local package) | Unit test: `CoursePackageRepository` loads geometry from mock JSON fixture |
| AC2 (high-contrast) | Visual review checklist: dark background, accent primary `#EA580C`, text >4.5:1 contrast |
| AC2 (safe areas) | Widget test: render in bounding box, assert no overflow in safe area |
| AC2 (large text) | Unit test: font sizes match UX spec |
| AC3 (<2s load) | Performance test: load cached hole map, measure `stopwatch.elapsed` < 2000ms |

---

## 6. File List (Relative to Repo Root)

```
apps/mobile/pubspec.yaml
packages/map-style/style.json
packages/course-package/lib/course_package.dart
packages/course-package/lib/src/manifest.dart
packages/course-package/lib/src/hole_geometry.dart
packages/course-package/lib/src/course_package_repository.dart
apps/mobile/lib/features/hole_map/hole_map.dart
apps/mobile/lib/features/hole_map/data/hole_geometry_dto.dart
apps/mobile/lib/features/hole_map/data/hole_map_repository.dart
apps/mobile/lib/features/hole_map/domain/hole_map_entity.dart
apps/mobile/lib/features/hole_map/domain/map_layer.dart
apps/mobile/lib/features/hole_map/domain/pin_entity.dart
apps/mobile/lib/features/hole_map/domain/target_entity.dart
apps/mobile/lib/features/hole_map/domain/wind_entity.dart
apps/mobile/lib/features/hole_map/domain/golfer_position_entity.dart
apps/mobile/lib/features/hole_map/domain/distance_ring_entity.dart
apps/mobile/lib/features/hole_map/presentation/hole_map_screen.dart
apps/mobile/lib/features/hole_map/presentation/hole_map_bloc.dart
apps/mobile/lib/features/hole_map/presentation/hole_map_state.dart
apps/mobile/lib/features/hole_map/presentation/hole_map_event.dart
apps/mobile/lib/features/hole_map/presentation/widgets/hole_map_view.dart
apps/mobile/lib/features/hole_map/presentation/widgets/golfer_position_marker.dart
apps/mobile/lib/features/hole_map/presentation/widgets/pin_marker.dart
apps/mobile/lib/features/hole_map/presentation/widgets/target_marker.dart
apps/mobile/lib/features/hole_map/presentation/widgets/wind_arrow_overlay.dart
apps/mobile/lib/features/hole_map/presentation/widgets/distance_ring_overlay.dart
apps/mobile/lib/features/hole_map/presentation/widgets/layer_toggle_panel.dart
apps/mobile/lib/features/hole_map/presentation/widgets/map_loading_skeleton.dart
apps/mobile/lib/features/hole_map/presentation/widgets/map_error_view.dart
apps/mobile/lib/features/hole_map/presentation/widgets/accessibility_hints.dart
```

---

## 7. Open Risks

1. **6.2/3.1 timing**: Wave 3 blocked until 6.2 and 3.1 ship. Recommend parallelizing 6.2 and 3.1 execution.
2. **MapLibre offline**: Need to verify `maplibre_gl` offline region API is stable for course package tile loading.
3. **Course package format**: No Dart course-package reader exists yet. Slice 2 creates one — this is a new package.
4. **Performance measurement**: <2s target needs real device testing; emulator numbers are unreliable.

---

## 8. Planning Evidence

- Read: `docs/implementation-artifacts/epic-06/6-3-render-strategic-hole-map.md`
- Read: `docs/planning-artifacts/prd.md` (sections 8.6 Hole Map, 10.2 Performance, 10.7 Accessibility)
- Read: `docs/planning-artifacts/architecture.md` (sections 8 Mobile Architecture, 9 Map Architecture)
- Read: `docs/planning-artifacts/ux-spec.md` (sections 5.2, 6.2, 10 Accessibility, 12 Performance)
- Read: `docs/implementation-artifacts/epic-03/3-1-model-course-and-golf-geometry.md`
- Read: `docs/implementation-artifacts/epic-06/6-2-detect-course-and-hole.md`
- Read: `docs/implementation-artifacts/sprint-status.yaml` (story 6.3 status: backlog, dependency 6.2: backlog, 3.1: backlog)
- Surveyed: `apps/mobile/lib/features/` (existing feature structure, BLoC pattern)
- Surveyed: `packages/map-style/style.json` (shell only)
- Surveyed: `packages/course-package/` (manifest schema only, no Dart impl)
- Surveyed: `apps/mobile/pubspec.yaml` (maplibre_gl not yet added)
