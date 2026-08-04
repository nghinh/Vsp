# Slice Plan — Story 9.1: Submit Correction Offline

## Story Metadata

| Field | Value |
|---|---|
| Story | 9.1 |
| Epic | 9 — Data Quality |
| Title | Submit Correction Offline |
| Status (before) | `ready-for-dev` |
| Run Folder | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |

---

## Context Summary

### What This Story Is
A golfer on the course encounters incorrect official data (wrong pin position, wrong hazard geometry, wrong hole, wrong green boundary, etc.) and reports it without interrupting play. The report must work offline and sync when connectivity returns. The portal receives the report for review (story 9.2).

### What This Story Is NOT
- Score correction (story 5.5 — already implemented via `CorrectionDialog` in `features/round/`)
- Correction review (story 9.2)
- Correction resolution (story 9.3)
- Data quality monitoring (story 9.4)

### Existing Foundation
| Layer | What Exists |
|---|---|
| Domain | `Correction` model in `features/round/domain/correction.dart` — for **score** corrections only |
| Sync | `SyncEvent` + `SyncStatus` + `SyncEventType` in `domain/models/` — score/round events, needs `correctionSubmit` type |
| SQLite | `ScoreDao`, `FlightDao`, `HoleSelectionLogDao` — table pattern established |
| Sync queue | `SyncEvent` queued via `QueuedRoundUpdate` — same queue carries score and round events |
| Location | `QualifiedLocation` + `LocationService` — GPS accuracy and stale state available |
| Auth | Existing token auth in `EncryptedStorage` |
| Design system | `mobile-theme` package with semantic color tokens, Fira Sans/Code typography |

### Key Architectural Decisions

1. **CourseCorrection ≠ ScoreCorrection**: New domain model separate from `features/round/domain/correction.dart`.
2. **Same sync queue**: Extend `SyncEventType` with `correctionSubmit` — reuses existing retry/backoff/idempotency mechanics.
3. **Offline-first writes**: `CourseCorrection` is written to SQLite before the sync worker attempts delivery.
4. **No photo upload in MVP**: AC says "optional photo" — photo capture deferred unless trivial; note field is MVP scope.
5. **Issue types**: Defined as enum covering the course-data quality loop: `pinPosition`, `holeGeometry`, `hazardShape`, `greenBoundary`, `teePosition`, `fairwayShape`, `otherCourseData`.

---

## Acceptance Criteria Mapping

| AC | Implementation |
|---|---|
| User selects issue type | `CorrectionIssueType` enum; picker/dropdown in form |
| App captures course | `CourseCorrection.courseId` — resolved from active round context or course package |
| App captures hole | `CourseCorrection.holeId` — optional; captured if a round is active |
| App captures location | `CourseCorrection.reporterLocation` — `QualifiedLocation` (lat/lng/accuracy) |
| App captures accuracy | `CourseCorrection.gpsAccuracy` — meters from `QualifiedLocation` |
| App captures timestamp | `CourseCorrection.submittedAt` — UTC timestamp at submission |
| Optional photo | Deferred (no-op in MVP; stub for future) |
| Optional note | `CourseCorrection.note` — free text, max 500 chars |
| Saves offline | SQLite insert via `CorrectionDao` before sync worker pickup |
| Syncs via local event queue | `SyncEventType.correctionSubmit` + `SyncEvent.forCorrection()` factory |
| User sees pending/submitted/accepted/rejected | `CorrectionSyncState` enum + `CorrectionListScreen` showing all user corrections |

---

## Slice Plan

### Slice 1 — Domain Model + DTO + SQLite Schema

**Goal**: Define the `CourseCorrection` entity, its DTO contract, and SQLite persistence layer.

**Files to create**:
- `apps/mobile/lib/features/correction/domain/course_correction.dart`
  - `CorrectionIssueType` enum (pinPosition, holeGeometry, hazardShape, greenBoundary, teePosition, fairwayShape, otherCourseData)
  - `CorrectionSyncState` enum (pending, submitted, accepted, rejected)
  - `CourseCorrection` class with all required fields (id, courseId, holeId, issueType, reporterLat, reporterLng, gpsAccuracy, submittedAt, note, syncState, idempotencyKey)
  - JSON serialization (toMap/fromMap/toJson/fromJson)
  - SQLite row serialization (toMap/fromMap for DAO)
- `packages/contracts/lib/src/dto/course_correction_dto.dart`
  - API request DTO matching the domain model fields
  - JSON serialization
- `apps/mobile/lib/data/local/tables/corrections_table.dart`
  - `kCorrectionsTableName`, `kCorrectionsTableCreateSql`, indexes
- `apps/mobile/lib/data/local/daos/correction_dao.dart`
  - CRUD: upsert, getById, getBySyncState, updateSyncState, getByCourseId

**Verification**: Unit tests for `CourseCorrection` serialization round-trips and `CorrectionDao` query methods.

---

### Slice 2 — Sync Event Extension + Repository

**Goal**: Add `correctionSubmit` to the sync event type system and implement the offline-first repository.

**Files to create/modify**:
- `apps/mobile/lib/domain/models/sync_event.dart`
  - Add `correctionSubmit` to `SyncEventType` enum
  - Add `SyncEvent.forCorrection()` factory constructor
- `apps/mobile/lib/data/repositories/course_correction_repository.dart`
  - Interface (abstract class) + implementation
  - `submitCorrection(CourseCorrection)` → inserts to SQLite + returns pending `SyncEvent`
  - `getCorrectionsByState(CorrectionSyncState)` → queries DAO
  - `getCorrectionsForCourse(String courseId)` → queries DAO
  - `updateCorrectionSyncState(String id, CorrectionSyncState)` → updates DAO

