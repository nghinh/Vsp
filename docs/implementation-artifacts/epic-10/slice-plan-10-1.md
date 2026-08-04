# Slice Plan: Story 10.1 — Deliver Apple Watch Core Round Experience

## Story Metadata
- **Story ID:** 10.1
- **Epic:** 10 (Smartwatch and Shot Tracking)
- **Phase:** MVP 2–3
- **Story File:** `docs/implementation-artifacts/epic-10/10-1-deliver-apple-watch-core-round-experience.md`
- **Status:** `in-progress`
- **Plan Date:** 2026-08-02

## Context Summary

### Source Documents
| Document | Key Inputs for 10.1 |
|----------|---------------------|
| PRD §12 Phase 2 | Apple Watch, Mini 2D map, Watch target control, Quick score |
| Architecture §15 | Watch adapter boundary (deferred hook, NOW being implemented) |
| UX-Spec §4 | Glanceable ≤2s, one-hand, two-tap, 44pt touch, semantic tokens, dark mode |
| Epic 10 (§597-609) | Watch shows hole/par/score, FCB, pin/hazard, navigation, quick score; offline 18-hole; crown/touch accessibility+battery |
| Story Dev Notes | Flutter+MapLibre+local-first preserved; no AI/analytics/tournament scope |

### Story ACs (acceptance criteria)
| AC | Description |
|----|-------------|
| AC-1 | Watch displays hole number, par, current score |
| AC-2 | Watch displays front-center-back distances to green |
| AC-3 | Watch displays pin position and hazard distances |
| AC-4 | Watch provides navigation between holes |
| AC-5 | Watch provides quick score entry |
| AC-6 | Offline course subset supports a full 18-hole round |
| AC-7 | Crown/touch controls meet platform accessibility and battery requirements |

## Slice Plan

### Slice 1: Watch Adapter Boundary & Data Contracts
**Goal:** Establish the watch-host communication layer and shared data contracts.

- Define `WatchRoundSession` domain model (hole, par, player scores, GPS state)
- Define `WatchDistanceData` contract (FCB, pin, hazards, confidence)
- Define `WatchScoreEntry` contract (player, hole, score, putts, penalties)
- Create watch repository interface in shared domain layer
- Add watch-specific DTOs to contracts package
- Define local persistence schema for watch offline round data

**Files:**
- `packages/domain/lib/src/round/watch_round_session.dart` (new)
- `packages/domain/lib/src/round/watch_distance_data.dart` (new)
- `packages/contracts/lib/src/dto/watch_dto.dart` (new)
- `packages/contracts/lib/src/schema/watch_persistence_schema.dart` (new)

---

### Slice 2: Watch UI Shell & Navigation
**Goal:** Build the watch app shell with glanceable primary distance panel.

- Create Flutter watch app scaffold (CupertinoWatchFurther or equivalent)
- Implement primary distance panel showing hole/par + FCB
- Implement watch navigation (next hole, prev hole, main menu)
- Integrate with existing round session state management
- Apply UX-Spec color tokens, typography (Fira Sans/Code), dark mode

**Files:**
- `apps/watch_apple/lib/main.dart` (new)
- `apps/watch_apple/lib/presentation/shell/watch_shell.dart` (new)
- `apps/watch_apple/lib/presentation/screens/distance_panel_screen.dart` (new)
- `apps/watch_apple/lib/presentation/widgets/distance_display.dart` (new)
- `apps/watch_apple/lib/presentation/widgets/hole_info_badge.dart` (new)
- `apps/watch_apple/lib/presentation/theme/watch_theme.dart` (new)

---

### Slice 3: Quick Score Entry
**Goal:** Enable score entry in ≤2 taps on watch.

- Implement score entry screen (player selector → score pad → confirm)
- Persist scores locally first (SQLite via watch local storage)
- Queue score events for idempotent sync
- Show confirmation and sync state

**Files:**
- `apps/watch_apple/lib/presentation/screens/score_entry_screen.dart` (new)
- `apps/watch_apple/lib/presentation/widgets/score_pad.dart` (new)
- `apps/watch_apple/lib/application/score_entry_notifier.dart` (new)
- `apps/watch_apple/lib/infrastructure/local/watch_score_repository.dart` (new)

