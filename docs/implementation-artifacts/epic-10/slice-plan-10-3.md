# Slice Plan: Story 10.3 — Track Shots Manually

**Story ID**: 10.3
**Epic**: 10 (Watch Experience)
**Phase**: MVP 2–3
**Status**: `in-progress`
**Created**: 2026-08-02
**Story File**: `docs/implementation-artifacts/epic-10/10-3-track-shots-manually.md`

---

## Context Summary

### Story AC
1. User can start/end, assign club, edit, delete, merge, and mark penalty/provisional/mulligan.
2. Each shot stores start/end, club, lie, distance, conditions, result, source, and confidence.
3. Shot edits work offline and synchronize idempotently.

### PRD Entities
- `Shot` (core entity, listed in PRD §9.1)
- `Round → Flight → Score → Shot` hierarchy
- `Club` / `GolfBag` from Epic 2
- `Correction` from Epic 9 (for shot data corrections)

### Architecture Context
- Flutter mobile app + modular monolith backend
- Local-first with SQLite + encrypted storage + event queue
- PostgreSQL/PostGIS geospatial source of truth
- OpenAPI contracts with idempotency keys
- Shot event schema noted as deferred architecture hook (not built in MVP 1)

### Dependencies
- Epic 5 (Round/Local-First Scoring) — Round, Flight, Score models exist
- Epic 2 (Golfer Profile/Golf Bag) — Club/GolfBag models exist
- Story 10.4 (Detect Shots with Confidence) — depends on this story's data model
- No dependency on 10.1/10.2 (watch experiences)

### UX Requirements
- Glanceable, one-hand, two-tap flows during active round
- GPS/data confidence states visible
- Offline indicator always understandable
- Touch targets ≥44pt iOS / 48dp Android
- Semantics for screen readers

---

## Domain Model

### Shot Entity (canonical fields)
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Primary key |
| `roundId` | UUID | FK → Round |
| `flightId` | UUID | FK → Flight |
| `playerId` | UUID | FK → Player |
| `holeNumber` | int | 1–18 |
| `shotNumber` | int | Per-hole sequence |
| `clubId` | UUID | FK → Club (nullable until assigned) |
| `startedAt` | DateTime | When shot was started |
| `endedAt` | DateTime | When shot was ended |
| `startLocation` | GeoJSON Point | WGS84 (SRID 4326) |
| `endLocation` | GeoJSON Point | WGS84 (SRID 4326) |
| `lie` | enum | teebox, fairway, rough, bunker, water, penalty, green, putt, etc. |
| `distanceYards` | decimal | Optional (GPS-calculated) |
| `distanceMeters` | decimal | Optional |
| `conditions` | JSON | Wind, temp, etc. snapshot |
| `result` | enum | fairway_hit, green_hit, in_bunker, in_water, out_of_bounds, penalty, mulligan, etc. |
| `isPenalty` | bool | |
| `isProvisional` | bool | |
| `isMulligan` | bool | |
| `mergedIntoShotId` | UUID | FK → Shot (for merge tracking) |
| `source` | enum | manual, detected, corrected |
| `confidence` | decimal | 0.0–1.0 |
| `syncStatus` | enum | pending, synced, failed |
| `idempotencyKey` | string | Unique per mutation event |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

### Shot Event (for sync queue)
```json
{
  "eventType": "ShotStarted | ShotEnded | ShotEdited | ShotDeleted | ShotsMerged",
  "shotId": "uuid",
  "roundId": "uuid",
  "playerId": "uuid",
  "payload": { /* shot fields */ },
  "idempotencyKey": "uuid",
  "timestamp": "ISO8601"
}
```

---

## Slice Architecture

### Layers and Ownership

```
┌─────────────────────────────────────────────┐
│  UI Layer (Flutter)                         │
│  - ShotEntrySheet (bottom sheet, 2-tap max) │
│  - ShotReviewScreen (round recap)            │
│  - ShotEditSheet (inline edit)               │
│  - ShotListTile (widget)                     │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Application Layer (Flutter)                 │
│  - ShotTrackingService                      │
│  - ShotSyncService                          │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Domain Layer (Flutter)                      │
│  - Shot (entity)                            │
│  - ShotResult (value object)                │
│  - ShotLie (value object)                   │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│  Infrastructure Layer (Flutter)              │
│  - SQLiteShotRepository                     │
│  - SyncEventQueue                           │
│  - OpenAPIShotClient                        │
└──────────────┬──────────────────────────────┘
               │
               │ OpenAPI contract
               ▼
┌─────────────────────────────────────────────┐
│  Backend (Modular Monolith)                 │
│  - Round Module (existing)                  │
│  - NEW: ShotModule                          │
│    - ShotController                         │
│    - ShotService                            │
│    - ShotRepository (PostGIS)               │
│    - ShotSyncEndpoint                       │
└─────────────────────────────────────────────┘
```

---

## Task Slices

