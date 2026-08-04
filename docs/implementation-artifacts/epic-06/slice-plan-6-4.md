# Slice Plan: Story 6.4 — Calculate Green and Hazard Distances

## Evidence of Context Reading

| Document | Lines Read | Key Sections Used |
|---|---|---|
| `docs/planning-artifacts/prd.md` | 0–551 | FR8 (distances), NFR2 (1s update), NFR14 (geospatial), §8.7 (distance measurement) |
| `docs/planning-artifacts/architecture.md` | 0–390 | §9.1 (MapLibre), §7 (PostGIS/geometry), §14 (quality gate: front/center/back computable) |
| `docs/planning-artifacts/ux-spec.md` | 0–492 | §6.1 (primary distance panel), §6.3 (hazard UX), §10 (accessibility) |
| `docs/implementation-artifacts/epic-06/6-4-calculate-green-and-hazard-distances.md` | 0–58 | Story ACs, tasks, dependencies |
| `docs/implementation-artifacts/epic-03/3-1-model-course-and-golf-geometry.md` | 0–57 | PostGIS geometry schema (green, bunker, water, OB) |
| `packages/contracts/schemas/course.yaml` | 0–1169 | `CoursePackageManifest` with `geoJsonUrl`, `dataVersion` |
| `docs/vnpt-flow/epic-run-run_2026_08_02_010/story-status-list.md` | 0–154 | Epic-06 story statuses: 6.1–6.6 all `ready-for-dev` |
| `apps/mobile/lib/data/services/nearby_course_service.dart` | — | Existing Haversine `calculateDistanceKm` as precedent |
| `apps/mobile/lib/features/profile/data/profile_dto.dart` | — | `DistanceUnit` enum precedent |

## Anti-Shortcut Evidence

- Story 6.3 (Render Strategic Hole Map) is also `ready-for-dev` — **no map rendering code exists yet** in the mobile app for hole geometry display. Distance panel is **not blocked** on map rendering; it is its own independent slice.
- No `HoleGeometry`, `GreenGeometry`, `HazardGeometry` domain models exist — must be created.
- No `DistanceCalculator` service exists — must be created.
- No active-round screen exists (only `round_setup_screen.dart` with `TODO: Navigate to ActiveRoundScreen` comment) — UI components must be created.
- The `geoJsonUrl` from `CoursePackageManifest` provides raw GeoJSON; parsing to domain model is an explicit task.
- `HaversineService.calculateDistanceKm` in `nearby_course_service.dart` is straight-line — green front/center/back requires **perpendicular distance to polygon edge**, not simple point-to-point.

## Story Scope Confirmation

### From PRD §8.7 (Distance Measurement)
- Front/center/back green distances — perpendicular distances to green polygon boundary
- Bunker/water **near/far** (two closest/farthest points on hazard polygon from golfer)
- **Carry** values (through a hazard to green)
- OB, dogleg, lay-up, selected target distances
- Each measurement: actual distance + optional elevation flag + GPS accuracy + timestamp + source + confidence

### From Epic 6 AC (Story 6.4)
- Local calculations produce green front/center/back, bunker/water near/far, and carry values in selected unit
- Values update within **1 second after location update**
- UI shows GPS accuracy, source, timestamp, confidence — no fabricated precision

### From Architecture §14 (Quality Gate #2)
- "Front/center/back and hazard distances can be computed from local data" — **already a quality gate**; this story delivers it

### From UX Spec §6.1
- Primary distance panel: front/center/back green always visible
- GPS accuracy state visible
- Unit: meters/yards
- Stale/low-accuracy → warning state, not hidden distances

### Dependencies
- **Story 6.1** (Acquire and Qualify Location): provides GPS position stream with accuracy/timestamp
- **Story 6.3** (Render Strategic Hole Map): provides hole geometry (from package GeoJSON)
- **Story 6.5** (Place and Move a Target): provides target position — distance panel shows ball-to-target after that
- **Story 3.1** (done): PostGIS geometry schema — green, bunker, water, OB polygon models already designed in backend schema

