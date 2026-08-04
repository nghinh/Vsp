# Slice Plan — Story 12.1: Operate Tournament and Live Leaderboard

## Evidence of Context Reading

| Source | Evidence |
|--------|----------|
| `prd.md` §8.12 | Tournament Mode: basic mode flag and configurable feature restrictions (deferred to Epic 12 for full ops) |
| `prd.md` §8.12 | Tournament Mode restrictions — "Restricted features must be hidden or disabled. Enabled feature set is auditable. Tournament Mode may lock after round start." |
| `prd.md` §4.2 Secondary Users | "Tournament organizer: configures tournament rules, flights, scoring, leaderboards" |
| `prd.md` §8.4 | Round setup: "mode selection: Casual, Practice, Tournament" |
| `prd.md` §8.11 Scorecard | MVP supports score entry for up to four golfers; score colors consistent across scorecard, leaderboard |
| `prd.md` §13 Risk | "Tournament rule violations → Tournament Mode, feature restrictions, audit logs" |
| `architecture.md` §14 QG-8 | "Basic Tournament Mode restrictions are represented in config and UI" — DONE in Story 7.4 |
| `architecture.md` §10 | Portal RBAC includes "Tournament Director" role |
| `ux-spec.md` §5.2 | Round Setup: "Mode selection: Casual, Practice, Tournament" |
| `epics.md` Story 12.1 AC | "Tournament supports required formats, registration/import, flights, tee times, starting tees, score confirmation, tie-break, and result publication." |
| `epics.md` Story 12.1 AC | "Live leaderboard handles expected concurrency and degraded connectivity." |
| `epics.md` Story 12.1 AC | "Tournament policy propagates to participant round clients." |
| `epics.md` §685-698 | Epic 12: Tournament and Smart Golf Ecosystem — full tournament ops deferred from MVP 1-3 |
| `story 12.1 file` | Story spec read in full — scope, tasks, constraints, dependencies, verification |
| `sprint-status.yaml` | epic-12 status is `backlog`; 12.1 is `backlog` |
| `epic-state.json` | epic-12 is `pending` — currently being activated |
| Story 7.4 impl | `TournamentPolicy` domain model, `TournamentFeatureGuard`, feature restriction UI — foundation for 12.1 |
| Story 5.x impl | `Round`, `Score`, `ScoreEntry` entities — tournament rounds extend these |
| Story 8.x impl | Course operations portal — tournament portal builds on portal architecture |

---

## Scope

### What IS in scope (Story 12.1)
- **Tournament entity**: create/configure a tournament (name, format, dates, course, policy)
- **Tournament formats**: stroke play, match play, stableford (minimum three formats)
- **Player registration/import**: add players individually or bulk import (CSV/phone list)
- **Flights**: group registered players into tee times (groups of 2-4)
- **Tee times**: assign flights to start times with course/tee assignment
- **Starting tees**: front 9 / back 9 / combined start management
- **Score confirmation**: tournament director confirms each flight's scores after round
- **Tie-break rules**: configured tie-break procedure (scorecard playoff, exact handicap, etc.)
- **Result publication**: publish final standings after confirmation and tie-break resolution
- **Live leaderboard**: real-time scoreboard with WebSocket/SSE push, handles concurrency
- **Tournament policy propagation**: tournament's `TournamentPolicy` pushed to all participant rounds

### What is NOT in scope (deferred to Epic 12 other stories or future phases)
- Booking and reservation (Story 12.2)
- Membership and loyalty (Story 12.2)
- Payment processing (Story 12.3)
- Internationalization/localization (Story 12.4)
- Official tournament registration to external bodies
- Handicapping system integration
- Tournament watch app integration (Epic 10)

---

## Slices

### Slice A — Tournament Domain Model & Contracts
**Owner: domain / shared contracts**