### Slice 1: Domain + Persistence (Backend + Mobile)
**Goal**: Shot entity and OpenAPI contract, SQLite local storage

1. **Backend**: Add `ShotModule` with `Shot`, `ShotRepository` (PostGIS), `ShotService`, `ShotController`
2. **Backend**: `POST /rounds/{roundId}/shots` — create shot
3. **Backend**: `PATCH /shots/{shotId}` — edit shot
4. **Backend**: `DELETE /shots/{shotId}` — delete shot
5. **Backend**: `POST /rounds/{roundId}/shots/merge` — merge shots
6. **Backend**: `GET /rounds/{roundId}/shots` — list shots with sync cursor
7. **Backend**: Idempotency key handling on all write endpoints
8. **Backend**: Audit trail for shot mutations
9. **Flutter**: `Shot` domain model matching contract
10. **Flutter**: `ShotRepository` (SQLite local, keyed by roundId)
11. **Flutter**: `ShotSyncService` using Epic 5's `SyncEventQueue`

### Slice 2: UI — Shot Entry (Mobile)
**Goal**: Start/end shots, assign club, during active round

1. **Flutter**: `ShotEntrySheet` — bottom sheet, 2-tap flow
   - Shot number display
   - Club selector (from active bag)
   - Start shot button (captures GPS start location)
   - End shot button (captures GPS end location, calculates lie/distance)
2. **Flutter**: GPS location capture on shot start/end
3. **Flutter**: Auto-calculate lie from end location (fairway/rough/bunker/water/OB detection)
4. **Flutter**: Auto-calculate distance from start→end
5. **Flutter**: `ShotTrackingState` — active shot indicator during round
6. **Flutter**: Offline save confirmation (Epic 5 pattern)
7. **Flutter**: Accessibility — Semantics labels, 44/48pt touch targets

### Slice 3: UI — Shot Review + Edit (Mobile)
**Goal**: Edit, delete, merge, penalty/provisional/mulligan marking

1. **Flutter**: `ShotReviewScreen` — accessible after round or between holes
   - Per-player shot list
   - Shot cards with club, lie, distance, result, confidence badge
2. **Flutter**: `ShotEditSheet` — inline edit
   - Edit club, lie, result
   - Mark penalty / provisional / mulligan toggles
   - Delete shot (with confirmation)
   - Merge shots (select two shots to combine)
3. **Flutter**: `ShotListTile` widget — reusable component
4. **Flutter**: Sync status indicator on each shot (pending/synced/failed)
5. **Flutter**: Retry action for failed sync

### Slice 4: Offline + Sync
**Goal**: Durable writes, idempotent sync, restart recovery

1. **Flutter**: All shot mutations write to SQLite first (Epic 5 pattern)
2. **Flutter**: Append shot events to `SyncEventQueue` with idempotency key
3. **Flutter**: `ShotSyncWorker` — retry with backoff when online
4. **Flutter**: Server deduplication by idempotency key
5. **Flutter**: Restart recovery — reload incomplete round with pending shot events
6. **Flutter**: Conflict policy: latest client edit wins (per Epic 5 sync design)
7. **Backend**: GET endpoint returns shots since sync cursor (delta sync)
8. **Backend**: Shot sync audit log

### Slice 5: Validation + Testing
**Goal**: All acceptance criteria verified

1. **Unit tests**: Shot domain model serialization
2. **Unit tests**: Lie auto-detection logic (fairway/rough/bunker/water/OB)
3. **Unit tests**: Distance calculation (WGS84)
4. **Integration tests**: Shot CRUD + sync round-trip
5. **Integration tests**: Offline write → restart → sync recovery
6. **Integration tests**: Merge behavior
7. **UI tests**: Shot entry flow (2-tap max)
8. **UI tests**: Shot edit/delete/merge flows
9. **Accessibility tests**: Semantics labels, touch target sizes
10. **Build gate**: `flutter analyze`, `flutter test`, `flutter build apk` (or `ios`)

---

## Acceptance Criteria Mapping

| AC | Verification Method |
|---|---|
| Start/end shots | Unit test + UI integration test |
| Assign club | UI test with club selector |
| Edit shot | UI test with ShotEditSheet |
| Delete shot | UI test with confirmation dialog |
| Merge shots | Integration test |
| Mark penalty | UI test — toggle |
| Mark provisional | UI test — toggle |
| Mark mulligan | UI test — toggle |
| Shot stores all fields | Contract test + serialization test |
| Offline + idempotent sync | Integration test — offline write, restart, sync |

---

## Verification Checklist

