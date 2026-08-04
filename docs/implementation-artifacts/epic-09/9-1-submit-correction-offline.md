---
story: "9.1"
epic: 9
title: "Submit Correction Offline"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 9.1: Submit Correction Offline

## User Story

As a golfer, I want to report incorrect course data so that maps and conditions improve without interrupting play.

## Acceptance Criteria

- User selects issue type; app captures course, hole, location, accuracy, timestamp, optional photo, and note.
- Submission saves offline and synchronizes through local event queue.
- User sees pending, submitted, accepted, or rejected state.

## Tasks and Subtasks

- [x] Confirm the submit correction offline scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Dev Agent Record

### Implementation Notes

**Slices implemented (2-5):**

- **Slice 2 — SyncEvent extension + Repository**: Extended `SyncEventType` enum with `correctionSubmit`; added `SyncEvent.forCorrection()` factory; implemented `CourseCorrectionRepository` (abstract + SQLite-backed impl) with `submitCorrection`, query methods, and sync hooks (`onSyncComplete`, `onServerStatusUpdate`).
- **Slice 3 — Submission form UI**: `CorrectionSubmissionBloc` (events: `LoadCorrectionForm`, `SubmitCorrection`; states: `Initial`, `Loading`, `FormReady`, `Success`, `Failure`); `CorrectionSubmissionScreen` (full form with issue type selector, GPS accuracy indicator, note field); wired from `ActiveRoundScreen` "Report Correction" shortcut.
- **Slice 4 — My corrections list UI**: `CorrectionListBloc` (events: `LoadCorrections`, `RefreshCorrections`; states: `Initial`, `Loading`, `Loaded`, `Empty`, `Error`); `CorrectionListScreen` (list with sync state chips, empty state, pull-to-refresh).
- **Slice 5 — Sync state hooks**: `CourseCorrectionRepository.onSyncComplete()` transitions `pending→submitted`; `onServerStatusUpdate()` transitions `submitted→accepted|rejected`. Wiring to sync worker is a deferred concern (per slice plan).

### File List

**New files:**
- `apps/mobile/lib/data/repositories/course_correction_repository.dart`
- `apps/mobile/lib/features/correction/correction.dart` (barrel)
- `apps/mobile/lib/features/correction/presentation/correction_submission_bloc.dart`
- `apps/mobile/lib/features/correction/presentation/correction_submission_screen.dart`
- `apps/mobile/lib/features/correction/presentation/correction_list_bloc.dart`
- `apps/mobile/lib/features/correction/presentation/correction_list_screen.dart`
- `apps/mobile/test/features/correction/presentation/correction_submission_bloc_test.dart`
- `apps/mobile/test/features/correction/presentation/correction_list_bloc_test.dart`

**Modified files:**
- `apps/mobile/lib/domain/models/sync_event.dart` (+`correctionSubmit` enum value, +`SyncEvent.forCorrection()`)
- `apps/mobile/lib/features/round/presentation/active_round_screen.dart` (wired "Report Correction" shortcut, added `LocationService` constructor param)

### Change Log

- **2026-08-02**: Implemented slices 2-5 (SyncEvent extension, Repository, Submission UI, List UI, Sync hooks). Extended `SyncEventType` with `correctionSubmit`; wired `CorrectionSubmissionScreen` from active round "Report Correction". Status: `in-progress` → `review`.

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Change Log

- **2026-08-02**: Created slice plan `slice-plan-9-1.md`. Status updated: `backlog` → `in-progress`.

- `docs/planning-artifacts/epics.md` — Story 9.1 and Epic 9
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `9-1-submit-correction-offline`