Tasks:
- [ ] Create `TournamentFormat` enum: `strokePlay`, `matchPlay`, `stableford`
- [ ] Create `TournamentStatus` enum: `draft`, `registrationOpen`, `inProgress`, `completed`, `cancelled`
- [ ] Create `Tournament` model: `id`, `name`, `format`, `status`, `courseId`, `startDate`, `endDate`, `tournamentPolicyId`, `registrationDeadline`, `maxPlayers`, `description`, `createdAt`, `createdBy`, `version`
- [ ] Create `TieBreakRule` model: `id`, `tournamentId`, `order` (list), `ruleType` (scorecardPlayoff, exactHandicap, lowestRound, mostBirdies, draw)
- [ ] Create `TournamentPlayer` model: `id`, `tournamentId`, `playerId`, `handicap`, `flightId` (nullable), `registrationTime`, `status` (registered, confirmed, withdrawn, disqualified)
- [ ] Create `Flight` model: `id`, `tournamentId`, `flightNumber`, `playerIds[]`, `teeTimeId` (nullable), `startingTee` (front/back)
- [ ] Create `TeeTime` model: `id`, `tournamentId`, `teeTime` (datetime), `courseId`, `startingTeeBoxId`, `flightId` (nullable)
- [ ] Add `tournamentId` to `Round` — tournament rounds link to tournament
- [ ] Create `TournamentResult` model: `id`, `tournamentId`, `playerId`, `rank`, `score`, `scoreToPar`, `prize`, `tieBreakApplied`, `publishedAt`
- [ ] Document: tournament owns `TournamentPolicy`; individual rounds inherit it
- [ ] Add tournament schemas to `packages/contracts/schemas/tournament.yaml`

### Slice B — Tournament Persistence (Backend)
**Owner: backend / data layer**

Tasks:
- [ ] Create `tournaments` table: id, name, format, status, course_id, start_date, end_date, tournament_policy_id, registration_deadline, max_players, description, created_at, created_by, version
- [ ] Create `tournament_players` table: id, tournament_id, player_id, handicap, flight_id, registration_time, status
- [ ] Create `flights` table: id, tournament_id, flight_number, tee_time_id, starting_tee
- [ ] Create `tee_times` table: id, tournament_id, tee_time, course_id, starting_tee_box_id, flight_id
- [ ] Create `tie_break_rules` table: id, tournament_id, rule_order, rule_type
- [ ] Create `tournament_results` table: id, tournament_id, player_id, rank, score, score_to_par, prize, tie_break_applied, published_at
- [ ] Add `tournament_id` column to `rounds` table
- [ ] Create JPA repositories: `TournamentRepository`, `TournamentPlayerRepository`, `FlightRepository`, `TeeTimeRepository`, `TournamentResultRepository`
- [ ] Create database migrations

### Slice C — Tournament Service & API (Backend)
**Owner: backend / api layer**

Tasks:
- [ ] Create `TournamentService` interface and `TournamentServiceImpl`
- [ ] Create `TournamentController` with endpoints:
  - `POST /tournaments` — create tournament
  - `GET /tournaments/{id}` — get tournament
  - `PATCH /tournaments/{id}` — update tournament (before status=inProgress)
  - `POST /tournaments/{id}/publish` — open registration
  - `POST /tournaments/{id}/start` — start tournament
  - `POST /tournaments/{id}/complete` — complete tournament
  - `GET /tournaments` — list tournaments (filter by status, course)
- [ ] Create `TournamentRegistrationController`:
  - `POST /tournaments/{id}/players` — register player
  - `POST /tournaments/{id}/players/import` — bulk import from CSV
  - `DELETE /tournaments/{id}/players/{playerId}` — withdraw player
  - `GET /tournaments/{id}/players` — list registered players
- [ ] Create `FlightController`:
  - `POST /tournaments/{id}/flights` — create flight
  - `PATCH /tournaments/{id}/flights/{flightId}` — assign players to flight
  - `GET /tournaments/{id}/flights` — list flights
