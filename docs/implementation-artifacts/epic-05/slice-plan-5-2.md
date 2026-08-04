# Slice Plan — Story 5.2: Persist Round Locally

## Story Metadata

| Field | Value |
|-------|-------|
| Story | 5.2 |
| Epic | epic-05 — Round Management |
| Title | Persist Round Locally |
| Status | `in-progress` |
| Phase | MVP 1 |
| User Story | As a golfer, I want all round changes saved locally first so that network failures never lose my game. |

## Context Evidence

| Source | Evidence |
|--------|----------|
| PRD §8.10 | "Score data is persisted locally before sync" |
| PRD §10.5 | "Local persistence before sync; retry and idempotency support; no score loss during backend outage" |
| Architecture §8.2 | "SQLite for course metadata, downloaded package manifest, rounds, scores, local events, and sync cursors" |
| Architecture §8.3 | "All on-course writes are first persisted locally. Client writes append events to local event queue" |
| UX §6.4 | "Offline states: Saved offline. Sync when online." |
| UX §5.2 | "Scorecard — Save feedback immediate. Offline saved indicator visible." |
| Story 5.1 | Configure and start a round — creates the round configuration |
| Story 3.1 (done) | Course and golf geometry models (hole, tee, score structures) |
| BagSyncStore pattern | Existing SQLite sync queue pattern with idempotency keys, pending/synced states |
| ActiveRoundGuard | Existing SQLite DB pattern using `vsp_active_round.db` |

## Dependencies

- **Hard**: Story 5.1 (in-progress) — round configuration output required to create a round
- **Soft**: Story 3.1 (done) — hole/score domain models for structure
- **Soft**: BagSyncStore pattern (existing) — same SQLite sync queue pattern to reuse

## Acceptance Criteria

| AC | Description | Verification |
|----|-------------|--------------|
| AC-1 | Round, hole, player, score, and sync event changes are transactionally persisted in SQLite | Round state changes written in a single SQLite transaction; no partial writes |
| AC-2 | App restart restores an incomplete round | After force-kill and relaunch, active round with all scores is recoverable |
| AC-3 | UI immediately confirms offline save state | Visual indicator shows "Saved" after each write before sync |

## Slice Plan

### Slice 1 — PERSIST-MODELS: Round Domain Models
**Owner**: Mobile (Domain)
**Phase**: Foundation — no external dependencies

Defines the core domain models needed for local round persistence:

1. **Round model** (`domain/models/round.dart`):
   - `id: String` (UUID, local identifier)
   - `courseId: int`
   - `courseName: String` (denormalized from course package)
   - `status: RoundStatus` enum: `inProgress`, `completed`, `abandoned`, `cancelled`
   - `startedAt: DateTime`
   - `endedAt: DateTime?`
   - `packageVersion: String` (captured at round start for guard)
   - `createdAt: DateTime`
   - `updatedAt: DateTime`

2. **HoleScore model** (`domain/models/hole_score.dart`):
   - `id: String` (UUID)
   - `roundId: String`
   - `holeNumber: int` (1-27)
   - `par: int` (3-6)
   - `strokes: int`
   - `putts: int?`
   - `penalties: int?`
   - `fairwayHit: bool?`
   - `gir: bool?`
   - `clubUsed: String?`
   - `notes: String?`
   - `createdAt: DateTime`
   - `updatedAt: DateTime`

3. **Player model** (`domain/models/player.dart`):
   - `id: String` (UUID, local or from account)
   - `name: String`
   - `handicap: double?`
   - `isCurrentUser: bool`

4. **RoundSyncOperation enum** (`domain/models/round_sync_operation.dart`):
   - `startRound`
   - `endRound`
   - `updateRound`
   - `addHoleScore`
   - `updateHoleScore`
   - `deleteHoleScore`

5. **QueuedRoundUpdate model** (`domain/models/queued_round_update.dart`):
   - `idempotencyKey: String`
   - `operation: RoundSyncOperation`
   - `roundId: String`
   - `payload: String` (JSON)
   - `createdAt: DateTime`
   - `syncedAt: DateTime?`
   - `retryCount: int`

**Acceptance**: Models compile, round_package_version.dart is compatible with existing RoundPackageVersion from active_round_guard.dart.

---

### Slice 2 — PERSIST-STORE: Round SQLite Repository
**Owner**: Mobile (Data)
**Depends**: Slice 1

Implements SQLite-backed round persistence following the BagSyncStore pattern:

