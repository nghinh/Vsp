# Slice Plan — Story 11.3: Calculate Strokes Gained

## Story Metadata

| Field | Value |
|---|---|
| Story ID | 11.3 |
| Title | Calculate Strokes Gained |
| Epic | epic-11 (Performance Analytics and Smart Caddie) |
| Phase | MVP 2–3 |
| Status | `in-progress` (planned this run) |
| Dependency | Story 11.2 (Deliver Driving Zone and Round Analytics) — `ready-for-dev` |
| Sprint Run | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |

## Context Reading Evidence

| Document | Lines | Status |
|---|---|---|
| `docs/planning-artifacts/prd.md` | 0–551 | Read: Strokes Gained deferred to Phase 3 (non-goal line 57, phase roadmap line 482); Epic 11 is MVP 2–3 |
| `docs/planning-artifacts/architecture.md` | 0–390 | Read: Analytics deferred extension hooks only (Section 15); modular monolith preserved |
| `docs/planning-artifacts/ux-spec.md` | 0–492 | Read: No strokes-gained UI spec; general UX principles apply |
| `docs/planning-artifacts/epics.md` | 665–683 | Read: Story 11.3 AC, dependencies |
| `docs/implementation-artifacts/epic-11/11-3-calculate-strokes-gained.md` | 0–58 | Read: full story spec |
| `apps/mobile/lib/domain/models/shot.dart` | 0–544 | Read: 22-field shot entity; `ShotLie`, `ShotResult`, `ShotSource` enums |
| Sprint status | `backlog` | Stale — story file and orchestrator confirm `ready-for-dev` |

---

## Anti-Shortcut Evidence

1. **PRD explicitly defers "Full Strokes Gained"** as MVP 1 non-goal (prd.md line 57). Story 11.3 is MVP 2–3 phase — do NOT conflate with MVP 1 scope.
2. **Dependency on 11.2 is not yet implemented** — strokes gained requires shot data from round analytics. Without 11.2, the shot-to-category mapping and distance-range filtering are undefined.
3. **No fabricated precision rule** (prd.md line 88, arch.md Section 10.4) — strokes gained with insufficient sample sizes MUST produce explicit `limitation` flags, never interpolated values.
4. **Epic 11 is Phase 2–3** — all architecture hooks (shot event schema, club performance model, feature store export) are deferred from MVP 1 (arch.md Section 15). Do NOT implement AI, Smart Caddie, or full analytics pipeline.
5. **Shot model already exists** (Story 10.3) — re-use `Shot`, `ShotLie`, `ShotResult` rather than creating parallel structures.

---

## Domain Model — Strokes Gained

### SGCategory (enum)

Represents supported Strokes Gained categories:

```
offTheTee      — Par-4/Par-5 tee shots (excluding putters)
approach       — Shots from 100+ yards to green
aroundTheGreen — Shots inside 100 yards, not on green
putting       — All putts
```

### SGBenchmarkType (enum)

```
similarHandicap  — Peer group benchmark (e.g., 10–15 handicap)
targetHandicap  — User's target/goal handicap
selfHistory     — Player's own historical average
professional    — Valid professional reference (PGA Tour baselines)
```

### StrokesGainedResult

```
category: SGCategory
benchmarkType: SGBenchmarkType
strokesGained: double          // negative = lost shots, positive = gained
baselineStrokes: double        // expected strokes for benchmark
actualStrokes: double          // actual strokes taken
sampleCount: int               // shots in this category (for credibility)
limitation: SGlimitation?      // null if robust, else reason
confidence: double             // 0.0–1.0 based on sample + shot quality
```

### SGlimitation (enum)

```
insufficientSample    — < 20 shots in category
noClubData           — no club distance data for this shot type
noBenchmarkData      — benchmark reference unavailable
mixedConditions      — wind/condition variance too high
tournamentRoundsOnly — filter applied but too few rounds
```

### StrokesGainedSummary