- [ ] Create `TeeTimeController`:
  - `POST /tournaments/{id}/tee-times` — create tee time slot
  - `PATCH /tournaments/{id}/tee-times/{teeTimeId}` — assign flight to tee time
  - `GET /tournaments/{id}/tee-times` — list tee times
- [ ] Create `LeaderboardController`:
  - `GET /tournaments/{id}/leaderboard` — current standings (polling)
  - `GET /tournaments/{id}/leaderboard/stream` — SSE stream for live updates
- [ ] Create `TournamentResultController`:
  - `POST /tournaments/{id}/results/publish` — publish final results
  - `GET /tournaments/{id}/results` — get published results
- [ ] RBAC: only `TournamentDirector` role can create/modify tournaments; all roles can view
- [ ] Audit: every tournament mutation logged

### Slice D — Tie-Break & Score Confirmation (Backend)
**Owner: backend / service layer**

Tasks:
- [ ] Create `TieBreakService`: `resolveTies(List<TournamentResult>)` — applies configured tie-break rules in order
- [ ] Create `ScoreConfirmationService`: `confirmFlight(flightId, confirmerId)` — locks flight scores
- [ ] Add `confirmedAt`, `confirmedBy` to `Flight`
- [ ] Backend: on tournament complete → auto-run tie-break resolution → generate `TournamentResult`
- [ ] Backend: tournament complete only allowed when all flights have confirmed scores
- [ ] `TournamentPolicy` from tournament must be attached to every round created for that tournament

### Slice E — Live Leaderboard (Backend)
**Owner: backend / service layer**

Tasks:
- [ ] Create `LeaderboardService`: maintains in-memory/cache leaderboard state per tournament
- [ ] Use Redis pub/sub or in-process event bus to publish score updates
- [ ] SSE endpoint (`/tournaments/{id}/leaderboard/stream`) broadcasts score changes
- [ ] Concurrency handling: score updates are atomic; leaderboard recalculates on each confirmed score
- [ ] Degraded connectivity: mobile can poll `/leaderboard` as fallback; SSE preferred
- [ ] Add `leaderboardVersion` to tournament — mobile can detect stale leaderboard
- [ ] Cache invalidation on score update

### Slice F — Tournament Policy Propagation (Backend + Mobile)
**Owner: backend / mobile infrastructure**

Tasks:
- [ ] Backend: `POST /rounds` with `tournamentId` auto-populates `tournamentPolicyId` from tournament
- [ ] Backend: when tournament policy is updated, propagate `tournamentPolicyVersion` bump to all active tournament rounds
- [ ] Mobile: `RoundRepository` stores `tournamentPolicy` locally alongside round
- [ ] Mobile: `TournamentFeatureGuard` uses round's `tournamentPolicy` (already implemented in Story 7.4 — just wire it up)
- [ ] Mobile: if tournament policy changes during active round, prompt user to sync new policy (UI shows policy update available)

### Slice G — Tournament Portal UI (Portal)
**Owner: portal / presentation**

Tasks:
- [ ] Tournament list screen: create, view, edit tournaments
- [ ] Tournament config form: name, format, dates, course, max players, policy selection
- [ ] Player management: add/remove/import players; show registered count
- [ ] Flight builder: drag players into flights; auto-sort by handicap
- [ ] Tee time scheduler: assign flights to tee times; choose starting tee
- [ ] Live leaderboard: real-time standings table with SSE connection
- [ ] Score confirmation panel: list unconfirmed flights; confirm button per flight
- [ ] Results publication: view final standings; publish button with confirmation
- [ ] Audit log: all tournament mutations visible in audit trail

### Slice H — Mobile Tournament Round Integration
**Owner: mobile / application + presentation**

Tasks:
- [ ] When starting a round with `format == tournament`, prompt for `tournamentId` if not already set
- [ ] Tournament rounds fetch and cache their tournament's `TournamentPolicy` on round start
- [ ] Tournament rounds show tournament name in round header
- [ ] Tournament rounds submit scores to tournament (not just local) — `ScoreSyncRequest` includes `tournamentId`
- [ ] Mobile leaderboard: poll `/tournaments/{id}/leaderboard` every 30s when app is active
- [ ] Tournament policy propagation UI: when policy changes mid-round, show non-blocking banner "Tournament policy updated — restart round for new restrictions"
- [ ] Offline: tournament policy cached locally; works offline for restricted feature checks