---

### Slice 4: Offline Course Subset for Watch
**Goal:** Subset of course data sufficient for 18-hole watch-only round.

- Define watch package manifest (subset of full course package)
- Add watch package generation to backend package pipeline
- Add watch package download/management to mobile companion app
- Add watch package sync to watch app on pairing

**Files:**
- `packages/course_package/lib/src/watch_package_manifest.dart` (new)
- `apps/api/lib/src/modules/package/watch_package_generator.dart` (new)
- `apps/mobile/lib/application/watch_package_notifier.dart` (new)
- `apps/mobile/lib/presentation/screens/watch_pairing_screen.dart` (new)

---

### Slice 5: Crown/Touch Controls & Accessibility
**Goal:** Platform-compliant controls and battery-aware behavior.

- Implement crown digital crown → scroll holes / adjust target
- Implement touch → tap to select, swipe for navigation
- Battery-aware: reduce polling when stationary, reduce animations
- Accessibility: VoiceOver labels, Dynamic Type, reduced motion

**Files:**
- `apps/watch_apple/lib/application/crown_input_handler.dart` (new)
- `apps/watch_apple/lib/presentation/widgets/accessibility_wrapper.dart` (new)
- `apps/watch_apple/lib/application/battery_manager.dart` (new)

---

### Slice 6: End-to-End Integration & Tests
**Goal:** Prove full watch round loop works offline and syncs correctly.

- Integration test: start watch round → play 18 holes → score entry → sync
- Test offline restart recovery
- Test GPS confidence state on watch
- Test accessibility audit

**Files:**
- `apps/watch_apple/test/e2e/watch_round_e2e_test.dart` (new)
- `apps/watch_apple/test/unit/crown_input_test.dart` (new)
- `apps/watch_apple/test/unit/watch_score_sync_test.dart` (new)

---

## Verification Gates

| Gate | Criteria |
|------|----------|
| Format | `flutter format apps/watch_apple` passes |
| Lint | `flutter analyze apps/watch_apple` passes |
| Typecheck | `dart analyze` passes |
| Unit Tests | All new unit tests pass |
| E2E Test | Watch round E2E passes |
| Accessibility | VoiceOver audit passes; Dynamic Type ≤20sp |
| Offline | Round survives app restart with no data loss |
| Sync | Score events replay idempotently to backend |

## Dependency Evidence

- **Epic 10 stories 10.1-10.4** depend on Epic 5 (Round Setup, Scoring), Epic 6 (GPS/Distance), Epic 4 (Course Packages) foundations.
- Story 10.1 specifically depends on: round session model, distance calculation engine, course package manifest, local persistence.
- **Contradiction noted:** sprint-status.yaml shows `epic-10` and `10-1` as `backlog`, but user dispatch says `ready-for-dev`. Following user dispatch; epic-10 may need status update.

## Non-Scope (Explicitly Excluded)

- AI/Smart Caddie features (Epic 11)
- Wear OS equivalent (Story 10.2)
- Shot tracking (Stories 10.3-10.4)
- Tournament platform features (Epic 12)
- Full MapLibre watch map (deferred to post-MVP Watch)

## Execution Notes

1. Start with Slice 1 (contracts) as it is the foundation for all other slices
2. Slice 2 (UI Shell) and Slice 3 (Score Entry) can run in parallel after Slice 1
3. Slice 4 (Offline) requires backend coordination; run as wave 2
4. Slice 5 (Accessibility) is cross-cutting, integrate throughout
5. Slice 6 (E2E) is final gate before review

---

**Evidence:**
- PRD §12 Phase 2 read (Apple Watch scope)
- Architecture §15 deferred hooks confirmed as now being implemented
- UX-Spec §4 design tokens and accessibility requirements extracted
- Epic 10 story breakdown read
- sprint-status.yaml checked (epic-10/10-1 currently backlog, updating to in-progress per dispatch)
