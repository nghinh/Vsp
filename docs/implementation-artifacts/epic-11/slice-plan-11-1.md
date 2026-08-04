# Slice Plan — Story 11.1: Calculate Club Performance and Dispersion

**Epic:** Epic 11 — Performance Analytics and Smart Caddie  
**Phase:** MVP 2–3  
**Story Status:** `ready-for-dev` → `in-progress`  
**Plan Date:** 2026-08-02  
**Run ID:** run_2026_08_02_010

---

## 1. Story Context

### User Story
As a golfer, I want actual club distributions so that I understand carry, variability, and misses.

### Acceptance Criteria
| # | Criterion | Notes |
|---|-----------|-------|
| AC-1 | System calculates average/median carry, total, variability, left/right, short/long, and confidence | Core statistical output |
| AC-2 | Low sample sizes are labeled and do not unlock recommendations | Sample size gate |
| AC-3 | Dispersion overlays can be compared against course hazards | Map overlay UX |

### Dependencies (Prerequisite Contracts)
| Source | Contract | Usage |
|--------|----------|-------|
| Epic 2 Story 2.4 | `Club` entity — `carryDistance`, `totalDistance`, `dispersion` fields | Per-club performance storage |
| Epic 10 Story 10.3 | `Shot` entity — `clubId`, `carryDistance`, `totalDistance`, `startLocation`, `endLocation` | Shot data source |
| Epic 10 Story 10.4 | Shot detection confidence | Confidence metadata on shots |
| Epic 6 Story 6.3/6.4 | Course geometry (PostGIS `holes` table) | Hazard geometry for overlay comparison |

### Constraints
- MVP 2–3 phase (Epic 11 is NOT MVP 1)
- Dispersion analytics explicitly deferred from MVP 1 (PRD Section 7.3 / Epic 11 scope)
- Do NOT implement AI/recommendations — only calculation and display
- Club recommendation remains locked until sufficient shot data accumulates (Epic 11 Story 11.4)
- Preserve Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS architecture decisions

---

## 2. Slice Architecture

### Slice 1 — Club Performance Domain & Statistics Engine (Backend)
**Wave:** 1 (foundational — no write-path overlap, pure computation)  
**Owner:** Backend  
**Write Scope:** `apps/api/src/modules/performance/` new module

**Scope:**
- `ClubPerformanceStats` domain model with all AC-1 fields
- Shot aggregation query: filter shots by `clubId` + `userId` + valid `carryDistance`/`totalDistance`
- Statistical computation: avg, median, stdDev, min, max for carry and total
- Left/right deviation: derive from `endLocation` lateral offset relative to shot line
- Short/long deviation: derive from `endLocation` longitudinal offset relative to target
- Confidence level: `low` (<10 shots), `medium` (10–30), `high` (>30) — configurable thresholds
- Sample size label: `insufficient` (<5), `limited` (5–9), `moderate` (10–29), `robust` (≥30)
- API endpoint: `GET /users/{userId}/bags/{bagId}/clubs/{clubId}/performance`
- API endpoint: `GET /users/{userId}/bags/{bagId}/performance` (batch)
- Persistence: computed stats cached in `club_performance` table (invalidated on new shot sync)
- Minimum sample gate: if `sampleSize < 5`, return stats with `confidence.level = "insufficient"` and flag `recommendationsLocked: true`

**Validation Commands:**
```bash
cd apps/api && npm run lint
cd apps/api && npm run test -- --grep "ClubPerformance"
cd apps/api && npm run typecheck
```

