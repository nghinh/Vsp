# Slice Plan — Story 11.4: Generate Explainable Smart Target

## Story Metadata

| Field | Value |
|-------|-------|
| Story | 11.4 |
| Epic | 11 (Performance Analytics and Smart Caddie) |
| Phase | MVP 2–3 |
| Status (pre-slice) | ready-for-dev |
| Run folder | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |
| Plan created | 2026-08-02 |

---

## Context Reading Evidence

| Document | Read | Lines |
|----------|------|-------|
| `docs/planning-artifacts/prd.md` | ✅ | 551 |
| `docs/planning-artifacts/architecture.md` | ✅ | 390 |
| `docs/planning-artifacts/ux-spec.md` | ✅ | 492 |
| `docs/planning-artifacts/epics.md` (Epic 11) | ✅ | 641–684 |
| `docs/implementation-artifacts/epic-11/11-4-generate-explainable-smart-target.md` | ✅ | 58 |
| `docs/implementation-artifacts/epic-11/11-3-calculate-strokes-gained.md` | ✅ | 58 |
| `docs/implementation-artifacts/epic-11/11-1-calculate-club-performance-and-dispersion.md` | ✅ | 57 |
| `docs/vnpt-flow/epic-run-run_2026_08_02_010/epic-state.json` | ✅ | 33 |
| `docs/implementation-artifacts/sprint-status.yaml` | ✅ | 99 |

---

## User Story

> As a golfer, I want safe, balanced, and aggressive strategies so that I can choose risk intentionally.

---

## Acceptance Criteria

| # | Criterion | Verification method |
|---|----------|---------------------|
| AC1 | Recommendations use geometry, club data, dispersion, hazards, conditions, handicap, history, and policy | Unit tests verifying all 8 data sources are consulted |
| AC2 | Output includes club, aim, carry, remaining distance, hazards, risk, confidence, and explanation | Model/serialization tests verifying all 8 output fields present |
| AC3 | Tournament restrictions applied before recommendation generation | Policy-gating unit tests: generation returns empty/disabled when restricted |

---

## Dependency Analysis

### Upstream dependencies (must be called/consulted)

| Dependency | Story | What is needed |
|-----------|-------|----------------|
| Tournament policy check | 7.4 (Enforce Tournament Mode Restrictions) | `TournamentPolicy.restrictions[]` — if `clubRecommendation` or `aiStrategy` is restricted, generation must not produce output or must mark `available: false` |
| Hole geometry | Epic 6 (any completed story with hole data) | `Hole.geometry`, hazard polygons, green boundary, pin position |
| Golf bag + clubs | 2.4 (Manage Golf Bag and Clubs) | `Bag.clubs[]` with loft, carry distance |
| Club performance + dispersion | 11.1 (Calculate Club Performance and Dispersion) | `ClubPerformanceStats` per club: avg/median carry, variability, left/right dispersion |
| Strokes gained + round analytics | 11.3 (Calculate Strokes Gained) | `StrokesGainedResult`, benchmark comparisons |
| Course/weather conditions | Epic 7 (Weather Intelligence) | wind direction/speed, temperature, green speed |

### Downstream consumers

- Active Round Map screen: displays Smart Target strategy cards
- Round summary: records selected strategy for later analysis
- Future: Smart Caddie AI round review (Phase 3 roadmap, not in scope)

### Epic ordering within 11

All four epic-11 stories (11.1, 11.2, 11.3, 11.4) are `ready-for-dev`. The manifest execution order is 11.1 → 11.2 → 11.3 → 11.4, consistent with data-flow dependencies (11.4 reads 11.1–11.3 outputs). Independent slices within 11.4 can begin immediately.

---

## Architecture Decisions

### Owning layer: Flutter mobile app — `apps/mobile/lib/`

### Module path: `lib/domain/analytics/` and `lib/application/analytics/`

### Package structure

```
apps/mobile/lib/
  domain/
    analytics/
      smart_target/
        models/
          strategy_option.dart         # Safe/balanced/aggressive strategy
          smart_target_recommendation.dart  # Top-level output
          hazard_at_landing.dart      # Hazard intersecting landing zone
        services/
          tournament_policy_guard.dart # AC3: policy check before generation
        repositories/
          club_performance_repository.dart   # Reads 11.1 output
          strokes_gained_repository.dart     # Reads 11.3 output
          hole_geometry_provider.dart       # Reads Epic 6 hole data
        smart_target_generator.dart    # Core algorithm
  application/
    analytics/
      generate_smart_target_use_case.dart
      smart_target_provider.dart       # State management (ChangeNotifier)
  presentation/
    analytics/
      smart_target_card.dart          # UX: strategy selection card
      strategy_option_tile.dart        # UX: individual option row
      smart_target_panel.dart         # UX: on-course panel
```