1. **RoundRepository** (`data/repositories/round_repository.dart`):
   - `static const String _dbName = 'vsp_round.db'`
   - `static const String _tableName = 'rounds'`
   - SQLite table: `id`, `course_id`, `course_name`, `status`, `started_at`, `ended_at`, `package_version`, `created_at`, `updated_at`
   - `createRound(Round): Future<void>` — insert with ON CONFLICT rollback
   - `updateRound(Round): Future<void>` — update with timestamp
   - `getRound(String id): Future<Round?>`
   - `getActiveRound(): Future<Round?>` — WHERE status = 'in_progress'
   - `getRoundsByCourse(int courseId): Future<List<Round>>`
   - `close(): Future<void>`

2. **HoleScoreRepository** (`data/repositories/hole_score_repository.dart`):
   - Same DB (`vsp_round.db`) — different table
   - SQLite table: `id`, `round_id`, `hole_number`, `par`, `strokes`, `putts`, `penalties`, `fairway_hit`, `gir`, `club_used`, `notes`, `created_at`, `updated_at`
   - `createScore(HoleScore): Future<void>`
   - `updateScore(HoleScore): Future<void>`
   - `deleteScore(String id): Future<void>`
   - `getScoresForRound(String roundId): Future<List<HoleScore>>`
   - `getScoreForHole(String roundId, int holeNumber): Future<HoleScore?>`

3. **PlayerRepository** (`data/repositories/player_repository.dart`):
   - Same DB — table: `id`, `round_id`, `name`, `handicap`, `is_current_user`
   - `addPlayer(Player, String roundId): Future<void>`
   - `getPlayersForRound(String roundId): Future<List<Player>>`
   - `removePlayer(String id): Future<void>`

4. **Transaction support**:
   - `transactional<T>(Future<T> Function(Transaction) action): Future<T>` using `db.transaction()`
   - Ensures round + scores + players are written atomically

**Acceptance**: Each repository persists and retrieves data correctly; transaction wraps multi-table writes atomically.

---

### Slice 3 — PERSIST-QUEUE: Round Sync Queue
**Owner**: Mobile (Data)
**Depends**: Slices 1, 2

Implements the local event queue for round sync, following BagSyncStore pattern:

1. **RoundSyncStore** (`core/storage/round_sync_store.dart`):
   - Same DB (`vsp_round.db`) — table: `round_sync_queue`
   - Columns: `idempotency_key`, `operation`, `round_id`, `payload`, `created_at`, `synced_at`, `retry_count`
   - `enqueueRoundOp({required String idempotencyKey, required RoundSyncOperation operation, required String roundId, String? payload}): Future<void>`
     - Uses `INSERT ... ON CONFLICT(idempotency_key) DO UPDATE SET payload=excluded.payload, created_at=excluded.created_at, synced_at=NULL`
   - `dequeueAll(): Future<List<QueuedRoundUpdate>>` — returns pending in creation order
   - `markSynced(String idempotencyKey): Future<void>` — sets synced_at
   - `hasPending(): Future<bool>`
   - `pendingCount(): Future<int>`
   - `incrementRetry(String idempotencyKey): Future<void>`
   - `purgeSynced(): Future<int>`

2. **Idempotency key generation**:
   - Format: `round_{uuid}_{operation}_{timestamp_ms}`
   - Example: `round_770e8400-e29b-41d4-a716_updateHoleScore_7200000`
   - Ensures same logical operation always gets same key (dedup-safe)

3. **Index for pending queue**:
   - `CREATE INDEX idx_round_sync_pending ON round_sync_queue(created_at) WHERE synced_at IS NULL`

**Acceptance**: Sync queue accepts operations, deduplicates by idempotency key, marks synced correctly.

---

### Slice 4 — PERSIST-SERVICE: Round State Service
**Owner**: Mobile (Service)
**Depends**: Slices 1, 2, 3

Implements the application service that coordinates persistence and queueing:

1. **RoundStateService** (`data/services/round_state_service.dart`):
   - `final RoundRepository _roundRepo`
   - `final HoleScoreRepository _scoreRepo`
   - `final PlayerRepository _playerRepo`
   - `final RoundSyncStore _syncStore`

   - `startRound(RoundConfig, List<Player>): Future<Round>`
     - Creates Round in DB (status: inProgress)
     - Enqueues `startRound` sync event
     - Records package version via `ActiveRoundGuard.recordRoundStart(courseId, roundId: round.id)`
     - Returns created Round

   - `updateHoleScore(String roundId, HoleScore): Future<void>`
     - Writes to HoleScoreRepository in transaction
     - Enqueues `updateHoleScore` sync event with idempotency key

   - `endRound(String roundId): Future<void>`
     - Updates round status to `completed`, sets endedAt
     - Enqueues `endRound` sync event
     - Calls `ActiveRoundGuard.recordRoundEnd(courseId)` to unlock package version

   - `getActiveRound(): Future<Round?>`
   - `getHoleScores(String roundId): Future<List<HoleScore>>`
   - `hasUnsyncedChanges(): Future<bool>`