### Slice I — Automated Tests
**Owner: all layers**

Tasks:
- [ ] Unit tests: `TournamentService`, `TieBreakService`, `LeaderboardService`
- [ ] Unit tests: tournament policy propagation logic
- [ ] Integration tests: tournament creation → player registration → flight building → round scoring → leaderboard → results
- [ ] Concurrency tests: simultaneous score submissions don't corrupt leaderboard
- [ ] Negative tests: unauthorized tournament modification, registration after deadline, complete before all confirmed
- [ ] E2E smoke test: full tournament flow in mobile app

---

## Verification

### Happy path
- [ ] Create tournament with stroke play format
- [ ] Register 20 players (individual + bulk import)
- [ ] Auto-generate flights (4-somes) sorted by handicap
- [ ] Assign flights to tee times on front/back tees
- [ ] Players start rounds; scores sync to leaderboard in real-time
- [ ] Tournament director confirms each flight's scores after they finish
- [ ] All flights confirmed → tie-break runs → results generated
- [ ] Tournament director publishes results
- [ ] Tournament policy from tournament propagates to all participant rounds
- [ ] Restricted features respect tournament policy on participant rounds

### Negative paths
- [ ] Create tournament with missing required fields → validation error
- [ ] Modify tournament after `inProgress` → 403 error
- [ ] Register player after `registrationDeadline` → 400 error
- [ ] Complete tournament with unconfirmed flights → 400 error
- [ ] Non-TournamentDirector tries to create tournament → 403 error
- [ ] Score submission for wrong tournament → 400 error
- [ ] Leaderboard SSE disconnects → mobile falls back to polling

### Accessibility
- [ ] Portal tournament screens: keyboard navigation, focus order, visible labels
- [ ] Leaderboard: color + position text (not color-only ranking)
- [ ] Touch targets ≥44pt on tournament portal controls
- [ ] Screen reader announces live leaderboard score updates

### Performance
- [ ] Leaderboard recalculation <100ms for 200-player tournament
- [ ] SSE connection handles 100 concurrent mobile clients
- [ ] Tournament creation <500ms

---

## File Changes

### New files (backend — Java)
```
apps/api/src/main/java/vnpt/vsp/api/tournament/TournamentController.java
apps/api/src/main/java/vnpt/vsp/api/tournament/TournamentRegistrationController.java
apps/api/src/main/java/vnpt/vsp/api/tournament/FlightController.java
apps/api/src/main/java/vnpt/vsp/api/tournament/TeeTimeController.java
apps/api/src/main/java/vnpt/vsp/api/tournament/LeaderboardController.java
apps/api/src/main/java/vnpt/vsp/api/tournament/TournamentResultController.java
apps/api/src/main/java/vnpt/vsp/module/tournament/TournamentService.java
apps/api/src/main/java/vnpt/vsp/module/tournament/TournamentServiceImpl.java
apps/api/src/main/java/vnpt/vsp/module/tournament/TieBreakService.java
apps/api/src/main/java/vnpt/vsp/module/tournament/TieBreakServiceImpl.java
apps/api/src/main/java/vnpt/vsp/module/tournament/LeaderboardService.java
apps/api/src/main/java/vnpt/vsp/module/tournament/LeaderboardServiceImpl.java
apps/api/src/main/java/vnpt/vsp/module/tournament/ScoreConfirmationService.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/Tournament.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/TournamentPlayer.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/Flight.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/TeeTime.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/TournamentResult.java
apps/api/src/main/java/vnpt/vsp/module/tournament/entity/TieBreakRule.java
apps/api/src/main/java/vnpt/vsp/module/tournament/repository/TournamentRepository.java
apps/api/src/main/java/vnpt/vsp/module/tournament/repository/TournamentPlayerRepository.java
apps/api/src/main/java/vnpt/vsp/module/tournament/repository/FlightRepository.java
apps/api/src/main/java/vnpt/vsp/module/tournament/repository/TeeTimeRepository.java
apps/api/src/main/java/vnpt/vsp/module/tournament/repository/TournamentResultRepository.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TournamentCreateRequest.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TournamentResponse.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TournamentPlayerResponse.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/FlightRequest.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/FlightResponse.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TeeTimeRequest.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TeeTimeResponse.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/LeaderboardResponse.java
apps/api/src/main/java/vnpt/vsp/module/tournament/dto/TournamentResultResponse.java
apps/api/src/main/resources/db/migration/VXX__tournaments.sql
apps/api/src/main/resources/db/migration/VXX__tournament_players.sql
apps/api/src/main/resources/db/migration/VXX__flights.sql
apps/api/src/main/resources/db/migration/VXX__tee_times.sql
apps/api/src/main/resources/db/migration/VXX__tournament_results.sql
apps/api/src/main/resources/db/migration/VXX__tie_break_rules.sql
apps/api/src/main/resources/db/migration/VXX__rounds_add_tournament.sql
```

