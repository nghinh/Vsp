# Slice Plan — Story 5.4: Synchronize Round Idempotently

## Evidence of Context Reading

| Source | Evidence |
|--------|----------|
| `prd.md` §10.6 | "Offline: Scorecard supported. Local persistence before sync. Retry and idempotency support. No score loss during backend outage." |
| `prd.md` §8.10 | "Score data is persisted locally before sync." |
| `architecture.md` §8.3 | "Sync: Local event queue + idempotent APIs. No score loss offline, safe retry." |
| `architecture.md` §11.3 | "Idempotency keys for write/sync endpoints." |
| `ux-spec.md` §6.4 | Visible sync states: "Online / Offline ready / Sync pending / Sync failed". Copy: "Saved offline. Sync when online." |
| `epics.md` story 5.4 | AC1: local events carry unique idempotency keys + retry with backoff. AC2: server deduplicates. AC3: pending/syncing/synced/failed visible + retry action. |
| `5-3-enter-scores-for-a-flight.md` | Score entry for up to 4 golfers; story 5.3 output feeds 5.4 sync |
| `5-2-persist-round-locally.md` | SQLite transactional persistence; app restart restores incomplete round |
| `5-1-configure-and-start-a-round.md` | Round configuration with up to 4 players |
| `IdempotencyFilter.java` | Already exists at `apps/api/src/main/java/vnpt/vsp/api/idempotency/IdempotencyFilter.java`; resolves `Idempotency-Key` header, replays cached response on duplicate |
| `IdempotencyService.java` | Interface exists: `isDuplicate`, `getCachedResponse`, `put`, `evict`; in-memory impl uses ConcurrentHashMap; Redis impl swappable |
| `module/score/` | ScoreService and Score entity already exist |
| `module/round/` | RoundService and Round entity already exist |

---

## Story Scope Confirmation

**Story 5.4 AC mapped to implementation:**

| AC | Implementation |
|----|----------------|
| AC1: Local events carry unique idempotency keys and retry with backoff | Flutter: `SyncEvent` model with UUID idempotency key + `SyncQueueRepository` in SQLite + `SyncWorker` with exponential backoff |
| AC2: Server deduplicates repeated submissions | Backend: `@Idempotent` on score/round sync endpoints; `IdempotencyFilter` already handles deduplication via `Idempotency-Key` header |
| AC3: Pending, syncing, synced, failed states visible with retry action | Flutter: `SyncStatus` enum (`pending`/`syncing`/`synced`/`failed`) + `SyncStatusBadge` widget in scorecard UI + retry action button |