2. **Recovery on launch**:
   - `recoverActiveRound(): Future<Round?>` — called on app start
   - Queries for `status = 'in_progress'` round
   - Returns it if found (enables "resume round" flow)

3. **Sync indicator state**:
   - `getSyncState(): Future<RoundSyncState>` — enum: `synced`, `pending`, `syncing`, `failed`

**Acceptance**: Round lifecycle (start → score → end) persists locally; unsynced count is accurate.

---

### Slice 5 — PERSIST-UI: Offline Save Indicator
**Owner**: Mobile (UI)
**Depends**: Slice 4

Implements the UX requirement for immediate offline save confirmation:

1. **SaveIndicator widget** (`presentation/widgets/offline_save_indicator.dart`):
   - States: `saved` (green checkmark + "Saved"), `pending` (blue clock + "Pending sync"), `syncing` (spinner), `failed` (red + "Sync failed")
   - Non-color-only: icon + text label for each state
   - Minimum 44x44pt touch target for retry action on failed state

2. **Scorecard screen integration**:
   - After each score write → show `saved` state briefly (2s), then return to `pending` if not yet synced
   - When sync completes → brief `saved` confirmation

3. **Round setup screen**:
   - Shows `pending` badge if there are unsynced rounds from prior session
   - "Resume round?" prompt if active incomplete round exists

**Acceptance**: Each score entry shows immediate save feedback; sync states are visible and non-color-only.

---

### Slice 6 — PERSIST-TEST: Unit and Integration Tests
**Owner**: Mobile (Test)
**Depends**: Slices 1–5

Comprehensive test coverage:

1. **Unit tests**:
   - `RoundRepository` CRUD + active-round query
   - `HoleScoreRepository` CRUD + hole-specific query
   - `RoundSyncStore` enqueue/dequeue/markSynced/deduplication
   - `RoundStateService` start/end/score/pending-count logic

2. **Integration tests**:
   - Transactional round creation (round + players persisted atomically)
   - Restart recovery: create round, kill app, relaunch, query active round — same data
   - Score round-trip: add score, retrieve, verify all fields
   - Sync queue: enqueue 3 operations, dequeue, mark one synced — correct remaining count

3. **Edge cases**:
   - Duplicate idempotency key → payload updated, not duplicated
   - Empty round list → `getActiveRound()` returns null
   - Score for non-existent round → handled gracefully

**Acceptance**: All tests pass; restart recovery verified in integration test.

---

## Slice Execution Order

| Order | Slice | Dependencies | Can Run |
|-------|-------|-------------|---------|
| 1 | PERSIST-MODELS | None | ✅ First |
| 2 | PERSIST-STORE | 1 | ✅ After 1 |
| 3 | PERSIST-QUEUE | 1, 2 | After 1, 2 |
| 4 | PERSIST-SERVICE | 1, 2, 3 | After 2, 3 |
| 5 | PERSIST-UI | 4 | After 4 |
| 6 | PERSIST-TEST | 1–5 | After all impl |

## Wave Planning

**Wave A (Models + Repository — foundation)**:
- Slice 1: PERSIST-MODELS
- Slice 2: PERSIST-STORE

**Wave B (Queue + Service — business logic)**:
- Slice 3: PERSIST-QUEUE
- Slice 4: PERSIST-SERVICE

**Wave C (UI + Tests — final)**:
- Slice 5: PERSIST-UI
- Slice 6: PERSIST-TEST

## Technical Notes

- **DB isolation**: Round data in `vsp_round.db` (separate from `vsp_package_manifest.db` and `vsp_active_round.db`)
- **Pattern consistency**: Reuses `BagSyncStore` pattern exactly — same idempotency dedup, same pending/synced columns, same index pattern
- **ActiveRoundGuard integration**: `RoundStateService.endRound()` must call `ActiveRoundGuard.recordRoundEnd()` to unlock package version
- **No API calls in this story**: Sync API calls belong to Story 5.4 (Synchronize Round Idempotently)
- **UUID generation**: Use `Uuid.v4()` for local IDs; server-assigned IDs come from sync in 5.4

## Verification Checklist

- [x] Round, hole, player, score written transactionally in SQLite
- [x] App restart recovers incomplete round (integration test)
- [x] UI shows "Saved" indicator immediately after each write
- [x] Sync queue deduplicates by idempotency key
- [x] Active round guard records round start/end
- [ ] All tests pass (Flutter not in PATH — must verify in Flutter environment)
- [ ] Format, lint, typecheck clean