- [x] Shot entity with all canonical fields defined in domain + contract _(Slice 1)_
- [x] SQLite persistence with offline-first writes _(Slice 1)_
- [x] Idempotency keys on all shot mutation events _(Slice 1)_
- [x] Sync event queue integration (Epic 5 pattern) _(Slice 1)_
- [ ] Shot entry bottom sheet — 2-tap or fewer _(Slice 2)_
- [ ] Shot edit/delete/merge — all accessible _(Slice 3)_
- [ ] Penalty/provisional/mulligan toggles _(Slice 3)_
- [ ] Offline save indicator visible _(Slice 2–3)_
- [ ] Sync pending/synced/failed states visible _(Slice 3)_
- [ ] Retry action for failed sync _(Slice 4)_
- [ ] GPS accuracy visible on shot capture _(Slice 2)_
- [ ] Semantics labels on all custom controls _(Slice 2–3)_
- [ ] 44/48pt touch targets _(Slice 2–3)_
- [ ] Unit + integration + UI tests pass _(Slice 5)_
- [ ] `flutter analyze` clean _(Slice 5)_
- [ ] `flutter build` successful _(Slice 5)_

**Slice 1 Gates:**
- [x] `mvn compile` — backend compiles
- [x] Dedup protocol — clean
- [x] OpenAPI contract — shot.yaml created, paths registered
- [x] Backend entity + repository + service + controller — complete
- [x] Flutter domain model + SQLite DAO + repository + SyncService — complete
- [ ] Flutter analyze — skipped (environment lacks flutter CLI)

---

## File Manifest (Implemented — Slice 1)

### Backend (Modular Monolith — ShotModule)
```
apps/api/src/main/java/vnpt/vsp/module/shot/
  ShotModule.java                  # Marker annotation
  ShotController.java             # REST endpoints
  ShotService.java                # Interface
  ShotServiceImpl.java            # Implementation with audit
  entity/Shot.java                # JPA entity (22 fields)
  repository/ShotRepository.java  # Spring Data JPA
  dto/
    ShotDto.java                  # Full shot response DTO
    ShotResponse.java            # Single mutation response
    ShotListResponse.java        # List + cursor response
    ShotSyncResponse.java        # Sync confirmation response
    CreateShotRequest.java       # Create shot DTO
    UpdateShotRequest.java       # Partial update DTO
    MergeShotsRequest.java       # Merge shots DTO
    GeoJSONPointDto.java         # GeoJSON Point helper
    ConditionsDto.java           # Conditions snapshot DTO
```

### Flutter Mobile (Slice 1)
```
apps/mobile/lib/
  domain/models/shot.dart        # Shot entity (22 fields, enums, serialization)
  domain/repositories/shot_repository.dart  # Repository interface
  data/local/tables/shots_table.dart     # SQLite table definition
  data/local/daos/shot_dao.dart         # SQLite DAO
  data/repositories/shot_repository_impl.dart  # Repository implementation
  application/services/shot_sync_service.dart  # Offline-first + SyncEventQueue
```

### Contracts (OpenAPI)
```
packages/contracts/
  schemas/shot.yaml              # New: 22-field Shot schema + enums + DTOs + ShotEvent
  openapi.yaml                  # Updated: 5 shot paths + Shots tag + schema refs
```

### Flutter Mobile
```
apps/mobile/
  lib/
    domain/
      models/
        shot.dart
        shot_lie.dart
        shot_result.dart
        shot_event.dart
    application/
      services/
        shot_tracking_service.dart
        shot_sync_service.dart
    infrastructure/
      repositories/
        shot_repository.dart
      datasources/
        shot_local_datasource.dart
        shot_remote_datasource.dart
    presentation/
      screens/
        shot_review_screen.dart
      sheets/
        shot_entry_sheet.dart
        shot_edit_sheet.dart
      widgets/
        shot_list_tile.dart
        shot_card.dart
        club_selector.dart
        penalty_toggle.dart
```

### Contracts
```
packages/contracts/
  src/
    openapi/
      paths/
        shots.yaml
      schemas/
        shot.yaml
        shot-event.yaml
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Shot schema conflicts with Epic 5 Score schema | Low | High | Epic 5 Score is per-hole gross; Shot is per-shot sub-detail. They coexist. |
| GPS location capture accuracy | Medium | Medium | Show GPS accuracy badge; allow manual location correction |
| Offline sync conflict with round completion | Low | Medium | Epic 5 conflict policy (client wins for score edits); extend to shots |
| Performance of shot list during long round | Low | Low | Lazy loading; pagination on API |

---

## Out of Scope (Not in This Story)

- Automatic shot detection (Story 10.4)
- Watch-specific shot UI (Stories 10.1/10.2)
- Club recommendation (Epic 11)
- Strokes Gained calculation (Epic 11)
- Shot dispersion analytics (Epic 11)
- Tournament shot restrictions (Epic 12)

---

## Ready for Implementer Dispatch

This slice plan provides complete implementation guidance. The implementer (Amelia/dev-agent) can proceed with:
1. Backend ShotModule + contract definition
2. Flutter domain model + repository
3. UI screens following UX spec
4. Offline + sync integration

**Implementer dispatch**: Owned by `vnpt-dev-epic-orchestrator` after this planning phase completes.