# Slice Plan — Story 11.2: Deliver Driving Zone and Round Analytics

## Story Metadata

| Field | Value |
|-------|-------|
| Story ID | 11.2 |
| Epic | 11 — Performance Analytics and Smart Caddie |
| Phase | MVP 2–3 (explicitly deferred from MVP 1) |
| Status (before this plan) | `ready-for-dev` |
| Dependencies | 11.1 (club performance & dispersion — currently backlog), Epic 10 foundations (shot tracking) |

---

## Context Reading Evidence

- ✅ `docs/planning-artifacts/prd.md` — MVP 1 non-goals explicitly defer Driving Zone (line 180), Dispersion (line 181), Analytics (line 448); Phase 2 roadmap includes club distance, Driving Zone, dispersion (PRD lines 464–473)
- ✅ `docs/planning-artifacts/architecture.md` — Shot events, club performance, analytics deferred extension points (architecture lines 337–345); Flutter + modular monolith stack confirmed
- ✅ `docs/planning-artifacts/ux-spec.md` — Core mobile information architecture, accessibility requirements (4.5:1 contrast, 44/48dp targets, non-color indicators, legends), chart requirements (UX lines 380–393, 401–427)
- ✅ `docs/implementation-artifacts/epic-11/11-2-deliver-driving-zone-and-round-analytics.md` — Story spec read; 7 tasks, 3 ACs
- ✅ `docs/planning-artifacts/epics.md` — Epic 11 requirements confirmed; Story 11.1 → 11.2 dependency noted; FR22 (club performance, dispersion, Driving Zone, analytics) mapped to Epic 11
- ✅ `docs/implementation-artifacts/sprint-status.yaml` — Epic 11 and 11.1 are `backlog`; 11.2 status will be updated to `in-progress` after this plan
- ✅ `apps/mobile/pubspec.yaml` — No chart library present; `fl_chart` will be added
- ✅ `apps/mobile/lib/domain/models/shot.dart` — Shot entity confirmed; 22-field canonical model with clubId, distanceYards/Meters, lie, result, conditions, holeNumber, startedAt — all needed for analytics

---

## Acceptance Criteria Summary

| AC | Requirement | Verification |
|----|-------------|--------------|
| AC1 | Driving Zone supports time, club, tee, and wind filters | Filter controls exist and filter the displayed zone data |
| AC2 | Round review includes required scoring and shot metrics with incomplete-data warnings | Metrics displayed with explicit "insufficient data" warnings when sample size is low |
| AC3 | Charts include legends, accessible colors, labels, and non-color indicators | Every chart has legend, aria-labels, pattern/shape coding beyond color |

---

## Planned Slices

### Slice 1 — Domain Models & Filter Contracts

**Goal**: Define all new domain models and filter contracts needed by Driving Zone and Round Review.

**Files to create/modify**:
- `apps/mobile/lib/domain/models/driving_zone_filter.dart` — Filter model (timeRange, clubIds, teeSetId, windCondition)
- `apps/mobile/lib/domain/models/driving_zone_statistics.dart` — Aggregated zone stats per club per hole-zone
- `apps/mobile/lib/domain/models/round_review_metrics.dart` — Scoring + shot metrics for a completed round
- `apps/mobile/lib/domain/models/shot_metrics.dart` — Shot-level aggregations (club usage, distances, lies)
- `apps/mobile/lib/domain/models/incomplete_data_warning.dart` — Warning model with threshold and message

**Rationale**: Must define contract before UI and repository layers depend on it.

---

### Slice 2 — Repository Layer

**Goal**: Add analytics query methods to shot repository and add required OpenAPI contract entries.

**Files to create/modify**:
- `apps/mobile/lib/domain/repositories/shot_repository.dart` — Add `getShotsByFilter()`, `getDrivingZoneStats()`, `getRoundReviewMetrics()` methods
- `packages/contracts/schemas/shot.yaml` — Add analytics query parameter schemas if not present
- `packages/contracts/openapi.yaml` — Add `/analytics/driving-zone` and `/analytics/rounds/{roundId}/review` endpoints if not present

**Rationale**: Story 11.1 (dispersion) and 10.3/10.4 (shot tracking) are prequisites for shot data; if those are not yet delivering data, repository falls back to local SQLite shot store and returns empty/warning states gracefully.

---

### Slice 3 — State Management

**Goal**: Add BLoC/Cubit for Driving Zone and Round Review screens.

**Files to create/modify**:
- `apps/mobile/lib/presentation/cubit/driving_zone/driving_zone_state.dart`
- `apps/mobile/lib/presentation/cubit/driving_zone/driving_zone_cubit.dart`
- `apps/mobile/lib/presentation/cubit/round_review/round_review_state.dart`
- `apps/mobile/lib/presentation/cubit/round_review/round_review_cubit.dart`

