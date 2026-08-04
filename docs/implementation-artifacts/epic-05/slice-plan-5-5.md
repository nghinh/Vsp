# Slice Plan — Story 5.5: Complete and Review Round

## Story Metadata

| Field | Value |
|-------|-------|
| Story | 5.5 |
| Epic | 5 — Round Setup and Local-First Scoring |
| Title | Complete and Review Round |
| Status | ready-for-dev → **in-progress** |
| Phase | MVP 1 |
| Runner | `vnpt-dev-story-orchestrator` |

---

## 1. Context: What Exists and What Is Missing

### 1.1 Existing Backend Infrastructure (from epic-05 prior stories + stories 5.1–5.4)

| Layer | Existing | Missing for 5.5 |
|-------|----------|-----------------|
| DB | `rounds` (id, golfer_account_id, status, started_at, ended_at, deleted_at) + `scores` (id, round_id, golfer_account_id, deleted_at) — V13 migration ✓ | `score_entries` table for per-hole scores; round completion audit trail |
| Round entity | `Round.java` ✓ — status enum (IN_PROGRESS/COMPLETED/ABANDONED/CANCELLED), startedAt, endedAt | Score entries embedded or joined; completion validation |
| Score entity | `Score.java` ✓ — minimal stub | Per-hole score entries (strokes, putts, penalties, fairway, gir, bunker, club, notes) |
| RoundService | `RoundService.java` — empty interface stub | Completion logic: validate round belongs to golfer, set status=COMPLETED, set endedAt, enqueue sync event |
| ScoreService | `ScoreService.java` + `ScoreServiceImpl.java` ✓ | Score correction with audit |
| Idempotency | `IdempotencyService.java` + `IdempotencyFilter.java` ✓ | Round completion uses existing idempotency key pattern |
| API contract | `round.yaml` — `RoundUpdate` schema has `status` + `endedAt` ✓ | New `POST /rounds/{roundId}/complete` or reuse `PATCH /rounds/{roundId}`; correction audit schema |
| OpenAPI | `/rounds` + `/rounds/{roundId}` endpoints defined ✓ | `POST /rounds/{roundId}/complete`; `POST /rounds/{roundId}/corrections` |

### 1.2 Existing Mobile Infrastructure (from epic-05 prior stories)

| Layer | Existing | Missing for 5.5 |
|-------|----------|-----------------|
| Active round guard | `active_round_guard.dart` ✓ — records round start/end with package version | Round completion must call `recordRoundEnd()` |
| Round state | No round BLoC yet | `RoundCompletionBloc` for summary + completion + correction |
| Round screens | None for completion/summary | `RoundSummaryScreen`, `RoundCompletionDialog` |
| Score entry | None yet (story 5.3 backlog) | Minimal scorecard data structure needed for summary display |
| Sync | Event queue stub from story 5.4 (backlog) | Round completion must append `round_complete` sync event |
| Navigation | `app.dart` — simple routes ✓ | New routes: `/round/:id/summary`, `/round/:id/complete` |

---

## 2. Scope: What Is IN and OUT for Story 5.5

### IN (explicitly in ACs and story scope)

- **AC-1**: Completion works offline and marks pending synchronization when required.
  - Mark round status = COMPLETED locally in SQLite.
  - Set `ended_at` timestamp locally.
  - Append `round_complete` event to local sync event queue with idempotency key.
  - If offline: event sits in queue with `pending` state.
  - Backend deduplicates via idempotency key on replay.

- **AC-2**: Summary displays hole scores, totals, basic stats, and sync state.
  - Summary screen shows per-hole scores for all players (up to 4).
  - Gross total per player.
  - Score vs par (relative score).
  - Basic stats: fairways hit %, GIR %, total putts, total penalties.
  - Sync state indicator (pending / syncing / synced / failed) per player score.
  - Visual sync state using `color.accent` green for synced, amber for pending, red for failed.

- **AC-3**: User can reopen permitted fields for correction with audit history.
  - Permitted fields: score entries (strokes, putts, penalties, fairway, GIR, bunker, notes).
  - Non-permitted: course, players, started_at.
  - Correction creates an audit entry (actor, timestamp, field, old_value, new_value).
  - Correction syncs via event queue with `round_correction` event type.

### OUT (deferred scope — NOT in this story)

