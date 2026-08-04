# Slice Plan — Story 5.3: Enter Scores for a Flight

## Evidence of Context Reading

| Source | Evidence |
|--------|----------|
| `prd.md` §8.10 | "MVP supports score entry for up to four golfers on one device. Fields: gross, putts, penalties, fairway hit, GIR, bunker, notes. Score data persisted locally before sync." |
| `prd.md` §10.7 | Accessibility: color-blind-friendly indicators, non-color-only score indicators |
| `prd.md` §5 (principles) | One-hand and max-two-tap UX, glanceable, offline-first, correctable later |
| `architecture.md` §8.1 | Flutter app layers: Presentation → Application → Domain → Infrastructure |
| `architecture.md` §8.2 | SQLite for rounds, scores, local events, sync cursors |
| `architecture.md` §8.3 | Local-first: writes → local SQLite → event queue → sync worker |
| `architecture.md` §6 | Round Module, Score Module as explicit bounded modules |
| `ux-spec.md` §5.1 | Active round bottom nav: Map, Score, Target, Conditions, More |
| `ux-spec.md` §6.2 | Scorecard: fast gross score entry, per-player compact cards, save feedback immediate, offline saved indicator |
| `ux-spec.md` §10 | Touch targets ≥44/44pt iOS / 48/48dp Android; non-color-only indicators |
| `story 5.2` | Persist round locally: SQLite transactions for round/hole/player/score/sync events |
| `story 5.1` | Configure and start a round: players (up to 4), format, tee, mode, starting hole |
| `story 3.1` | Course/hole/tee geometry models already implemented (done) |
| `epic-05` | Round Management epic: 5.1 configure, 5.2 persist, **5.3 enter scores**, 5.4 sync, 5.5 complete |

---

## Story Summary

**Story**: 5.3 — Enter Scores for a Flight  
**Epic**: 5 — Round Management  
**Status**: `in-progress`  
**Phase**: MVP 1  
**Assumption**: Stories 5.1 (round config) and 5.2 (SQLite persistence) are being implemented in parallel or ahead. Their output (domain models, repository layer) is assumed available when this story's implementation runs.

---

## User Story

As a scorer, I want fast score entry for up to four golfers so that scoring does not slow play.

---

## Acceptance Criteria

| # | Criterion | Verification approach |
|---|-----------|----------------------|
| AC-1 | Gross score is the primary entry; putts, penalties, fairway, GIR, bunker, and notes are available progressively | Manual: tap gross → tap other fields to expand; unit test: progressiveDisclosureState enum transitions |
| AC-2 | Frequent score actions take no more than two taps and have 44/48dp touch targets | Manual: measure tap count from scorecard screen; automated: verify tap targets ≥44dp via FlutterWidgetTest |
| AC-3 | Score indicators do not rely on color alone | Manual: inspect scorecard in grayscale mode; automated: semantic label exists on every score widget |

---

## Domain Model — Changes/Additions

### New: `Flight` (in `packages/domain/`)

```
Flight
  id: UUID
  roundId: UUID  (FK → Round)
  flightIndex: int          // 1-based, e.g. flight 1 of the day)
  playerIds: List<UUID>     // 1–4 players
  createdAt: DateTime
  updatedAt: DateTime
```

**Assumption**: Round from story 5.1 has `flightIds: List<FlightId>`. If Round is not yet available, stub `FlightRoundRef` with just `id` and `roundId` for this story's scope.

### New: `Score` (in `packages/domain/`)

```
Score
  id: UUID
  flightId: UUID   (FK → Flight)
  holeId: UUID     (FK → Hole, from story 3.1)
  playerId: UUID   (FK → Player)
  // Primary entry
  grossScore: int?       // null until entered; 1–15 (or course par+10)
  // Progressive fields
  putts: int?            // 0–15
  penalties: int?        // 0–10
  fairwayHit: Bool?      // true/false/null (for par-3: null treated as N/A)
  gir: Bool?             // green-in-regulation
  bunker: Bool?          // hit from bunker
  notes: String?         // free text, max 200 chars
  // Metadata
  enteredAt: DateTime?
  syncStatus: SyncStatus  // local | pending | synced | conflict
  version: int           // optimistic concurrency
  updatedAt: DateTime
```

**Constraint**: Exactly one `Score` per (flightId, holeId, playerId) tuple.