### Strategy tier algorithm (core logic)

For each strategy tier (safe, balanced, aggressive):

1. **Identify candidate aim points** along the shot line at N-meter intervals between safe zone and green
2. **For each aim point**:
   - Compute carry distance = distance from golfer position to aim point
   - Filter clubs whose carry range covers this distance (within ±dispersion tolerance)
   - Compute landing zone ellipse (carry distance ± club dispersion)
   - Intersect ellipse with hazard geometries → count/size of hazards crossed
   - Compute risk score = weighted sum of (hazard proximity × hazard penalty weight)
3. **Select best aim point per strategy**:
   - `safe`: minimize risk, prefer higher-confidence clubs
   - `balanced`: maximize expected strokes gained vs risk tradeoff
   - `aggressive`: maximize potential distance gain, accept higher risk
4. **Generate explanation**: template string citing key decision factors

### Risk scoring model

```
risk_score = Σ (hazard_penalty_i × proximity_factor_i × confidence_weight)

proximity_factor = 1.0 if landing zone overlaps hazard
                 = 0.5 if hazard within 1 dispersion unit
                 = 0.0 otherwise

confidence_weight = ClubPerformanceStats.confidence (0.0–1.0)
```

### Tournament policy guard

```
IF tournamentPolicy.isRestrictionEnabled('clubRecommendation') OR
   tournamentPolicy.isRestrictionEnabled('aiStrategy')
THEN
  return SmartTargetRecommendation(available: false, reason: 'restricted_by_policy')
```

---

## Slice Plan

### Slice 0: Contracts and Domain Models (no-op proof)

**Goal**: Establish the data contracts without touching UI or persistence.

**Files**:
- `apps/mobile/lib/domain/analytics/smart_target/models/strategy_option.dart`
- `apps/mobile/lib/domain/analytics/smart_target/models/hazard_at_landing.dart`
- `apps/mobile/lib/domain/analytics/smart_target/models/smart_target_recommendation.dart`
- `apps/mobile/lib/domain/analytics/smart_target/models/strategy_type.dart`
- `apps/mobile/lib/domain/analytics/smart_target/services/tournament_policy_guard.dart` — pure function, no dependencies
- `apps/mobile/lib/domain/analytics/smart_target/smart_target_generator.dart` — stub returning null until data sources land

**Tests**:
- `test/unit/smart_target_models_test.dart` — serialization round-trip, null-safety
- `test/unit/tournament_policy_guard_test.dart` — policy-gating truth table (restricted/not, mode: tournament/casual)

**Verification**: `flutter test` passes, no linter errors.

---

### Slice 1: Data Access Interfaces

**Goal**: Define repository interfaces and in-memory stub implementations so Slice 0 generator can be wired to real data.

**Files**:
- `apps/mobile/lib/domain/analytics/smart_target/repositories/club_performance_repository.dart` — interface
- `apps/mobile/lib/domain/analytics/smart_target/repositories/strokes_gained_repository.dart` — interface
- `apps/mobile/lib/domain/analytics/smart_target/repositories/hole_geometry_provider.dart` — interface
- `apps/mobile/lib/domain/analytics/smart_target/repositories/in_memory_club_performance_repository.dart` — stub for testing
- `apps/mobile/lib/domain/analytics/smart_target/repositories/in_memory_strokes_gained_repository.dart` — stub
- `apps/mobile/lib/domain/analytics/smart_target/repositories/in_memory_hole_geometry_provider.dart` — stub

**Tests**:
- `test/unit/club_performance_repository_test.dart`
- `test/unit/strokes_gained_repository_test.dart`
- `test/unit/hole_geometry_provider_test.dart`

**Verification**: `flutter test` passes.

---

### Slice 2: Core Generator Algorithm

**Goal**: Implement the full strategy-tier algorithm.

**Files**:
- `apps/mobile/lib/domain/analytics/smart_target/smart_target_generator.dart` — full implementation
- Update `apps/mobile/lib/application/analytics/generate_smart_target_use_case.dart`

**Algorithm detail**:
- `generate(HoleContext, GolferState, ClubPerformanceRepository, StrokesGainedRepository, HoleGeometryProvider, TournamentPolicy): SmartTargetRecommendation`
- Early return `unavailable` for insufficient data (< minimum shot sample threshold)
- Produce exactly 3 `StrategyOption` (safe, balanced, aggressive)
- Each option has: `club`, `aimPoint` (lat/lng), `carryMeters`, `remainingMeters`, `hazardsAtLanding[]`, `riskScore` (0–100), `confidenceScore` (0.0–1.0), `explanation`

**Tests**:
- `test/unit/smart_target_generator_test.dart` — happy path with synthetic geometry
- `test/unit/smart_target_generator_boundaries_test.dart` — insufficient data, all hazards clear, all hazards blocked, tournament restricted