- Post-round analytics (Strokes Gained, club dispersion) → Epic 11.
- Scorecard image generation / signature → deferred.
- Tournament verification / official score submission → deferred.
- Sharing round results socially → deferred.
- Deep-link into specific hole from summary → can note but not required.

---

## 3. Slice Plan

### Slice 1: Backend — Round Completion Endpoint

**Files touched:**
```
apps/api/src/main/java/vnpt/vsp/module/round/RoundService.java       [update interface]
apps/api/src/main/java/vnpt/vsp/module/round/RoundServiceImpl.java  [add complete logic]
apps/api/src/main/java/vnpt/vsp/module/round/RoundController.java   [add PATCH /rounds/{id}/complete]
apps/api/src/main/java/vnpt/vsp/module/score/ScoreService.java       [add correction method]
apps/api/src/main/java/vnpt/vsp/module/score/ScoreServiceImpl.java  [add correction + audit]
apps/api/src/main/java/vnpt/vsp/module/score/entity/ScoreCorrection.java [NEW - audit entry]
apps/api/src/main/resources/db/migration/V20__round_completion_and_audit.sql [NEW]
packages/contracts/schemas/round.yaml                                [add complete request/response]
packages/contracts/openapi.yaml                                       [add POST /rounds/{id}/complete]
```

**Logic:**
- `PATCH /rounds/{roundId}` with `status=completed` and `endedAt` — idempotent (already completed → return 200).
- Validate: round exists, belongs to authenticated golfer, status != already completed.
- Set `endedAt = now()` if not set.
- Set `status = COMPLETED`.
- Emit audit entry for completion.
- `POST /rounds/{roundId}/corrections` — validate permitted fields only, create `score_corrections` audit table entry, return updated score.

**Migration:**
```sql
-- Score correction audit table
CREATE TABLE score_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id),
    player_id BIGINT NOT NULL REFERENCES golfer_accounts(id),
    field_name VARCHAR(50) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    corrected_at TIMESTAMP NOT NULL DEFAULT NOW(),
    corrected_by BIGINT NOT NULL REFERENCES golfer_accounts(id)
);

-- Add hole_number + par + strokes + putts + penalties + fairway_hit + gir + bunker + club + notes
-- to score_entries (new table joined to scores)
CREATE TABLE score_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    score_id UUID NOT NULL REFERENCES scores(id),
    hole_number INT NOT NULL CHECK (hole_number BETWEEN 1 AND 27),
    par INT NOT NULL,
    strokes INT NOT NULL,
    putts INT DEFAULT 0,
    penalties INT DEFAULT 0,
    fairway_hit BOOLEAN,
    gir BOOLEAN,
    bunker BOOLEAN,
    club VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_score_entries_score ON score_entries(score_id);
```

---

### Slice 2: Mobile — Domain Models + BLoC

**Files touched:**
```
apps/mobile/lib/domain/models/round_summary.dart        [NEW]
apps/mobile/lib/domain/models/score_entry.dart         [NEW]
apps/mobile/lib/domain/models/sync_state.dart           [NEW]
apps/mobile/lib/domain/models/correction.dart           [NEW]
apps/mobile/lib/features/round/data/round_repository.dart   [NEW]
apps/mobile/lib/features/round/data/round_service.dart       [NEW]
apps/mobile/lib/features/round/presentation/round_completion_bloc.dart [NEW]
apps/mobile/lib/features/round/presentation/round_summary_screen.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/round_stats_card.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/score_row_widget.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/sync_state_badge.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/correction_dialog.dart [NEW]
apps/mobile/lib/app.dart                                    [add /round/:id/summary route]
```

**Models:**
- `RoundSummary`: roundId, courseName, startedAt, endedAt, players[], holes[], totals, syncState
- `ScoreEntry`: holeNumber, par, strokes, putts, penalties, fairwayHit, gir, bunker, club, notes
- `SyncState`: enum {pending, syncing, synced, failed}, lastAttempt, retryCount
- `Correction`: field, oldValue, newValue, correctedAt

**Bloc events:**
- `LoadRoundSummary(roundId)`
- `CompleteRound(roundId)` → writes COMPLETED locally, queues sync event
- `RetrySync(roundId)` → re-triggers sync event
- `RequestCorrection(roundId, field, oldValue, newValue)` → queues correction event

