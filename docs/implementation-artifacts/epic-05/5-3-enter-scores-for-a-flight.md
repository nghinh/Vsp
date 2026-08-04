---
story: "5.3"
epic: 5
title: "Enter Scores for a Flight"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 5.3: Enter Scores for a Flight

## User Story

As a scorer, I want fast score entry for up to four golfers so that scoring does not slow play.

## Acceptance Criteria

- Gross score is the primary entry; putts, penalties, fairway, GIR, bunker, and notes are available progressively.
- Frequent score actions take no more than two taps and have 44/48dp touch targets.
- Score indicators do not rely on color alone.

## Tasks and Subtasks

- [x] Confirm the enter scores for a flight scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 5.2 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where applicable.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Dev Agent Record

### Implementation Notes
Slices 2 (SQLite persistence), 3 (Score Entry UI), and 4 (Progressive Disclosure) completed.

**Slice 2 (Score SQLite Persistence):**
- `data/local/tables/flights_table.dart` — SQL table definition constants (kFlightsTableCreateSql, kFlightsTableRoundIndexSql)
- `data/local/tables/scores_table.dart` — SQL table definition constants (kScoresTableCreateSql, kScoresTableFlightHoleIndexSql, kScoresTableFlightPlayerIndexSql)
- `data/local/daos/flight_dao.dart` — FlightDao with insert/update/delete/getById/getByRoundId
- `data/local/daos/score_dao.dart` — ScoreDao with upsert/update/delete/getById/getByFlightHolePlayer/getByFlightAndHole/getByFlightAndPlayer/getByFlightId/getBySyncStatus
- `domain/repositories/score_repository.dart` — ScoreRepository interface (abstract)
- `data/repositories/score_repository_impl.dart` — ScoreRepositoryImpl using ScoreDao