**Validation**:
- `grossScore` nullable (not all holes may be played), but if set: 1 ≤ grossScore ≤ 30
- `putts` ≥ 0, ≤ 15
- `penalties` ≥ 0, ≤ 10
- At least one of (fairwayHit, gir) meaningful only for holes where applicable

### New: `ScorecardState` (UI state, not persisted)

```
ScorecardState
  flightId: UUID
  holeIds: List<UUID>   // ordered 1–18 (or subset)
  scores: Map<playerId, Map<holeId, Score>>
  currentHoleIndex: int
```

---

## Slice Plan

### Slice 1 — Domain Models & Contracts
**Goal**: Define `Flight`, `Score` domain entities and their OpenAPI/DTO contracts. No UI yet.

**Files**:
- `packages/domain/lib/src/round/` — add `flight.dart`
- `packages/domain/lib/src/score/` — add `score.dart`, `score_value_objects.dart`
- `packages/contracts/lib/src/` — add flight/score DTOs (`flight_dto.dart`, `score_dto.dart`)
- `apps/api/lib/modules/round/` — stub `FlightModule` (or add to existing RoundModule)
- `apps/api/lib/modules/score/` — add `ScoreModule` bounded module
- `docs/implementation-artifacts/epic-05/5-3-enter-scores-for-a-flight.md` — update File List

**Acceptance**: Domain entities compile, DTOs serialize/deserialize correctly.

---

### Slice 2 — Score Persistence (SQLite)
**Goal**: Persist `Score` and `Flight` to local SQLite. Depends on story 5.2's SQLite infrastructure being available (or stubbed).

**Files**:
- `apps/mobile/lib/data/local/tables/` — add `flights_table.dart`, `scores_table.dart`
- `apps/mobile/lib/data/local/daos/` — add `flight_dao.dart`, `score_dao.dart`
- `apps/mobile/lib/data/repositories/` — add `score_repository_impl.dart`
- `apps/mobile/lib/domain/repositories/` — add `score_repository.dart` (interface in `packages/domain/`)
- `apps/mobile/test/` — add `score_dao_test.dart`, `score_repository_test.dart`

**Schema** (SQLite):
```sql
CREATE TABLE flights (
  id TEXT PRIMARY KEY,
  round_id TEXT NOT NULL,
  flight_index INTEGER NOT NULL,
  player_ids TEXT NOT NULL,  -- JSON array of UUIDs
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE scores (
  id TEXT PRIMARY KEY,
  flight_id TEXT NOT NULL,
  hole_id TEXT NOT NULL,
  player_id TEXT NOT NULL,
  gross_score INTEGER,
  putts INTEGER,
  penalties INTEGER,
  fairway_hit INTEGER,   -- 1=true, 0=false, null=unset
  gir INTEGER,
  bunker INTEGER,
  notes TEXT,
  entered_at INTEGER,
  sync_status TEXT NOT NULL DEFAULT 'local',
  version INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  UNIQUE(flight_id, hole_id, player_id)
);
```

**Acceptance**: CRUD for Score via DAO; Scorecard state survives app restart via story 5.2 recovery path.

---

### Slice 3 — Score Entry UI (Primary Flow)
**Goal**: Scorecard screen — per-hole, per-player gross score entry in ≤2 taps.

**Files**:
- `apps/mobile/lib/presentation/screens/score/` — add `scorecard_screen.dart`
- `apps/mobile/lib/presentation/widgets/score/` — add `score_entry_card.dart`, `player_score_row.dart`, `hole_score_header.dart`
- `apps/mobile/lib/presentation/widgets/common/` — add `offline_indicator.dart` (reusable)
- `apps/mobile/lib/application/score/` — add `scorecard_cubit.dart`, `scorecard_state.dart`
- `apps/mobile/lib/application/score/` — add `hole_score_cubit.dart`, `hole_score_state.dart`
- `apps/mobile/test/presentation/` — add `scorecard_screen_test.dart`

**UI Layout**:
```
┌─────────────────────────────────┐
│  Hole 5  Par 4    [Offline ●]  │  ← Header: hole#, par, sync state (icon+label)
├─────────────────────────────────┤
│  [Player 1]  ●●●○  [−] [4] [+] │  ← Gross score: large tap targets, +/- buttons
│  [Player 2]  ●○○○  [−] [3] [+] │  ← Score indicator: filled/empty circles (NOT color-only)
│  [Player 3]  ────  [−] [–] [+] │  ← Dashes = not yet played
│  [Player 4]  ●●○○  [−] [5] [+] │
├─────────────────────────────────┤
│  Putts  Fairway  GIR  Bunker   │  ← Progressive disclosure row (swipe or tap to expand)
│  [2]    [✓]     [✓]  [○]      │
├─────────────────────────────────┤
│  Notes: ___________________     │
├─────────────────────────────────┤
│  [← Prev Hole]   [Next Hole →] │
└─────────────────────────────────┘
```