**Bloc states:**
- `RoundSummaryInitial`
- `RoundSummaryLoading`
- `RoundSummaryLoaded(summary)`
- `RoundCompletionInProgress`
- `RoundCompletionSuccess`
- `RoundCompletionOffline(summary with pending sync)`
- `RoundCorrectionRequested`
- `RoundError(message)`

---

### Slice 3: Mobile — Round Summary Screen

**Layout (per UX spec §5.2 Round Summary + UX-DR principles):**

```
AppBar: "Round Complete" + sync state badge
  [Course name] [Date] [Total score vs par]

Per-player scorecard section:
  ┌─────────────────────────────────────┐
  │ Player Name          Front  Back  Total │
  │ Hole 1   2   3 ...     37    38    75  │
  │ Par   4  4  5 ...     36    36    72  │
  │ +/-   +1 +1 +0 ...     +1    +2    +3  │
  └─────────────────────────────────────┘

Stats card:
  Fairways: 7/14 (50%)   GIR: 10/18 (56%)
  Total Putts: 34        Penalties: 2

Sync state indicator:
  [Icon] "Scores saved offline. Will sync when online." / "All scores synced ✓"

[Edit Scores] button  [Share] button  [Done] button
```

- Touch targets: minimum 48dp.
- Color + icon for sync state (not color alone).
- Semantics labels on all score rows.
- Large text support.
- Dark mode support.

---

### Slice 4: Backend — Score Correction with Audit

**Endpoint: `POST /rounds/{roundId}/corrections`**

Request:
```json
{
  "playerId": "uuid",
  "corrections": [
    { "field": "strokes", "holeNumber": 3, "oldValue": "5", "newValue": "4" }
  ]
}
```

Response:
```json
{
  "correctionId": "uuid",
  "appliedAt": "ISO8601",
  "auditId": "uuid"
}
```

- Validate permitted fields list.
- Validate round belongs to user.
- Validate round is COMPLETED (can only correct completed rounds).
- Insert `score_corrections` audit row.
- Update `score_entries` row.
- Emit audit sync event.

---

### Slice 5: Integration — Offline Completion + Sync Queue

**Round completion offline flow:**
1. User taps "End Round" in active round screen.
2. `RoundCompletionBloc` dispatches `CompleteRound(roundId)`.
3. BLoC writes `status=COMPLETED` + `endedAt` to local SQLite `rounds` table.
4. BLoC appends `round_complete` event to `sync_events` table:
   ```json
   { "eventType": "round_complete", "roundId": "...", "idempotencyKey": "uuid", "payload": {...}, "syncState": "pending" }
   ```
5. BLoC calls `activeRoundGuard.recordRoundEnd(courseId)`.
6. BLoC emits `RoundCompletionOffline(summary)` state (if connectivity absent) or `RoundCompletionSuccess(summary)`.
7. Summary screen shows with sync state badge.

**Sync retry:**
- Story 5.4 worker processes `round_complete` event with idempotency key.
- Server deduplicates.
- On failure, event state → `failed`; retry button in summary re-queues.

---

## 4. Dependency Chain

```
Story 5.1 (configure/start)  ─────┐
Story 5.2 (persist locally)  ─────┤──► Story 5.3 (enter scores)
Story 5.3 (enter scores)    ───────┤    Story 5.4 (sync idempotently) ──┐
                                   └────────────────────────────────────┘
                                                                            │
                                                              Story 5.5 (complete + review) ◄── DEPENDS ON ALL ABOVE
```

Story 5.5 depends on the **outputs** of 5.1–5.4 (round data, score data, sync event queue). If 5.3 and 5.4 are not yet implemented, this story's mobile slice can still build domain models and UI stubs against mock data.

---

## 5. Verification Plan

| AC | Verification Method |
|----|---------------------|
| AC-1 offline completion | Unit test: `RoundCompletionBloc` dispatches CompleteRound → SQLite has status=COMPLETED, sync_event has pending state. Integration test: airplane mode → complete → event queued locally. |
| AC-2 summary display | Widget test: `RoundSummaryScreen` renders with mock RoundSummary; verify per-hole scores, totals, stats, sync badge visible. Accessibility test: Semantics widget has labels on score rows. |
| AC-3 correction + audit | Unit test: `ScoreService.correctScore()` creates audit entry and updates score. API test: POST /rounds/{id}/corrections returns 200 with auditId. |
| Sync state visibility | Unit test: sync state badge shows correct color/icon for pending/synced/failed. |
| Retry behavior | Unit test: RetrySync event re-queues sync event with new idempotency key. |