## Domain Models to Create/Extend

### Value Objects (new)
```
lib/domain/value_objects/distance_measurement.dart
  - DistanceMeasurement: value (double meters), unit (DistanceUnit), type (DistanceType),
    source (official/estimated), timestamp, gpsAccuracy, confidence (0–1)

lib/domain/value_objects/distance_type.dart
  - DistanceType enum: frontGreen, centerGreen, backGreen, pin,
    bunkerNear, bunkerFar, bunkerCarry,
    waterNear, waterFar, waterCarry,
    ob, dogleg, layup, target, targetToPin
```

### Domain Models (new)
```
lib/domain/models/hole_geometry.dart
  - HoleGeometry: holeNumber, par, greenPolygon (List<LatLng>),
    pinPosition (LatLng), hazards (List<HazardGeometry>),
    teeBox (LatLng), fairwayCenterline (List<LatLng>),
    cartPaths (List<List<LatLng>>), obAreas (List<List<LatLng>>),
    landmarks (List<LandmarkGeometry>),
    dataQuality: DataQuality

lib/domain/models/hazard_geometry.dart
  - HazardGeometry: id, type (bunker|water|penalty|ob), name,
    polygon (List<LatLng>), nearestPoint, farthestPoint, dataQuality

lib/domain/models/landmark_geometry.dart
  - LandmarkGeometry: id, name, type, position (LatLng), dataQuality
```

## Service Layer

### DistanceCalculator (new)
```
lib/domain/services/distance_calculator.dart
  - Calculates all distances from golfer position to green, hazards, pins
  - Uses geodesic (Haversine approximation acceptable for <1km golf distances)
  - Front green: minimum perpendicular distance to green polygon edge
  - Center green: minimum straight-line distance to green polygon
  - Back green: maximum straight-line distance to green polygon
  - Hazard near: minimum straight-line distance to hazard polygon
  - Hazard far: maximum straight-line distance to hazard polygon
  - Hazard carry: distance from golfer through hazard to first green boundary intersection
  - OB: minimum distance to OB line/polygon
  - Converts meters → yards when DistanceUnit.yards selected
  - Attaches: source (official/estimated), timestamp, GPS accuracy, confidence
```

## State Management

### DistanceState (new)
```
lib/application/distance/distance_state.dart
  - DistanceState: golferPosition, gpsAccuracy, timestamp,
    greenDistances (front/center/back), hazardDistances (by hazardId),
    pinDistance, targetDistance (null if no target),
    selectedUnit, confidence, loading, error

lib/application/distance/distance_cubit.dart
  - Listens to location stream from story 6.1
  - On each location update: recalculate all distances
  - On target placed (story 6.5): add target distance
  - Emits updated state within 1s of location update
```

## UI Components

```
lib/presentation/widgets/distance/primary_distance_panel.dart
  - Shows front/center/back green distances prominently (large typography)
  - GPS accuracy chip (green/amber/red)
  - Unit toggle (m/yd)
  - Confidence indicator (text + color, not color-only)

lib/presentation/widgets/distance/hazard_distance_list.dart
  - Grouped hazard rows: icon, name, near distance, far/carry distance
  - Hazard type icon (bunker/water/OB)
  - Scrollable if many hazards
  - Accessible: each row has semantic label

lib/presentation/widgets/distance/gps_accuracy_chip.dart
  - Displays GPS accuracy with color: <5m green, 5–10m amber, >10m red
  - Includes accuracy value in text label

lib/presentation/widgets/distance/distance_value_display.dart
  - Reusable large numeric display for a single distance
  - Accessibility: Semantics label, supports large text

lib/presentation/widgets/distance/distance_panel_accessible.dart
  - Wraps primary_distance_panel with full accessibility:
    Semantics labels, excludeFromSemantics: false,
    supportsScreenReader: true
```

## Integration Points