### New files (contracts — YAML)
```
packages/contracts/schemas/tournament.yaml  # new — tournament, tournament_player, flight, tee_time, leaderboard, result schemas
```

### Modified files (backend)
```
apps/api/src/main/java/vnpt/vsp/module/round/entity/Round.java           # add tournamentId
apps/api/src/main/java/vnpt/vsp/module/round/dto/RoundCreateRequest.java  # accept tournamentId
apps/api/src/main/java/vnpt/vsp/module/round/dto/RoundResponse.java       # include tournamentId
apps/api/src/main/java/vnpt/vsp/module/round/RoundServiceImpl.java        # auto-assign tournamentPolicyId from tournament
apps/api/src/main/java/vnpt/vsp/module/round/Round.java                   # add tournament_id FK (nullable)
apps/api/src/main/resources/db/migration/VXX__rounds_add_tournament.sql   # add tournament_id column
```

### New files (mobile — Dart)
```
apps/mobile/lib/domain/models/tournament.dart
apps/mobile/lib/domain/models/tournament_format.dart
apps/mobile/lib/domain/models/tournament_status.dart
apps/mobile/lib/domain/models/tournament_player.dart
apps/mobile/lib/domain/models/flight.dart
apps/mobile/lib/domain/models/tee_time.dart
apps/mobile/lib/domain/models/tournament_result.dart
apps/mobile/lib/domain/models/tie_break_rule.dart
apps/mobile/lib/domain/models/leaderboard_entry.dart
apps/mobile/lib/application/tournament/tournament_service.dart
apps/mobile/lib/application/tournament/leaderboard_notifier.dart
apps/mobile/lib/data/repositories/tournament_repository.dart
apps/mobile/lib/data/repositories/flight_repository.dart
apps/mobile/lib/presentation/screens/tournament/tournament_list_screen.dart
apps/mobile/lib/presentation/screens/tournament/tournament_detail_screen.dart
apps/mobile/lib/presentation/screens/tournament/create_tournament_screen.dart
apps/mobile/lib/presentation/screens/tournament/leaderboard_screen.dart
apps/mobile/lib/presentation/widgets/tournament/leaderboard_table.dart
apps/mobile/lib/presentation/widgets/tournament/flight_card.dart
apps/mobile/lib/presentation/widgets/tournament/player_list_tile.dart
```

### Modified files (mobile — Dart)
```
apps/mobile/lib/domain/models/round.dart              # add tournamentId, tournamentPolicy
apps/mobile/lib/features/round_setup/presentation/round_setup_bloc.dart  # tournament round flow
apps/mobile/lib/features/round_setup/presentation/round_setup_screen.dart  # tournament selector
apps/mobile/lib/application/score_sync_service.dart   # include tournamentId in sync
apps/mobile/lib/features/active_round/active_round_screen.dart  # show tournament name
```