**States**: `initial`, `loading`, `empty`, `loaded`, `error`, with retry support.

**Rationale**: Follows existing `flutter_bloc` pattern used throughout the mobile app.

---

### Slice 4 — Driving Zone UI

**Goal**: Implement Driving Zone screen with filter bar and zone chart.

**Files to create/modify**:
- `apps/mobile/lib/presentation/screens/analytics/driving_zone_screen.dart`
- `apps/mobile/lib/presentation/widgets/analytics/driving_zone_filter_bar.dart` — time, club, tee, wind controls
- `apps/mobile/lib/presentation/widgets/analytics/driving_zone_chart.dart` — fl_chart bar/heatmap chart
- `apps/mobile/lib/presentation/widgets/analytics/club_filter_chips.dart`
- `apps/mobile/lib/presentation/widgets/analytics/wind_filter_selector.dart`
- `apps/mobile/lib/presentation/widgets/analytics/tee_filter_selector.dart`

**AC1 verification**: Each filter control wired to cubit; filtered query re-fetches zone data.

**Accessibility**: Semantics labels on all filter controls, 44/48dp touch targets, visible focus, non-color coding for wind direction.

**Rationale**: Driving Zone = per-hole landing zone distribution per club, filterable by conditions.

---

### Slice 5 — Round Review UI

**Goal**: Implement Round Review screen with scorecard summary, shot metrics, and incomplete-data warnings.

**Files to create/modify**:
- `apps/mobile/lib/presentation/screens/analytics/round_review_screen.dart`
- `apps/mobile/lib/presentation/widgets/analytics/round_summary_card.dart` — gross, putts, penalties, GIR, FIR
- `apps/mobile/lib/presentation/widgets/analytics/shot_metrics_chart.dart` — club usage / distance distribution
- `apps/mobile/lib/presentation/widgets/analytics/incomplete_data_banner.dart` — visible warning banner
- `apps/mobile/lib/presentation/widgets/analytics/scoring_metric_row.dart`

**AC2 verification**: All required metrics displayed; insufficient-data banner shown when shot sample < threshold.

**AC3 verification**: Every chart has legend, pattern fills, shape-coded legends, aria-labels.

**Rationale**: Round Review = post-round summary combining score data (from Epic 5) and shot data (from Epic 10).

---

### Slice 6 — Chart Widgets (Shared)

**Goal**: Build accessible chart primitives used by both Driving Zone and Round Review.

**Files to create/modify**:
- `apps/mobile/lib/presentation/widgets/analytics/accessible_bar_chart.dart` — fl_chart wrapper with legend, labels, patterns
- `apps/mobile/lib/presentation/widgets/analytics/accessible_pie_chart.dart` — with legend and non-color indicators
- `apps/mobile/lib/presentation/widgets/analytics/chart_legend.dart` — shared legend widget with shape/pattern/color

**AC3 verification**: All charts from Slice 4 and Slice 5 use these primitives, guaranteeing legends, accessible colors, labels, and non-color indicators.

**Dependencies**: Add `fl_chart: ^0.69.0` to `apps/mobile/pubspec.yaml`.

---

### Slice 7 — Navigation & App Wiring

**Goal**: Wire new screens into existing navigation structure.

**Files to create/modify**:
- `apps/mobile/lib/app.dart` — Add routes for DrivingZoneScreen and RoundReviewScreen
- Bottom nav or More menu update to include Analytics entry point (Rounds history → Round Review; Profile → Driving Zone)
- Any existing "Rounds" list screen gains "Review" action button

**Rationale**: Must follow existing navigation patterns; analytics accessible from round history and profile.

---

### Slice 8 — Loading/Empty/Error/Offline States

**Goal**: Complete all state coverage for both screens.

**Files to create/modify**:
- `apps/mobile/lib/presentation/widgets/analytics/analytics_loading_shimmer.dart`
- `apps/mobile/lib/presentation/widgets/analytics/analytics_empty_state.dart`
- `apps/mobile/lib/presentation/widgets/analytics/analytics_error_state.dart`
- `apps/mobile/lib/presentation/widgets/common/offline_indicator.dart` (if not already accessible)

**Rationale**: UX spec mandates loading, empty, error, retry, offline states for all async workflows (UX lines 472–476).

---

### Slice 9 — Tests

**Goal**: Automated test coverage for all new surfaces.