- **LocationProvider**: to be provided by Story 6.1 — interface `LocationStreamProvider` subscribing to GPS position
- **HoleGeometryProvider**: reads parsed hole geometry from local package (from Story 6.3 output)
- **TargetProvider**: optional target position from Story 6.5 — when target is set, panel shows ball-to-target + target-to-pin
- **DistanceUnitPreference**: read from golfer profile (already in `profile_dto.dart` as `DistanceUnit`)

## Slice Wave Plan

### Wave 1: Domain & Calculation (independent, no UI)
1. Create `DistanceType` enum
2. Create `DistanceMeasurement` value object
3. Create `HazardGeometry`, `LandmarkGeometry`, `HoleGeometry` models
4. Create `DistanceCalculator` service with all calculation methods
5. Unit tests for `DistanceCalculator`: green front/center/back, hazard near/far/carry, unit conversion

### Wave 2: State Management
6. Create `DistanceState` and `DistanceCubit`
7. Integration test: mock location + geometry → verify distance output

### Wave 3: UI Components
8. Create `gps_accuracy_chip.dart`
9. Create `distance_value_display.dart`
10. Create `primary_distance_panel.dart`
11. Create `hazard_distance_list.dart`
12. Accessibility verification: screen reader labels, large text, reduced motion

### Wave 4: Integration
13. Wire `DistanceCubit` to location stream (interface from 6.1)
14. Add unit conversion toggle wiring
15. Create `active_round_distances_screen.dart` shell (for later screen integration)
16. Run full test suite + format + lint

## Files to Create

```
apps/mobile/lib/domain/value_objects/distance_measurement.dart
apps/mobile/lib/domain/value_objects/distance_type.dart
apps/mobile/lib/domain/models/hole_geometry.dart
apps/mobile/lib/domain/models/hazard_geometry.dart
apps/mobile/lib/domain/models/landmark_geometry.dart
apps/mobile/lib/domain/services/distance_calculator.dart
apps/mobile/lib/application/distance/distance_state.dart
apps/mobile/lib/application/distance/distance_cubit.dart
apps/mobile/lib/presentation/widgets/distance/gps_accuracy_chip.dart
apps/mobile/lib/presentation/widgets/distance/distance_value_display.dart
apps/mobile/lib/presentation/widgets/distance/primary_distance_panel.dart
apps/mobile/lib/presentation/widgets/distance/hazard_distance_list.dart
apps/mobile/test/domain/services/distance_calculator_test.dart
apps/mobile/test/application/distance/distance_cubit_test.dart
```

## Acceptance Criteria Mapping

| AC | Implementation |
|---|---|
| Local calc → green F/C/B | `DistanceCalculator.calculateGreenDistances()` using polygon edge distances |
| Bunker/water near/far/carry | `DistanceCalculator.calculateHazardDistances()` using polygon min/max + carry intersection |
| Selected unit | `DistanceUnit` from `profile_dto.dart`, applied at display layer via `DistanceMeasurement.toDisplayUnit()` |
| Update within 1s of location | `DistanceCubit` recalculates synchronously on stream emit; no debounce |
| GPS accuracy shown | `GpsAccuracyChip` reads `gpsAccuracy` from `DistanceState` |
| Source shown | `DistanceMeasurement.source` displayed as badge (official/estimated) |
| Timestamp shown | `DistanceMeasurement.timestamp` displayed as relative time |
| Confidence shown | `DistanceMeasurement.confidence` displayed as text + color |
| No fabricated precision | Accuracy >10m → amber/red warning; no precision claim beyond GPS error margin |
| Accessibility | All widgets use `Semantics`, non-color-only indicators, 44pt touch targets, large text support |

## Constraints

- **Flutter only** — no backend changes needed
- **Offline-first** — all calculation is local; no network calls in distance calculation path
- **Geodesic precision** — Haversine acceptable for golf distances (<1km range, <0.3% error)
- **No AI/smartwatch/deferred scope**
- **Map rendering not required** — distance panel is a standalone widget (6.3 renders map; 6.4 provides data)
- **Story 6.5 (target)** is an extension, not a dependency — panel renders target distance only when available