```
playerId: String
roundId: String?
dateRange: DateRange?
overallStrokesGained: double
categoryBreakdown: List<StrokesGainedResult>
limitations: List<SGlimitation>
lastCalculatedAt: DateTime
```

---

## Slice Plan

### Slice 1: Domain Models + Calculation Engine

**Goal:** Pure calculation logic — no I/O, no UI.

1. **Domain models** in `apps/mobile/lib/domain/models/strokes_gained.dart`:
   - `SGCategory`, `SGBenchmarkType`, `SGlimitation`, `StrokesGainedResult`, `StrokesGainedSummary`

2. **Benchmark data models** in same file:
   - `SGBenchmarkData` — static benchmark curves (similar-handicap lookup table)
   - `ProfessionalBenchmark` — PGA Tour baseline by distance band and category
   - `SelfHistoryBenchmark` — computed from player's own shot history

3. **StrokesGainedCalculator** service in `apps/mobile/lib/application/services/strokes_gained_calculator.dart`:
   - `calculateForRound(playerId, roundId, benchmarkTypes): StrokesGainedSummary>`
   - `calculateForDateRange(playerId, start, end, benchmarkTypes): StrokesGainedSummary>`
   - Maps shots → SG categories using distance + lie
   - Applies benchmark lookups
   - Flags limitations when sample < 20 or data missing
   - Self-history benchmark computed from local shot DB

4. **Unit tests** in `apps/mobile/test/application/services/strokes_gained_calculator_test.dart`:
   - Happy path: full round, all categories, all benchmark types
   - Sample size thresholds
   - Limitation flags for missing/incomplete data
   - Empty round (no shots)
   - Mixed conditions filter

### Slice 2: Contracts + Repository

**Goal:** Stable API contracts and local persistence for benchmark results.

1. **OpenAPI contract** additions in `packages/contracts/schema/strokes-gained.yaml`:
   - `StrokesGainedRequest`, `StrokesGainedResponse`, `SGBenchmarkType` enum
   - Add to existing analytics endpoints or create `/analytics/strokes-gained`

2. **Repository interface** in `apps/mobile/lib/domain/repositories/strokes_gained_repository.dart`:
   - `getStrokesGainedSummary(playerId, roundId?, benchmarkTypes): StrokesGainedSummary?`
   - `saveStrokesGainedSummary(summary: StrokesGainedSummary): void`
   - `getBenchmarkData(benchmarkType, category): SGBenchmarkData?`

3. **SQLite DAO** in `apps/mobile/lib/data/local/daos/strokes_gained_dao.dart`:
   - Table: `strokes_gained_summaries` (player_id, round_id, date_range, overall_sg, category_breakdown_json, limitations_json, confidence, last_calculated_at)
   - Table: `sg_benchmarks` (player_id, benchmark_type, category, baseline_strokes, sample_count, updated_at)

4. **Repository impl** in `apps/mobile/lib/data/repositories/strokes_gained_repository_impl.dart`

5. **Unit tests** for DAO and repository

### Slice 3: Comparison View (UI Shell)

**Goal:** UI that displays strokes gained with benchmark comparison.

1. **StrokesGainedScreen** in `apps/mobile/lib/presentation/screens/analytics/strokes_gained_screen.dart`:
   - Displays `StrokesGainedSummary`
   - Category breakdown cards (Off-the-Tee, Approach, Around-Green, Putting)
   - Benchmark type selector (Similar Handicap / Target Handicap / Self-History / Professional)
   - Limitation badges when `limitation != null`
   - Empty state when insufficient shot data
   - Loading and error states

2. **StrokesGainedCard** widget in `apps/mobile/lib/presentation/widgets/analytics/strokes_gained_card.dart`:
   - SG value with sign coloring (green = positive, red = negative)
   - Baseline vs actual strokes
   - Sample count indicator
   - Confidence meter

3. **Accessibility**:
   - Screen reader labels for SG values
   - Non-color-only status (icons + text labels)
   - Touch targets ≥ 44pt

### Slice 4: End-to-End Integration

**Goal:** Tie calculator to real shot data and score data.