**Scope boundary (from story Dev Context):**
- Does NOT implement full offline-correction sync (that's epic-9)
- Does NOT implement tournament sync locking (epic-7)
- Does NOT implement shot tracking sync (epic-10)
- Sync worker processes events already stored by stories 5.1–5.3

---

## Slice Plan

### Slice 1 — Backend: Idempotent Score/Round Endpoints

**File:** `apps/api/src/main/java/vnpt/vsp/module/score/ScoreController.java` (new or existing)
**File:** `apps/api/src/main/java/vnpt/vsp/module/round/RoundController.java` (new or existing)

**Changes:**
1. Annotate existing score-sync endpoint with `@Idempotent(ttlSeconds = 86400)` (24h TTL matches architecture §8.3)
2. Annotate round-sync endpoint with `@Idempotent(ttlSeconds = 86400)`
3. Both endpoints already covered by `IdempotencyFilter` — no filter changes needed
4. Add `SyncStatusResponse` DTO returning `{eventId, status, syncedAt, error}` for sync confirmation
5. The `IdempotencyFilter` returns `X-Idempotent-Replay: true` header on replay; client can use this to detect deduplication without re-processing

**Verification:**
- Unit test: `IdempotencyFilter` replays cached response when same `Idempotency-Key` resubmitted
- Unit test: Score endpoint returns 400 when `Idempotency-Key` header absent (VALIDATION_006)

---

### Slice 2 — Flutter Domain: Sync Event Model and State Machine

**File:** `apps/mobile/lib/domain/model/sync_event.dart` (new)
**File:** `apps/mobile/lib/domain/model/sync_status.dart` (new)

**Model — `SyncEvent`:**
```dart
enum SyncEventType { scoreUpdate, roundCreate, roundComplete }

enum SyncState { pending, syncing, synced, failed }

class SyncEvent {
  final String id;           // UUID v4 — idempotency key
  final SyncEventType type;
  final String entityId;     // score_id or round_id
  final String payload;      // JSON-encoded event body
  final SyncState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;
}
```

**Model — `SyncStatus` enum and helpers:**
```dart
enum SyncStatus { pending, syncing, synced, failed }

// Per-entity helper: round-level aggregated status
SyncStatus aggregateStatus(List<SyncEvent> events) { ... }
```

**Verification:**
- Unit test: `SyncEvent` serializes to/from JSON with idempotency key preserved
- Unit test: `aggregateStatus` returns correct aggregated state

---

### Slice 3 — Flutter Infrastructure: SQLite Queue + Sync Worker with Backoff

**File:** `apps/mobile/lib/infrastructure/persistence/sync_queue_repository.dart` (new)
**File:** `apps/mobile/lib/infrastructure/sync/sync_worker.dart` (new)
**File:** `apps/mobile/lib/infrastructure/sync/idempotency_client.dart` (new)

**`SyncQueueRepository`:**
- SQLite table `sync_events(id TEXT PK, type TEXT, entity_id TEXT, payload TEXT, state TEXT, attempt_count INTEGER, created_at INTEGER, last_attempt_at INTEGER, error_message TEXT)`
- `append(SyncEvent)` — insert with `state=pending`
- `markSyncing(String id)`
- `markSynced(String id)`
- `markFailed(String id, String error)`
- `getPending()` — ordered by `created_at` ASC
- `getForEntity(SyncEventType type, String entityId)`

**`SyncWorker`:**
- Exponential backoff: `min(baseDelay * 2^attemptCount, maxDelay)`, base=5s, max=300s, maxAttempts=5
- On connectivity restored → call `IdempotencyClient.syncAll()`
- On permanent failure (maxAttempts reached) → mark `failed` and surface to UI for manual retry
- Background execution via `WorkManager` or `dart:async` isolate — NOT blocking UI thread
- Stop worker when round is `complete` and all events `synced`

**`IdempotencyClient`:**
- Wraps `ApiClient`; on every sync call, attaches `Idempotency-Key: <event.id>` header
- Handles `X-Idempotent-Replay: true` → mark event `synced` without re-processing
- Handles 2xx → mark `synced`
- Handles 4xx → mark `failed` (client error, no retry)
- Handles 5xx / network error → mark `pending`, increment `attemptCount`

**Connectivity detection:**
- Use `connectivity_plus` package `onConnectivityChanged` stream
- Trigger sync on `connectivityResult != none`

**Verification:**
- Unit test: backoff delays computed correctly for attempt 0–5
- Unit test: `SyncQueueRepository` round-trips all `SyncState` values
- Integration test: full sync cycle — pending → syncing → synced

---

### Slice 4 — Flutter Presentation: Sync Status UI

**File:** `apps/mobile/lib/presentation/widgets/sync_status_badge.dart` (new)
**File:** `apps/mobile/lib/presentation/screens/scorecard_screen.dart` (modify)

**`SyncStatusBadge`:**
- Shows icon + label: `pending` → clock icon + "Saved offline", `syncing` → spinner + "Syncing…", `synced` → check icon + "Synced", `failed` → warning icon + "Sync failed — Tap to retry"
- Color: `pending` → amber, `syncing` → blue, `synced` → accent green, `failed` → red
- Non-color-only: includes icon + text label (UX §10 / UX-DR5)
- Touch target ≥ 48dp
- `failed` state shows retry `InkWell` that calls `SyncWorker.retry(event.id)`

**Placement in `ScorecardScreen`:**
- Persistent bottom bar showing round-level aggregate sync status
- Status bar visible during and after round without requiring navigation
- Accessible label: "Round sync status: <state>"

**Accessibility (per UX §10):**
- `Semantics` wrapper with `label: "Sync status: ${state.label}"`
- `excludeSemantics: false`
- Respects `reducedMotion` — no infinite spinners, use static icon instead

**Verification:**
- Widget test: badge renders correct icon/color/text for each `SyncStatus` value
- Widget test: failed badge retry action is triggered on tap

---

## Implementation Order

```
Backend slice (1)        →  Independent, can start immediately
Flutter domain slice (2) →  Depends on nothing, start in parallel
Flutter infra slice (3)  →  Depends on slice 2 (models exist)
Flutter UI slice (4)     →  Depends on slice 2 + 3 (models + worker exist)
```

**Parallel execution recommended:** slices 1 and 2 in parallel by separate implementers.

---

## Open Decisions / Risks

| Item | Risk | Mitigation |
|------|------|------------|
| Backend: score/round endpoints not yet created | Unknown if sync endpoints exist | Implementer to check `module/score/` and `module/round/` for existing sync endpoints before creating new ones |
| Flutter: no existing sync worker pattern | Worker lifecycle management risk | Use `WorkManager` for background persistence; stop worker when round completes |
| Backend: Redis idempotency store not yet configured | Production deduplication may miss in-flight events | Architecture says Redis impl is swappable; in-memory impl covers single-instance dev |
| Retry exponential base not defined in PRD | Backoff values are judgment calls | Use base=5s, max=300s (5 minutes), maxAttempts=5 — stated explicitly for implementer |

---

## Quality Gate Alignment

| Gate | Covered By |
|------|-----------|
| Idempotency key uniqueness | Slice 2: UUID v4 generated at `SyncEvent` creation |
| Retry with backoff | Slice 3: `SyncWorker` exponential backoff formula |
| Server deduplication | Slice 1: `@Idempotent` annotation + `IdempotencyFilter` |
| Sync state visibility | Slice 4: `SyncStatusBadge` in scorecard |
| Retry action | Slice 4: failed badge `InkWell` triggers `SyncWorker.retry()` |
| Offline resilience | Slice 3: SQLite queue survives app restart |
| Non-color-only indicators | Slice 4: icon + text label always present |
| Accessibility | Slice 4: Semantics wrapper, 48dp touch target |

---

## File List (Preliminary)

### Backend (Java)
- `apps/api/src/main/java/vnpt/vsp/module/score/ScoreController.java` — add `@Idempotent` + `SyncStatusResponse`
- `apps/api/src/main/java/vnpt/vsp/module/round/RoundController.java` — add `@Idempotent` + `SyncStatusResponse`
- `apps/api/src/test/java/vnpt/vsp/module/score/ScoreControllerIdempotencyTest.java` (new)

### Flutter (Dart)
- `apps/mobile/lib/domain/model/sync_event.dart`
- `apps/mobile/lib/domain/model/sync_status.dart`
- `apps/mobile/lib/infrastructure/persistence/sync_queue_repository.dart`
- `apps/mobile/lib/infrastructure/sync/sync_worker.dart`
- `apps/mobile/lib/infrastructure/sync/idempotency_client.dart`
- `apps/mobile/lib/presentation/widgets/sync_status_badge.dart`
- `apps/mobile/test/domain/model/sync_event_test.dart`
- `apps/mobile/test/infrastructure/sync/sync_worker_test.dart`
- `apps/mobile/test/presentation/widgets/sync_status_badge_test.dart`

---

## Status Update

After this slice plan is written and accepted:
- Story source status: `ready-for-dev` → `in-progress`
- Sprint-status: `5-4-synchronize-round-idempotently: backlog` → `in-progress`
