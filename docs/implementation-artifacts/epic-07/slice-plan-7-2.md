# Slice Plan — Story 7.2: Display Wind Relative to Shot Line

## Story Context

- **Epic**: 7 (Weather Intelligence)
- **Story**: 7.2 — Display Wind Relative to Shot Line
- **Status**: `ready-for-dev`
- **Phase**: MVP 1
- **Dependencies**: Story 7.1 (Integrate and Cache Weather) — must provide WindEntity with direction/speed data

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | App derives headwind, tailwind, and left/right crosswind from shot line | Unit test + integration test |
| AC2 | Missing or stale wind does not generate false precision | Stale-wind path returns null components with confidence=0 |
| AC3 | Wind indicator remains accessible without relying on arrow color alone | Semantics label + text labels on all wind components |

## Existing Artifacts

| Artifact | Path | Notes |
|----------|------|-------|
| WindEntity | `apps/mobile/lib/features/hole_map/domain/wind_entity.dart` | Has direction, speed, source, timestamp, unit |
| WindArrowOverlay | `apps/mobile/lib/features/hole_map/presentation/widgets/wind_arrow_overlay.dart` | Shows wind direction + speed; needs relative-wind enhancement |
| HoleMapEntity | `apps/mobile/lib/features/hole_map/domain/hole_map_entity.dart` | Holds wind, golfer position, target, pin |
| Weather contract | `packages/contracts/schemas/weather.yaml` | WindData schema with speed, direction, degrees, gusts |

## Slice Architecture

### Slice 1 — Wind-Relative Calculation Engine (Domain)

**New file**: `apps/mobile/lib/features/hole_map/domain/wind_relative_entity.dart`

```dart
// WindRelativeEntity — holds headwind/tailwind/crosswind derived from shot line
class WindRelativeEntity extends Equatable {
  final double? headwind;      // km/h into face (< 0 = tailwind)
  final double? tailwind;      // km/h at back (< 0 = into-face)
  final double? crosswindLeft;  // km/h from left
  final double? crosswindRight; // km/h from right
  final WindSource source;
  final DateTime timestamp;
  final bool isStale;
  final double? confidence;     // 0 when stale

  // componentLabel: 'headwind' | 'tailwind' | 'crosswind-left' | 'crosswind-right' | null
  // componentDirection: for crosswind labeling (e.g., "from left" vs "from right")
}
```

**New file**: `apps/mobile/lib/features/hole_map/domain/services/wind_relative_calculator.dart`

```dart
// WindRelativeCalculator — derives head/tail/crosswind from WindEntity + shot line
class WindRelativeCalculator {
  // WindEntity (direction in degrees, speed in km/h) + shot line bearing
  // Returns WindRelativeEntity with components or nulls if stale/missing
  WindRelativeEntity? calculate({
    required WindEntity wind,
    required double shotLineBearingDegrees, // 0-360, 0=North
    Duration? maxAge,
  });

  double _angleDiff(double windDir, double shotLine); // handles wrap-around
}
```

**Test file**: `apps/mobile/test/features/hole_map/domain/wind_relative_calculator_test.dart`

---

### Slice 2 — Wind Arrow Overlay Enhancement (Presentation)

**Modified file**: `apps/mobile/lib/features/hole_map/presentation/widgets/wind_arrow_overlay.dart`

Changes:
- Accept `WindRelativeEntity?` (optional, falls back to current behavior)
- Show headwind/tailwind component as text label below arrow
- Show crosswind as secondary label: "← Crosswind 5 km/h" or "Crosswind 5 km/h →"
- Color is NOT the only indicator — text labels always visible
- Full `Semantics` label: "Wind 15 km/h from SE, 8 km/h headwind, crosswind from left 3 km/h"
- Stale wind shows "Wind data stale" with no fabricated precision

---

### Slice 3 — Hole Map Integration (Application)

**Modified**: BLoC/Cubit that manages `HoleMapEntity` — ensure wind relative is computed when:
- Golfer position updates
- Target is placed/moved
- Wind data refreshes
- Pin position changes (shot line to pin fallback)

Shot line bearing calculation:
```
shotLineBearing = bearing(golferPosition, target ?? pin)
```

---

### Slice 4 — Stale Wind Guard (Domain + Presentation)

**New file**: `apps/mobile/lib/features/hole_map/domain/services/wind_staleness_guard.dart`

```dart
// Returns true if wind data is too old for reliable calculation
bool isWindStale(WindEntity wind, {Duration maxAge = Duration(minutes: 30)});

// When stale:
// - calculate() returns WindRelativeEntity with all null components
// - confidence = 0.0
// - UI shows "Wind stale" instead of fabricated numbers
```

---

## Dependency Chain

```
Story 7.1 (weather integration)
    ↓ (provides WindEntity via repository)
Slice 1: WindRelativeCalculator
    ↓ (produces WindRelativeEntity)
Slice 2: WindArrowOverlay enhancement
    ↓ (consumes WindRelativeEntity)
Slice 3: Hole map integration
    ↓ (staleness check via)
Slice 4: WindStalenessGuard
```

## File Changes

| File | Change |
|------|--------|
| `apps/mobile/lib/features/hole_map/domain/wind_relative_entity.dart` | **NEW** |
| `apps/mobile/lib/features/hole_map/domain/services/wind_relative_calculator.dart` | **NEW** |
| `apps/mobile/lib/features/hole_map/domain/services/wind_staleness_guard.dart` | **NEW** |
| `apps/mobile/lib/features/hole_map/presentation/widgets/wind_arrow_overlay.dart` | **MODIFY** |
| `apps/mobile/test/features/hole_map/domain/wind_relative_calculator_test.dart` | **NEW** |
| `apps/mobile/test/features/hole_map/domain/wind_staleness_guard_test.dart` | **NEW** |
| `apps/mobile/test/features/hole_map/presentation/widgets/wind_arrow_overlay_test.dart` | **NEW** |

## Verification Checklist

- [ ] Unit tests cover: headwind, tailwind, crosswind left, crosswind right calculations
- [ ] Unit tests cover: stale wind returns nulls with confidence=0
- [ ] Unit tests cover: null wind returns null result
- [ ] Unit tests cover: angle wrap-around (0° vs 359°)
- [ ] Widget test: Semantics label present for screen readers
- [ ] Widget test: Text labels visible without color
- [ ] Widget test: Stale state shows "stale" not numbers
- [ ] Integration: wind relative updates when target placed

## Constraints

- Do NOT implement AI, smartwatch, analytics, or tournament scope
- Preserve Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS decisions
- Keep offline durability — wind data cached locally (from 7.1)
- No fabricated precision when wind is stale
- Accessibility: non-color-only indicators, screen reader support