1. **Hole-to-category mapping** in calculator:
   - Use `Shot.lie`, `Shot.distanceYards`, and hole `par` to classify
   - Tee shots on Par-4/5 → `offTheTee`
   - 100+ yards from fairway/rough → `approach`
   - Inside 100 yards, not green → `aroundTheGreen`
   - Any putt → `putting`

2. **Score integration**:
   - Verify gross score from `Score` entity for baseline comparison
   - Use `hole_par` from course data for expected score computation

3. **Round analytics service** integration:
   - If Story 11.2 provides shot categorization, consume its contracts
   - If not yet implemented, implement minimal shot→category mapping directly

---

## Wave Structure

| Wave | Slices | Description | Dependency |
|---|---|---|---|
| Wave 1 | Slice 1 | Domain + Calculator Engine | None |
| Wave 2 | Slice 2 | Contracts + Repository | Wave 1 |
| Wave 3 | Slice 3 | UI Shell | Wave 1 + 2 |
| Wave 4 | Slice 4 | E2E Integration | All prior |

**Rationale for parallel-ready waves**: Slices 1–2 are pure domain/calculation with no UI coupling. Slice 3 depends on domain models but not on persistence details. Slice 4 requires all prior layers.

---

## Key Constraints

1. **No fabricated estimates** — when `sampleCount < 20` for a category, return `limitation: insufficientSample` and set `strokesGained: 0`, `confidence: 0.0`
2. **No AI/recommendations** — do NOT generate Smart Caddie advice; limit output to measurement and comparison
3. **Offline-first** — benchmark data and results are persisted locally; no network required for calculation
4. **Tournament policy** — if round is Tournament Mode, flag results with `tournamentRoundsOnly` limitation
5. **Flutter only** — this story is mobile-side calculation; backend analytics is deferred

---

## Verification Gates

- [ ] Unit tests: calculator happy path, sample thresholds, limitation flags, empty/incomplete data
- [ ] Unit tests: DAO CRUD, repository persistence
- [ ] Widget tests: StrokesGainedCard renders SG value with correct sign color
- [ ] Widget tests: StrokesGainedScreen empty state and limitation badges
- [ ] Integration: full round with real shot data produces non-null summary with correct category count
- [ ] Format + lint + typecheck pass on all changed files
- [ ] No new dart analyzer errors introduced

---

## File List (Planned)

```
apps/mobile/lib/domain/models/strokes_gained.dart              [NEW]
apps/mobile/lib/application/services/strokes_gained_calculator.dart [NEW]
apps/mobile/lib/domain/repositories/strokes_gained_repository.dart [NEW]
apps/mobile/lib/data/local/daos/strokes_gained_dao.dart       [NEW]
apps/mobile/lib/data/local/tables/strokes_gained_tables.dart   [NEW]
apps/mobile/lib/data/repositories/strokes_gained_repository_impl.dart [NEW]
apps/mobile/lib/presentation/screens/analytics/strokes_gained_screen.dart [NEW]
apps/mobile/lib/presentation/widgets/analytics/strokes_gained_card.dart [NEW]
apps/mobile/test/application/services/strokes_gained_calculator_test.dart [NEW]
apps/mobile/test/data/local/daos/strokes_gained_dao_test.dart  [NEW]
apps/mobile/test/presentation/widgets/strokes_gained_card_test.dart [NEW]
packages/contracts/schema/strokes-gained.yaml                   [NEW or UPDATE]
```

---

## Planning Evidence

- Context docs read: PRD (lines 0–551), Architecture (0–390), UX Spec (0–492), Epics (665–683), Story (0–58)
- Shot model verified: 22-field entity with `ShotLie`, `ShotResult`, `ShotSource` enums
- Score model exists: `score.dart`, `hole_score.dart` in domain/models
- No existing strokes-gained code found (glob across apps/mobile and apps/api)
- Sprint status shows story `backlog` (stale); story file and orchestrator confirm `ready-for-dev`
- Story 11.2 is dependency but also `ready-for-dev` — plan accommodates partial dependency gap