**Two-tap flow** (gross score):
1. Tap player row → expand inline controls (1 tap if already expanded)
2. Tap `+` or `−` → score changes (2nd tap or hold for ±1 per 200ms)
OR: tap gross score number → numeric keypad appears → enter directly

**Touch targets**: all buttons ≥44×44pt (iOS) / 48×48dp (Android).

**Score indicator** (non-color-only):
- Filled circle ● = score entered
- Empty circle ○ = not entered  
- Dash — = hole not played / not applicable
- Also shows actual score number alongside icon (not color alone)

**Offline state**: orange "Saved offline" chip with icon label visible in header.

**Acceptance**: Screen renders; gross score enters in ≤2 taps; app restart restores last state (via 5.2).

---

### Slice 4 — Progressive Disclosure (Secondary Fields)
**Goal**: Putts, penalties, fairway, GIR, bunker, notes — accessible but not primary.

**Files**:
- `apps/mobile/lib/presentation/widgets/score/` — add `progressive_score_field.dart`, `fairway_gir_toggle.dart`, `bunker_toggle.dart`
- `apps/mobile/test/` — add `progressive_disclosure_test.dart`

**Behavior**:
- Primary view shows only gross score and score-status indicator.
- Tap "More" or swipe up → reveals putts, penalties (numeric stepper each).
- Tap "Stats" → reveals fairway hit (✓/✗), GIR (✓/✗), bunker (✓/✗).
- Notes field always accessible via icon in player row.
- Progressive fields animate in (150–200ms, subtle).

**Acceptance**: Secondary fields visible within 1 additional tap from primary score view.

---

### Slice 5 — Accessibility & UX Compliance
**Goal**: Verify all accessibility requirements from AC-2, AC-3, and ux-spec §10.

**Files**:
- All widget files updated with `Semantics` labels
- `apps/mobile/test/` — add `score_accessibility_test.dart`

**Checks**:
- Every tappable control has a semantic label ("Increase score for Player 1", "Hole 5 gross score: 4").
- Score indicators have text alternatives ("Score entered: 4", "Score not entered").
- Touch targets measured ≥44dp in widget tests.
- Grayscale test: all score states distinguishable without color.
- Screen reader: tab order follows visual order.

---

### Slice 6 — Round Hole Navigation
**Goal**: Navigate between holes within active round.

**Files**:
- `apps/mobile/lib/application/score/` — update `scorecard_cubit.dart` to handle hole navigation
- Add `hole_navigation_bar.dart` widget

**Behavior**:
- Tap "← Prev Hole" / "Next Hole →" advances hole and saves current hole's scores.
- Shows current hole index / total (e.g., "Hole 5 of 18").
- After hole 18, "Complete Round" CTA.
- Navigation persists position in SQLite per story 5.2.

---

### Slice 7 — Integration & Full Round Flow
**Goal**: Scorecard end-to-end with a configured round (assuming 5.1 done).

**Files**:
- `apps/mobile/test/integration/` — add `scorecard_integration_test.dart`

**Tests**:
- Start round (5.1) → enter scores hole 1–18 → verify all scores in SQLite → complete round (5.5).
- Offline: enter scores → go offline → restart app → verify scores recovered.

---

## Dependency Map

```
Story 5.1 (configure/start round)
    └── Round, Player models available
          │
Story 5.2 (persist round locally)
    └── SQLite infrastructure, app restart recovery
          │
          ▼
    Story 5.3 (enter scores) ◄── needs both 5.1 + 5.2
          │
          ├── Slice 1 (domain/contracts)     ← independent
          ├── Slice 2 (SQLite persistence)    ← needs 5.2 SQLite infra
          ├── Slice 3 (score entry UI)        ← needs Slice 1, 2
          ├── Slice 4 (progressive fields)    ← needs Slice 3
          ├── Slice 5 (accessibility)         ← crosscuts all
          ├── Slice 6 (hole navigation)       ← needs Slice 3
          └── Slice 7 (integration)            ← needs all
```