**Slice 3 (Score Entry UI):**
- `application/score/hole_score_state.dart` — HoleScoreState for single-hole score form
- `application/score/hole_score_cubit.dart` — HoleScoreCubit for single-hole score entry
- `application/score/scorecard_state.dart` — ScorecardScreenState for full scorecard
- `application/score/scorecard_cubit.dart` — ScorecardCubit for full scorecard management
- `presentation/widgets/common/offline_indicator.dart` — OfflineIndicator (icon+text, non-color-only)
- `presentation/widgets/score/hole_score_header.dart` — HoleScoreHeader (hole#, par, sync state)
- `presentation/widgets/score/player_score_row.dart` — PlayerScoreRow (shapes+text indicators, ±44pt touch targets)
- `presentation/widgets/score/score_entry_card.dart` — ScoreEntryCard wrapping all player rows
- `presentation/widgets/score/hole_navigation_bar.dart` — HoleNavigationBar (prev/next/complete)
- `presentation/screens/score/scorecard_screen.dart` — ScorecardScreen with score keypad modal

**Slice 4 (Progressive Disclosure):**
- `presentation/widgets/score/progressive_score_field.dart` — ProgressiveScoreField (putts/penalties steppers) + ProgressiveReveal (animated container)
- `presentation/widgets/score/fairway_gir_toggle.dart` — StatToggle (yes/no toggle) + FairwayGirToggles (combined fairway/GIR panel)
- `presentation/widgets/score/bunker_toggle.dart` — BunkerToggle widget
- `presentation/widgets/score/progressive_disclosure_panel.dart` — ProgressiveDisclosurePanel combining all progressive fields
- `application/score/scorecard_cubit.dart` — Extended with progressive field update methods (increment/decrement putts, penalties, setFairwayHit, setGir, setBunker, setNotes)
- `presentation/widgets/score/score_entry_card.dart` — Updated to support progressive disclosure expansion
- `presentation/screens/score/scorecard_screen.dart` — Updated _ScorecardBody with progressive callbacks + _NotesBottomSheet

**Key Design Decisions:**
- DAOs use vsp_round.db (shared with 5.2 RoundRepository/HoleScoreRepository)
- Score upsert uses ConflictAlgorithm.replace for UNIQUE(flight_id, hole_id, player_id) constraint
- Score indicator: ●/○/— shapes with text label (non-color-only per AC-3)
- Touch targets: 44pt minimum (kMinTouchTarget constant)
- ScorecardCubit manages full scorecard; HoleScoreCubit manages single-hole form
- Score keypad modal for direct numeric entry
- Haptic feedback on score changes
- OfflineIndicator shows icon+label per accessibility requirements
- Progressive disclosure: tap player row to expand → reveals putts, penalties, fairway/GIR, bunker, notes
- ProgressiveReveal: 175ms animated size + opacity reveal
- StatToggle: yes/no buttons with ✓/✗ icons + text labels (non-color-only)
- Notes via bottom sheet with 200 char limit

**Dedup Gates:** All symbols passed PRE_WRITE and POST_WRITE gates
- ProgressiveScoreField, FairwayGirToggle, BunkerToggle — all passed pre+post gates
- ScoreAccessibilityTest, HoleNavigationCubitTest, ScorecardIntegrationTest — all passed pre+post gates
- Reindex: ok=true (external FTS index issue noted, not blocking)

**Slice 5 (Accessibility & UX Compliance):**
- `test/score_accessibility_test.dart` — Full accessibility test suite covering:
  - PlayerScoreRow: semantic labels for entered/notEntered/notPlayed states, touch targets ≥44dp, non-color-only indicators (●/○/—), grayscale distinguishability
  - HoleNavigationBar: hole progress semantic label, prev/next touch targets, complete round button semantics
  - ProgressiveScoreField: field semantic labels, increment/decrement button semantics, touch target verification
  - FairwayGirToggle: stat toggle semantic labels, yes/no button semantics, touch targets
  - OfflineIndicator: offline/syncing labels, icon+text non-color-only, grayscale test
  - Combined score indicators: all three states (●/○/—) distinguishable in grayscale

**Slice 6 (Hole Navigation):**
- `test/score_navigation_test.dart` — Navigation test suite covering:
  - Initial hole position (hole 1)
  - navigateToNextHole/PreviousHole navigation
  - navigateToHoleIndex for direct navigation
  - Boundary checks (can't go back at hole 1, can't go forward at hole 18)
  - Full 18-hole round navigation flow
  - Forward/backward navigation
  - Hole position persistence
  - Score entry during navigation

**Slice 7 (Integration & Full Round):**
- `test/integration/scorecard_integration_test.dart` — Integration test suite covering:
  - Full round flow (18 holes × 4 players score entry)
  - Offline flag set when scores entered
  - Sync status = local on score creation
  - loadScores recovers persisted scores on restart (offline persistence)
  - Score update after navigating away and back
  - Progressive fields (putts, penalties, fairway, GIR, bunker) integration
  - Hole navigation saves scores before moving
  - Offline recovery verification
  - Score validation (gross 1-30, putts 0-15, penalties 0-10)

## File List

### Slice 2 — Score SQLite Persistence (NEW)
- `apps/mobile/lib/data/local/tables/flights_table.dart` (new)
- `apps/mobile/lib/data/local/tables/scores_table.dart` (new)
- `apps/mobile/lib/data/local/daos/flight_dao.dart` (new)
- `apps/mobile/lib/data/local/daos/score_dao.dart` (new)
- `apps/mobile/lib/domain/repositories/score_repository.dart` (new)
- `apps/mobile/lib/data/repositories/score_repository_impl.dart` (new)

### Slice 3 — Score Entry UI (NEW)
- `apps/mobile/lib/application/score/hole_score_state.dart` (new)
- `apps/mobile/lib/application/score/hole_score_cubit.dart` (new)
- `apps/mobile/lib/application/score/scorecard_state.dart` (new)
- `apps/mobile/lib/application/score/scorecard_cubit.dart` (new)
- `apps/mobile/lib/presentation/widgets/common/offline_indicator.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/hole_score_header.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/player_score_row.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/score_entry_card.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/hole_navigation_bar.dart` (new)
- `apps/mobile/lib/presentation/screens/score/scorecard_screen.dart` (new)

### Slice 4 — Progressive Disclosure (NEW)
- `apps/mobile/lib/presentation/widgets/score/progressive_score_field.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/fairway_gir_toggle.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/bunker_toggle.dart` (new)
- `apps/mobile/lib/presentation/widgets/score/progressive_disclosure_panel.dart` (new)
- `apps/mobile/lib/application/score/scorecard_cubit.dart` (modified: added progressive field update methods)
- `apps/mobile/lib/presentation/widgets/score/score_entry_card.dart` (modified: progressive callback props + panel integration)
- `apps/mobile/lib/presentation/screens/score/scorecard_screen.dart` (modified: progressive callbacks + _NotesBottomSheet)

### Previously Implemented (Slice 1)
- `apps/mobile/lib/domain/models/flight.dart` (existing)
- `apps/mobile/lib/domain/models/score.dart` (existing)
- `apps/mobile/lib/domain/models/score_value_objects.dart` (existing)
- `apps/mobile/lib/domain/models/scorecard_state.dart` (existing)

### Slice 5 — Accessibility & UX Compliance (NEW)
- `apps/mobile/test/score_accessibility_test.dart` (new)

### Slice 6 — Hole Navigation (NEW)
- `apps/mobile/test/score_navigation_test.dart` (new)

### Slice 7 — Integration & Full Round (NEW)
- `apps/mobile/test/integration/scorecard_integration_test.dart` (new)

## Change Log
- 2026-08-02: Slices 2–3 — Added SQLite persistence (flights_table, scores_table, FlightDao, ScoreDao, ScoreRepository interface + impl) and Score Entry UI (ScorecardCubit, ScorecardScreen, PlayerScoreRow, HoleScoreHeader, OfflineIndicator, HoleNavigationBar, ScoreEntryCard). All dedup gates passed.
- 2026-08-02: Slice 4 — Added progressive disclosure widgets (ProgressiveScoreField, FairwayGirToggle, BunkerToggle, ProgressiveDisclosurePanel), extended ScorecardCubit with putts/penalties/fairway/GIR/bunker/notes update methods, integrated progressive panel into ScoreEntryCard, added _NotesBottomSheet to scorecard_screen. All dedup gates passed.
- 2026-08-02: Slices 5–7 — Added accessibility test suite (semantic labels, ≥44dp touch targets, non-color-only indicators, grayscale tests), hole navigation test suite (18-hole flow, prev/next/complete, boundary checks), and integration test suite (full round flow, offline persistence, score validation). Story status updated to done.

## Source References

- `docs/planning-artifacts/epics.md` — Story 5.3 and Epic 5
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `5-3-enter-scores-for-a-flight`