**Verification**: `flutter test` passes, `dart analyze` clean.

---

### Slice 3: State Management + UI Shell

**Goal**: Wire generator into app state and build minimal UI surface.

**Files**:
- `apps/mobile/lib/application/analytics/smart_target_provider.dart` — ChangeNotifier
- `apps/mobile/lib/presentation/analytics/smart_target_panel.dart` — on-course panel widget
- `apps/mobile/lib/presentation/analytics/smart_target_card.dart` — strategy card
- `apps/mobile/lib/presentation/analytics/strategy_option_tile.dart` — individual option row
- Update `apps/mobile/lib/presentation/screens/active_round_screen.dart` to include Smart Target panel

**UX requirements** (from ux-spec.md):
- Glanceable: critical info readable in <2 seconds
- One-hand/two-tap: strategy selection completes in ≤2 taps
- Confidence visible: risk score and confidence score shown with text + color
- Tournament mode: panel hidden or shows "unavailable" when policy restricts
- Accessibility: semantics labels, 44/48dp touch targets, non-color-only indicators

**Tests**:
- `test/unit/smart_target_provider_test.dart` — state transitions: loading/available/unavailable/error
- `test/widget/smart_target_panel_test.dart` — render, accessibility semantics

**Verification**: `flutter test`, widget test passes.

---

### Slice 4: Integration + End-to-End Behavior

**Goal**: Wire to real repositories (11.1, 11.3 data) when available, add offline/sync behavior.

**Files**:
- `apps/mobile/lib/infrastructure/analytics/sqlite_club_performance_repository.dart` — reads from local SQLite (written by 11.1)
- `apps/mobile/lib/infrastructure/analytics/sqlite_strokes_gained_repository.dart` — reads from local SQLite (written by 11.3)
- `apps/mobile/lib/infrastructure/analytics/hole_geometry_provider_impl.dart` — reads from downloaded course package (Epic 4/6)
- Update `smart_target_provider.dart` to handle `dataUnavailable` state gracefully (show "insufficient data" message, not crash)

**Offline behavior**:
- Smart Target is computed locally (no server round-trip)
- If 11.1/11.3 data not yet synced, show "Not enough round history" with confidence = 0
- No network dependency for generation

**Tests**:
- `test/unit/smart_target_integration_test.dart` — end-to-end with stubbed real data shapes

**Verification**: `flutter test`, `flutter build apk` (or `flutter build ios`).

---

## Anti-Shortcut Evidence

- ❌ Do NOT generate a fixed/static recommendation without consulting real club performance data (would fail AC1)
- ❌ Do NOT skip the tournament policy check (would fail AC3)
- ❌ Do NOT fabricate missing data — insufficient history must surface as `available: false` with explicit reason, not estimated values
- ❌ Do NOT output risk scores without hazard intersection calculation
- ❌ Do NOT skip confidence scoring — low sample size must reduce confidence (per 11.1 spec)
- ❌ Do NOT build a server-side generator — Smart Target must work offline (per local-first principle)

---

## Quality Gate Coverage

| Gate | Applicable to | Tool |
|------|--------------|------|
| Format | All Dart files | `dart format` |
| Lint | All Dart files | `dart analyze` |
| Unit tests | All slices | `flutter test test/unit/` |
| Widget tests | Slice 3+ | `flutter test test/widget/` |
| Accessibility | Slice 3+ | `flutter test`, manual semantic review |
| Build | Slice 4 | `flutter build apk` |

---

## Verification Evidence Required from Implementer

- [ ] All 8 data sources confirmed consulted (traced in code)
- [ ] All 8 output fields confirmed present (model serialization test)
- [ ] Tournament policy gating confirmed with unit tests
- [ ] `flutter test` green on all slices
- [ ] `dart analyze` zero errors
- [ ] Widget tests pass for UI components
- [ ] Accessibility: Semantics labels on all interactive elements, 44/48dp touch targets
- [ ] Offline behavior verified: works without network when data available locally

---

## Story 11.4 Execution Wave

All epic-11 stories (11.1, 11.2, 11.3, 11.4) are `ready-for-dev`. Stories 11.1–11.3 produce data that 11.4 consumes. The recommended wave is:

```
Wave A (can run in parallel with 11.2, 11.3):
  - 11.1: Calculate Club Performance and Dispersion

Wave B (depends on 11.1):
  - 11.2: Deliver Driving Zone and Round Analytics
  - 11.3: Calculate Strokes Gained

Wave C (depends on 11.1 + 11.2 + 11.3):
  - 11.4: Generate Explainable Smart Target  ← this story
```

This slice plan is for Wave C / Story 11.4.

---

*Plan authored by `vnpt-dev-story-orchestrator` for story 11.4 — Generate Explainable Smart Target*