---

## Verification Checklist

| Criterion | Method |
|-----------|--------|
| Gross score primary, 2 taps | Manual tap-count + widget test |
| 44/48dp touch targets | Flutter widget test with `tester.getSize()` |
| Non-color-only indicators | Semantics test + grayscale manual |
| Progressive disclosure | UI test: find secondary fields after 1 tap |
| Offline persistence | Restart test: scores survive app kill |
| Hole navigation | Integration test: hole 1→18→complete |
| Score validation | Unit test: invalid gross score rejected |
| Sync status written | DAO test: score written with sync_status=local |
| Screen reader | `flutter test --accessibility` or manual |
| All ACs documented | Each AC has ≥1 automated test |

---

## Files to Create/Modify

### New files
```
apps/mobile/lib/domain/repositories/score_repository.dart       # interface
apps/mobile/lib/data/local/tables/flights_table.dart
apps/mobile/lib/data/local/tables/scores_table.dart
apps/mobile/lib/data/local/daos/flight_dao.dart
apps/mobile/lib/data/local/daos/score_dao.dart
apps/mobile/lib/data/repositories/score_repository_impl.dart
apps/mobile/lib/application/score/scorecard_cubit.dart
apps/mobile/lib/application/score/scorecard_state.dart
apps/mobile/lib/application/score/hole_score_cubit.dart
apps/mobile/lib/application/score/hole_score_state.dart
apps/mobile/lib/presentation/screens/score/scorecard_screen.dart
apps/mobile/lib/presentation/widgets/score/score_entry_card.dart
apps/mobile/lib/presentation/widgets/score/player_score_row.dart
apps/mobile/lib/presentation/widgets/score/hole_score_header.dart
apps/mobile/lib/presentation/widgets/score/progressive_score_field.dart
apps/mobile/lib/presentation/widgets/score/fairway_gir_toggle.dart
apps/mobile/lib/presentation/widgets/score/bunker_toggle.dart
apps/mobile/lib/presentation/widgets/score/hole_navigation_bar.dart
apps/mobile/lib/presentation/widgets/common/offline_indicator.dart
packages/domain/lib/src/score/                                 # Score entity + value objects
packages/domain/lib/src/round/flight.dart                      # Flight entity
packages/contracts/lib/src/dto/flight_dto.dart
packages/contracts/lib/src/dto/score_dto.dart
apps/api/lib/modules/score/                                    # ScoreModule
apps/mobile/test/score_dao_test.dart
apps/mobile/test/score_repository_test.dart
apps/mobile/test/presentation/scorecard_screen_test.dart
apps/mobile/test/progressive_disclosure_test.dart
apps/mobile/test/score_accessibility_test.dart
apps/mobile/test/integration/scorecard_integration_test.dart
```

### Modify existing files
```
apps/mobile/lib/main.dart                         # route for /scorecard
apps/mobile/lib/navigation/app_router.dart       # add ScorecardRoute
packages/domain/lib/domain.dart                   # export Flight, Score
packages/contracts/lib/contracts.dart             # export FlightDto, ScoreDto
apps/mobile/pubspec.yaml                         # add any needed test dependencies
```

---

## Open Risks / Assumptions

| Risk | Mitigation |
|------|-----------|
| 5.1 and 5.2 not yet implemented | Build against interfaces defined here; stub implementations for unit tests |
| Round → Flight relationship not yet modeled | Define `Flight.roundId` FK; coordinate with 5.1 implementer on Round model |
| Score → Hole FK depends on story 3.1 | Story 3.1 is done; holeId UUIDs assumed available |
| API sync deferred to 5.4 | Score.syncStatus='local' written now; sync worker in 5.4 |
| Tournament mode restrictions | Flag in ScorecardState; UI respects mode from 5.1 config |

---

## Slice Execution Order

1. **Slice 1** (domain) — no dependencies, start here
2. **Slice 2** (SQLite persistence) — needs 5.2 SQLite setup; stub if not ready
3. **Slice 3** (score entry UI — gross score) — needs Slice 1
4. **Slice 4** (progressive disclosure) — needs Slice 3
5. **Slice 5** (accessibility) — crosscut; run alongside Slice 3
6. **Slice 6** (hole navigation) — needs Slice 3
7. **Slice 7** (integration) — needs all prior slices

**Parallelization**: Slice 1 can start immediately. Slices 2–7 depend on 5.1/5.2 progress; coordinate with that stream.