### Slice 2 — Dispersion Overlay API & GeoJSON Generation (Backend)
**Wave:** 1 (independent of Slice 1's write path; both compute from shared shot data read)  
**Owner:** Backend  
**Write Scope:** `apps/api/src/modules/performance/` (same module, different service)

**Scope:**
- `DispersionPoint` model: `{ relativeX, relativeY, result }` (normalized coordinates, shot outcome)
- Shot scatter aggregation: group shots by `clubId`, compute normalized relative positions
- Hazard overlay query: join with `holes.geometry` (bunkers, water, OB) via PostGIS
- GeoJSON FeatureCollection generation: scatter points + hazard polygons projected to hole local coordinates
- API endpoint: `GET /users/{userId}/bags/{bagId}/clubs/{clubId}/dispersion?holeId={holeId}&layoutId={layoutId}`
- Returns: scatter points, hazard features, distance metrics (center-to-hazard distances)

**Validation Commands:**
```bash
cd apps/api && npm run lint
cd apps/api && npm run test -- --grep "DispersionOverlay"
cd apps/api && npm run typecheck
```

### Slice 3 — Club Performance UI Screen (Flutter Mobile)
**Wave:** 2 (depends on Slice 1 API contract stabilization)  
**Owner:** Flutter Mobile  
**Write Scope:** `apps/mobile/lib/src/screens/performance/` new screens

**Scope:**
- `ClubPerformanceScreen`: per-club stats display
  - Club name + icon header
  - Sample size badge with label (insufficient/limited/moderate/robust)
  - Stats cards: carry avg/median, total avg/median, variability (stdDev)
  - Directional cards: left/right avg±stdDev, short/long avg±stdDev
  - Confidence indicator with explanation text
  - Recommendations locked state with explanation when sample insufficient
- `BagPerformanceScreen`: club list with performance summary cards
  - List of clubs with mini performance sparklines
  - Tap to navigate to `ClubPerformanceScreen`
- Loading, empty, and error states
- Offline: show cached performance data with stale indicator (no computation offline)
- Accessibility: screen reader labels, non-color indicators, 44/48dp touch targets

**Validation Commands:**
```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug  # smoke test
```

### Slice 4 — Dispersion Overlay Visualization (Flutter Mobile)
**Wave:** 2 (depends on Slice 2 API contract stabilization, can parallelize with Slice 3)  
**Owner:** Flutter Mobile  
**Write Scope:** `apps/mobile/lib/src/widgets/performance/` new widgets

**Scope:**
- `DispersionMapWidget`: MapLibre overlay showing:
  - Shot scatter points as heatmap or point cloud (color = result: fairway/rough/hazard/OB)
  - Hazard polygons from course package geometry
  - Scale reference (25m grid)
- Integrate with hole map from Epic 6 Story 6.3
- Toggle: show/hide hazards, toggle scatter layer
- Overlay on actual hole geometry (uses hole local coordinate system)
- `DispersionLegendWidget`: result color legend, count per category
- Accessibility: non-color indicators (icons + patterns), screen reader descriptions

**Validation Commands:**
```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug
```

---

## 3. Wave Plan

| Wave | Slices | Parallel | Reason |
|------|--------|----------|--------|
| 1 | Slice 1 (stats engine), Slice 2 (dispersion API) | ✅ Yes | Independent backend compute services reading same shot data; no write-path overlap |
| 2 | Slice 3 (performance UI), Slice 4 (dispersion overlay) | ✅ Yes | Independent Flutter screens/widgets; both depend on API contracts from Wave 1 but don't share write scope |

**Note:** Wave 2 may begin after Wave 1 API contracts are stabilized (not necessarily fully deployed). API contract review during Wave 1 is recommended before Wave 2 dispatch.

---

## 4. Requirements Coverage Matrix

| Acceptance Criterion | Slice(s) | Coverage |
|---------------------|----------|----------|
| AC-1: avg/median carry, total, variability | Slice 1 | Full |
| AC-1: left/right, short/long | Slice 1 | Full |
| AC-1: confidence | Slice 1 | Full |
| AC-2: low sample labeled | Slice 1, Slice 3 | Full (backend flags, UI displays label + locked state) |
| AC-2: recommendations not unlocked | Slice 1 (`recommendationsLocked: true`), Slice 3 (UI respects flag) | Full |
| AC-3: dispersion overlays | Slice 2, Slice 4 | Full (backend generates GeoJSON, Flutter renders overlay) |
| AC-3: compare against course hazards | Slice 2 (hazard join), Slice 4 (overlay on hole map) | Full |

---

## 5. Data Flow

```
Shot Entity (Epic 10)
  └─► ClubPerformanceStatsService (Slice 1)
        ├─► club_performance table (cache)
        └─► GET /users/{userId}/bags/{bagId}/clubs/{clubId}/performance

Shot Entity (Epic 10) + Hole Geometry (Epic 6)
  └─► DispersionOverlayService (Slice 2)
        └─► GET /users/{userId}/bags/{bagId}/clubs/{clubId}/dispersion?holeId=

Flutter Mobile (Slice 3 + Slice 4)
  ├─► ClubPerformanceScreen
  └─► DispersionMapWidget (MapLibre overlay on hole map)
```

---

## 6. Minimum Sample Size Policy

| shots | label | confidence | recommendationsLocked |
|-------|-------|------------|----------------------|
| <5 | `insufficient` | `insufficient` | `true` |
| 5–9 | `limited` | `low` | `true` |
| 10–29 | `moderate` | `medium` | `true` |
| ≥30 | `robust` | `high` | `false` |

**Note:** `recommendationsLocked: true` does NOT suppress display of stats. Stats are always shown with label. Recommendations unlock only when `recommendationsLocked: false` (≥30 shots).

---

## 7. Non-Functional Requirements

| NFR | Implementation |
|-----|----------------|
| NFR-1: <2s screen load | Cache computed stats; invalidate on new shot sync |
| NFR-2: Distance units | API returns meters; Flutter converts to user-preferred unit (meters/yards) |
| NFR-3: Offline behavior | Mobile caches last-fetched performance data; computation requires connectivity |
| NFR-4: Accessibility | All stats cards have semantic labels; confidence uses icon+text, not color alone |
| NFR-5: Glanceability | Performance summary visible at top of screen before scroll |
| NFR-6: Flutter semantics | Use `Semantics` widgets for custom performance cards |

---

## 8. Out of Scope (Do Not Implement)

- Club recommendations or AI suggestion generation (Epic 11 Story 11.4)
- Strokes Gained calculation (Epic 11 Story 11.3)
- Smart Target generation (Epic 11 Story 11.4)
- Driving Zone UI (Epic 11 Story 11.2 — backend may prepopulate)
- Watch app support (Epic 10)
- Tournament Mode feature changes (Epic 7 Story 7.4)

---

## 9. Slice Write Scope Boundaries

| Slice | Module/Layer | Files (estimated) |
|-------|-------------|-------------------|
| Slice 1 | `apps/api/src/modules/performance/club-performance/` | `club-performance-stats.service.ts`, `club-performance-stats.controller.ts`, `club-performance-stats.domain.ts`, `club-performance.repository.ts`, `club-performance.module.ts` |
| Slice 2 | `apps/api/src/modules/performance/dispersion/` | `dispersion-overlay.service.ts`, `dispersion-overlay.controller.ts`, `dispersion-overlay.domain.ts`, `dispersion-overlay.repository.ts`, `dispersion-overlay.module.ts` |
| Slice 3 | `apps/mobile/lib/src/screens/performance/` | `club_performance_screen.dart`, `bag_performance_screen.dart`, `widgets/club_stats_card.dart`, `widgets/confidence_badge.dart` |
| Slice 4 | `apps/mobile/lib/src/widgets/performance/` | `dispersion_map_widget.dart`, `dispersion_legend_widget.dart`, `scatter_point_layer.dart` |

---

## 10. Testing Strategy

| Layer | Test Type | Coverage Target |
|-------|-----------|-----------------|
| Slice 1 | Unit: statistical computation functions | Happy paths, edge cases (0 shots, 1 shot, median of even count) |
| Slice 1 | Integration: API endpoint | 200, 404 (club not found), 401 (unauth), empty shot set |
| Slice 2 | Unit: GeoJSON generation from shot points | scatter point normalization, hazard polygon join |
| Slice 2 | Integration: dispersion endpoint with PostGIS | Valid hole, non-existent hole |
| Slice 3 | Widget: stats card rendering | Loading, error, insufficient sample, robust sample |
| Slice 3 | Screen: navigation and data flow | Round-trip from bag list → club screen |
| Slice 4 | Widget: overlay renders without crash | Empty overlay, full scatter, hazard toggle |
| E2E | Club performance end-to-end | Preconditions: user has shots for club; verify stats display |

---

## 11. Quality Gate Triggers

After each wave, the following must be clean before proceeding:
1. **Format:** `npm run format` / `flutter format`
2. **Lint:** `npm run lint` / `flutter analyze`
3. **Typecheck:** `npm run typecheck` / `flutter analyze`
4. **Tests:** 100% new unit tests passing; no regressions in existing tests
5. **Build:** `npm run build` / `flutter build apk --debug` (smoke)
6. **Dedup:** Symbol uniqueness verified (Serena + GitNexus check for new symbols)

---

*Slice plan created by `vnpt-epic-story-runner` for story 11.1 — `run_2026_08_02_010`*