**Files to modify**:
- `apps/mobile/lib/domain/models/sync_event.dart` — add enum value and factory (no other changes)

**Verification**: Unit tests for `SyncEventType.correctionSubmit` round-trip and repository mock tests.

---

### Slice 3 — Submission UI: Form Screen

**Goal**: Correction submission form — accessible from active round "Report Correction" shortcut.

**Files to create**:
- `apps/mobile/lib/features/correction/presentation/correction_submission_screen.dart`
  - Full-screen form with:
    - Issue type selector (segmented button or dropdown)
    - Captured location display (read-only, auto-filled from GPS)
    - GPS accuracy indicator (color-coded: green <5m, amber 5–10m, red >10m)
    - Note text field (max 500 chars, optional)
    - Submit button (saves offline, shows confirmation)
  - Accessible: semantic labels, 44pt touch targets, screen reader support
  - Offline-aware: always enabled; shows "Saved offline" confirmation on success
- `apps/mobile/lib/features/correction/presentation/correction_submission_bloc.dart`
  - Events: `SubmitCorrection`, `LoadCorrectionForm`
  - States: `CorrectionSubmissionInitial`, `CorrectionSubmissionLoading`, `CorrectionSubmissionSuccess`, `CorrectionSubmissionFailure`
  - Uses `CourseCorrectionRepository` + `LocationService`
- `apps/mobile/lib/features/correction/correction.dart`
  - Barrel export for the feature

**Files to modify**:
- `apps/mobile/lib/features/round/presentation/active_round_screen.dart`
  - Wire the existing "Report Correction" shortcut button to open `CorrectionSubmissionScreen`
  - Pass active `courseId`, `holeId` to the screen

**Verification**: Widget tests for form rendering, state transitions, accessibility labels.

---

### Slice 4 — My Corrections List Screen

**Goal**: User can view their submitted corrections and see sync state (pending/submitted/accepted/rejected).

**Files to create**:
- `apps/mobile/lib/features/correction/presentation/correction_list_screen.dart`
  - List of `CourseCorrection` for the current user
  - Each item shows: issue type badge, course name, hole (if applicable), sync state chip, timestamp
  - Empty state: "No corrections submitted yet"
  - Pull-to-refresh: checks sync queue status and refreshes list from local DB
- `apps/mobile/lib/features/correction/presentation/correction_list_bloc.dart`
  - Events: `LoadCorrections`, `RefreshCorrections`
  - States: `CorrectionListLoading`, `CorrectionListLoaded`, `CorrectionListEmpty`, `CorrectionListError`

**Entry point**: Accessible from "More" bottom nav or profile section.

**Verification**: Widget tests for list rendering, empty state, pull-to-refresh behavior.

---

### Slice 5 — Correction Sync State Update Hook

**Goal**: When the sync worker processes a `correctionSubmit` event and receives server confirmation, update the local `CorrectionSyncState` from `pending` → `submitted`. Also handle server-side status push (accepted/rejected) from story 9.2.

**Files to modify**:
- `apps/mobile/lib/data/repositories/course_correction_repository.dart`
  - Add `onSyncComplete(String idempotencyKey)` method
  - Add `onServerStatusUpdate(String correctionId, CorrectionSyncState)` method
- Sync worker / round state service: wire correction state transitions

**Note**: Server-side accepted/rejected updates come via push notification or on-demand poll — this slice handles the local state update hook. Actual push/polling is out of scope for story 9.1.

---

## File List (Summary)

### New files
```
apps/mobile/lib/features/correction/
  correction.dart                                  # barrel export
  domain/
    course_correction.dart                        # domain model + enums
  data/
    local/
      tables/corrections_table.dart               # SQLite schema
      daos/correction_dao.dart                   # SQLite CRUD
    repositories/course_correction_repository.dart # offline-first repo
  presentation/
    correction_submission_screen.dart              # form UI
    correction_submission_bloc.dart                # form state management
    correction_list_screen.dart                    # my corrections list UI
    correction_list_bloc.dart                     # list state management
packages/contracts/lib/src/dto/course_correction_dto.dart  # API contract
apps/mobile/test/features/correction/
  domain/course_correction_test.dart
  data/local/daos/correction_dao_test.dart
  presentation/correction_submission_bloc_test.dart
  presentation/correction_list_bloc_test.dart
```

### Modified files
```
apps/mobile/lib/domain/models/sync_event.dart          # +correctionSubmit type + factory
apps/mobile/lib/features/round/presentation/active_round_screen.dart  # wire shortcut
```

---

## Validation Gate

| Gate | Command |
|---|---|
| Format | `flutter format apps/mobile/lib apps/mobile/test` |
| Dart analyze | `flutter analyze apps/mobile/lib apps/mobile/test` |
| Unit tests | `flutter test apps/mobile/test/features/correction/` |
| Integration | Manual: submit correction offline, restart app, verify sync state |

---

## Dependencies on Earlier Stories

- **Epic 5 (Round Management)**: Active round context (`courseId`, `holeId`) needed for auto-fill — story 5.1/5.2 must be done or correction form falls back to manual entry.
- **Epic 6 (GPS)**: `LocationService` and `QualifiedLocation` already done (story 6.1 done).
- **Epic 3 (Course Model)**: `Course` entity and `CourseRepository` already exist.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| No backend API for corrections yet | Design DTOs for the API contract; mobile stores locally; sync worker queues events. Backend integration is a separate concern. |
| Photo capture deferred | No-op for MVP; struct is designed for future `photoPath` field addition |
| Active round context not available | Form accepts manual courseId/holeId entry if no active round |