**Negative paths to cover:**
- Complete already-completed round → idempotent 200 (no error).
- Correction on non-completed round → 409 conflict.
- Correction with non-permitted field → 422 validation error.
- Complete round offline → sync state = pending.
- Sync event fails → state = failed with retry action.

---

## 6. File Manifest (Complete)

### Backend
```
apps/api/src/main/java/vnpt/vsp/module/round/RoundService.java          [interface add completeRound()]
apps/api/src/main/java/vnpt/vsp/module/round/RoundServiceImpl.java     [add completeRound() + validate]
apps/api/src/main/java/vnpt/vsp/module/round/RoundController.java      [add complete endpoint]
apps/api/src/main/java/vnpt/vsp/module/score/ScoreService.java         [add correctScoreEntries()]
apps/api/src/main/java/vnpt/vsp/module/score/ScoreServiceImpl.java     [add correction logic]
apps/api/src/main/java/vnpt/vsp/module/score/entity/ScoreCorrection.java [NEW entity]
apps/api/src/main/resources/db/migration/V20__round_completion_and_audit.sql [NEW]
packages/contracts/schemas/round.yaml                                     [add CompleteRoundRequest/Response]
packages/contracts/schemas/score.yaml                                     [add ScoreCorrection schema]
packages/contracts/openapi.yaml                                          [add POST /rounds/{id}/complete, correction]
```

### Mobile
```
apps/mobile/lib/domain/models/round_summary.dart        [NEW]
apps/mobile/lib/domain/models/score_entry.dart           [NEW]
apps/mobile/lib/domain/models/sync_state.dart            [NEW]
apps/mobile/lib/domain/models/correction.dart            [NEW]
apps/mobile/lib/features/round/data/round_repository.dart [NEW]
apps/mobile/lib/features/round/data/round_service.dart    [NEW]
apps/mobile/lib/features/round/presentation/round_completion_bloc.dart [NEW]
apps/mobile/lib/features/round/presentation/round_summary_screen.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/round_stats_card.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/score_row_widget.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/sync_state_badge.dart [NEW]
apps/mobile/lib/features/round/presentation/widgets/correction_dialog.dart [NEW]
apps/mobile/lib/app.dart                                 [add routes]
```

### Tests
```
apps/api/src/test/java/vnpt/vsp/api/round/RoundCompletionTest.java    [NEW]
apps/api/src/test/java/vnpt/vsp/api/round/RoundCorrectionTest.java    [NEW]
apps/mobile/test/domain/models/round_summary_test.dart                  [NEW]
apps/mobile/test/features/round/presentation/round_completion_bloc_test.dart [NEW]
```

---

## 7. Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Score data not yet persisted (5.3 backlog) — summary has no data | Medium | Build against `RoundSummary` model with mock data; story 5.3 must deliver real data before epic-05 review gate |
| Backend RoundServiceImpl empty — large impl scope | High | Implement only `completeRound()` + `correctScoreEntries()`; reuse existing JPA patterns from ScoreServiceImpl |
| Flutter app has no round feature routing | Medium | Add named routes `/round/:id/summary` in app.dart; do not refactor entire navigation |
| ActiveRoundGuard needs `recordRoundEnd()` call on completion | Low | Already exists in `active_round_guard.dart`; call it from BLoC |
| Audit table migration V20 may conflict with other stories | Low | Use additive migration (new tables only); no column adds to existing tables |

---

## 8. Open Decisions (to resolve before implementation)

1. **Round completion trigger**: Is there an explicit "End Round" button on the active round map screen, or does the 18th hole completion auto-trigger? → UX decision: explicit button needed per UX-DR1 (glanceability). Add to active round screen as part of this story if not already there.
2. **Correction allowed window**: Is there a time limit after which corrections are no longer allowed? → Default: corrections allowed indefinitely for MVP; flagged as open.
3. **Summary stats scope**: Should total penalties be shown? Yes (from story 5.3 AC context). Should putts-per-hole average be shown? Include total putts; per-hole average is derivative and can be deferred.