### New files (portal — TypeScript/React)
```
apps/portal/src/features/tournament/pages/tournament-list-page.tsx
apps/portal/src/features/tournament/pages/tournament-detail-page.tsx
apps/portal/src/features/tournament/pages/create-tournament-page.tsx
apps/portal/src/features/tournament/components/tournament-form.tsx
apps/portal/src/features/tournament/components/player-manager.tsx
apps/portal/src/features/tournament/components/flight-builder.tsx
apps/portal/src/features/tournament/components/tee-time-scheduler.tsx
apps/portal/src/features/tournament/components/live-leaderboard.tsx
apps/portal/src/features/tournament/components/score-confirmation-panel.tsx
apps/portal/src/features/tournament/components/results-publication.tsx
apps/portal/src/features/tournament/hooks/use-tournament-api.ts
apps/portal/src/features/tournament/hooks/use-leaderboard-sse.ts
apps/portal/src/features/tournament/api/tournament-api.ts
```

---

## Dependencies on Earlier Stories

| Story | Dependency | Gap |
|-------|-----------|-----|
| 7.4 | `TournamentPolicy` model, feature flags, `TournamentFeatureGuard` | Reuse — tournament owns the policy that propagates to rounds |
| 5.1 | Round setup with `format` (tournament) | Extend to accept `tournamentId` and auto-assign policy |
| 5.3 | Score entry for a flight | Tournament scores confirmed by director; not directly editable by player |
| 5.4 | Round sync with idempotency | Tournament scores sync to tournament (not just round) |
| 5.5 | Round completion | Tournament round completion triggers score confirmation workflow |
| 1.3 | OpenAPI contracts, error standards, idempotency | Use for tournament API contracts |
| 1.5 | RBAC roles including Tournament Director | Already defined; used for tournament authorization |
| 8.x | Course operations portal architecture | Tournament portal uses same portal architecture |

---

## Quality Gate Alignment

- **FR24** (Epic 12): "Tournament platform" — tournament creation, flights, scoring, leaderboard ✓
- **PRD §8.12**: Tournament Mode feature restrictions — now expanded to full tournament operations ✓
- **PRD §4.2**: "Tournament organizer: configures tournament rules, flights, scoring, leaderboards" ✓
- **Story 12.1 AC**: formats, registration/import, flights, tee times, starting tees, score confirmation, tie-break, result publication ✓
- **Story 12.1 AC**: Live leaderboard handles concurrency and degraded connectivity ✓
- **Story 12.1 AC**: Tournament policy propagates to participant round clients ✓
- **Architecture §10**: Tournament Director RBAC role ✓
- **UX-DR1–DR3**: Glanceable leaderboard, one-hand tournament scoring flows, two-tap score confirm ✓
- **NFR-Security**: RBAC on tournament mutations, audit trail ✓
- **NFR-Offline**: Tournament policy cached locally; leaderboard polling fallback ✓

---

## Execution Notes

1. **Slice A (Domain + Contracts)** is the foundation — run first
2. **Slice B (Persistence)** depends on A — run second
3. **Slice C (Tournament API)** depends on B — run third
4. **Slice D (Tie-break + Score Confirmation)** depends on C — run fourth
5. **Slice E (Live Leaderboard)** depends on D — run fifth
6. **Slice F (Policy Propagation)** depends on C + 7.4 — run fifth/sixth
7. **Slice G (Portal UI)** depends on C-F — run as wave 2
8. **Slice H (Mobile Integration)** depends on A-F — run as wave 2
9. **Slice I (Tests)** is final gate before review

**Wave structure:**
- Wave 1: Slices A-E (backend foundation + live leaderboard)
- Wave 2: Slices F-H (policy propagation + mobile + portal)
- Final: Slice I (tests) + QA review