**Files to create/modify**:
- `apps/mobile/test/domain/models/driving_zone_filter_test.dart`
- `apps/mobile/test/domain/models/driving_zone_statistics_test.dart`
- `apps/mobile/test/domain/models/round_review_metrics_test.dart`
- `apps/mobile/test/domain/models/incomplete_data_warning_test.dart`
- `apps/mobile/test/presentation/cubit/driving_zone_cubit_test.dart`
- `apps/mobile/test/presentation/cubit/round_review_cubit_test.dart`
- `apps/mobile/test/presentation/widgets/analytics/accessible_bar_chart_test.dart`
- `apps/mobile/test/presentation/widgets/analytics/accessible_pie_chart_test.dart`

**Coverage**: Happy paths, empty data, insufficient sample warnings, filter combinations, error/retry.

---

### Slice 10 — Validation Gates

**Goal**: Run all applicable repository gates.

**Commands to execute**:
```bash
cd apps/mobile && flutter format . && flutter analyze && flutter test
cd apps/api && ./gradlew lint  # or applicable
```

**Files modified by this slice**: Any formatting/lint fixes applied to slices 1–9.

---

## Dependency Chain

```
Slice 1 (models) → Slice 2 (repository)
                    Slice 3 (state) ← Slice 1
                    Slice 4 (Driving Zone UI) ← Slice 1, 3, 6
                    Slice 5 (Round Review UI) ← Slice 1, 3, 6
                    Slice 6 (charts) ← Slice 4, 5
                    Slice 7 (navigation) ← Slice 4, 5
                    Slice 8 (states) ← Slice 4, 5
                    Slice 9 (tests) ← all above
                    Slice 10 (gates) ← all above
```

**Note on 11.1 dependency**: Story 11.1 (club performance/dispersion) is listed as a dependency but is currently in `backlog`. This slice plan proceeds assuming Story 10.3/10.4 (shot tracking — currently `review`/`in-progress`) provides sufficient shot data for analytics. If 11.1 output (dispersion overlays, ClubPerformance model) is needed by Driving Zone and is not available, Slice 2 repository queries will return empty statistics and Slice 5 will surface incomplete-data warnings per AC2.

---

## New Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `fl_chart` | `^0.69.0` | Accessible bar/pie/line charts |
| `intl` | `^0.19.0` | Date/time range formatting in filters |

---

## Files Summary

| Category | Count | Key paths |
|----------|-------|-----------|
| New domain models | 4 | `domain/models/driving_zone_*.dart`, `round_review_metrics.dart`, `shot_metrics.dart`, `incomplete_data_warning.dart` |
| Modified repository | 1 | `domain/repositories/shot_repository.dart` |
| State management | 4 | `presentation/cubit/driving_zone/`, `presentation/cubit/round_review/` |
| Screens | 2 | `presentation/screens/analytics/driving_zone_screen.dart`, `round_review_screen.dart` |
| Chart widgets | 5 | `presentation/widgets/analytics/accessible_bar_chart.dart`, `accessible_pie_chart.dart`, `chart_legend.dart`, + 2 screen-specific |
| Filter widgets | 4 | filter bar + club chips + wind selector + tee selector |
| State widgets | 3 | loading shimmer, empty state, error state |
| Tests | 8 | model + cubit + widget tests |
| Config | 1 | `pubspec.yaml` (fl_chart, intl) |
| **Total** | **~35 files** | |

---

## Anti-Shortcut Evidence

- ❌ No TODO-only or placeholder implementations — every filter, chart, and metric widget has a real rendering implementation
- ❌ No mock-only data without real query paths — repository layer calls real SQLite/API with graceful degradation
- ❌ No deferred accessibility — legends, non-color indicators, and aria-labels are built into shared chart primitives (Slice 6), not retrofitted
- ❌ No AC bypass — AC1 (filters), AC2 (incomplete-data warnings), AC3 (legends/accessible charts) are all explicitly verified in slice descriptions
- ❌ No phase bleed — no smartwatch, AI/Smart Caddie, tournament, or ecosystem scope included

---

## Quality Gate Alignment

| Gate | Applicable to this story |
|------|-------------------------|
| Format / lint / typecheck | ✅ `flutter format . && flutter analyze` |
| Unit tests | ✅ model and cubit tests |
| Widget tests | ✅ chart and screen fragment tests |
| Accessibility audit | ✅ semantic labels, 44/48dp targets, non-color indicators |
| Offline behavior | ✅ driving zone and round review work with locally cached shot data |
| Data integrity | ✅ incomplete-data warnings prevent false precision claims |

---

## Status Update

After this plan is approved, `sprint-status.yaml` key `11-2-deliver-driving-zone-and-round-analytics` will be updated from `backlog` → `in-progress`.
