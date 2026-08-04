# Slice Plan — Story 5.1: Configure and Start a Round

## Evidence of Context Reading

| Source | Evidence |
|--------|----------|
| `prd.md` §8.4 | FR5: "Users can configure and start Casual, Practice, or Tournament rounds for up to four golfers." |
| `prd.md` §8.4 | Round setup: "User selects course, layout, holes, tee, game format, players, handicap, mode, and active bag." |
| `prd.md` §8.4 | Suggest nearest course, layout, tee, starting hole, and frequent partners. |
| `architecture.md` §8.2 | Local SQLite for rounds, scores, local events, and sync cursors. |
| `architecture.md` §8.3 | All on-course writes are first persisted locally; sync worker retries idempotent API calls. |
| `ux-spec.md` §5.2 | Round Setup screen: course/layout/tee/game format, player selection up to four, mode selection, active bag, starting hole with auto-suggest. |
| `ux-spec.md` §4 | Design tokens, high-contrast, 44/48dp touch targets, non-color-only indicators. |
| `epics.md` Story 5.1 | "As a golfer, I want to configure course, tee, format, players, mode, bag, and starting hole so that the round matches my game." |
| `round.yaml` (contracts) | RoundCreate requires courseId + startTime; playerIds array; packageId optional. |
| `V13__rounds_and_scores.sql` | rounds table: golfer_account_id, status, started_at, ended_at, deleted_at. |
| `active_round_guard.dart` | Already implements recordRoundStart(courseId, roundId) using active manifest version. |
| `course_package_manifest.dart` | isEffective getter checks effectiveDate and expiresAt. |
| `bag_dto.dart` | BagDTO.isActive, active bag used for round setup. |

---

## Scope

### What IS in scope
- Round configuration screen (course, layout, tee, format, players, mode, bag, starting hole)
- Nearby course/layout/hole suggestion with GPS + manual override
- Offline package readiness validation before round start
- Warning UI when package is missing, expired, or not downloaded
- Backend: `POST /rounds` round creation with playerIds, courseId, startTime
- Local round config persistence (SQLite) before sync
- ActiveRoundGuard.recordRoundStart() call on successful round start
- Active bag pre-selection from golfer profile

### What is NOT in scope (deferred)
- Hole-by-hole score entry (Story 5.3)
- Local round persistence (Story 5.2 — transactional SQLite writes)
- Round sync and idempotency (Story 5.4)
- Round completion and review (Story 5.5)
- Tournament Mode feature restrictions (Story 7.4)
- Weather/conditions display during round (Epic 7)
- GPS hole detection (Epic 6)
- Active round map/distance (Epic 6)

---

## Slices

### Slice A — Round Configuration Domain Models
**Owner: domain layer**

Tasks:
- [ ] Create `RoundConfig` model: courseId, courseName, layoutId, teeId, format (casual/practice/tournament), playerIds (1–4), mode, bagId, startHole, startTime
- [ ] Create `Player` model: id, name, handicap, isPrimary
- [ ] Create `RoundFormat` enum: casual, practice, tournament
- [ ] Create `RoundMode` enum: strokePlay, stableford (MVP: strokePlay only, others locked)
- [ ] Add validation: 1 ≤ playerIds.length ≤ 4, startHole 1–18 or 1–9 front/10–18 back
- [ ] Add `RoundConfig.isOfflineReady` computed: courseId + packageId + manifest != null && manifest.isEffective

### Slice B — Round Setup UI Screen
**Owner: mobile/presentation**

Tasks:
- [ ] Create `round_setup_screen.dart` with sections: Course, Players, Format, Mode, Bag, Start Hole
- [ ] Course section: course name display, change course button, offline-ready badge (green) or warning (amber/red)
- [ ] Layout/tee selector: dropdown from course layouts and tee sets from package manifest
- [ ] Players section: add/remove up to 4 players; primary player (first) is self from profile
- [ ] Format selector: Casual / Practice / Tournament pill toggle
- [ ] Mode selector: Stroke Play (MVP), others disabled with lock icon + tooltip
- [ ] Bag selector: pre-select active bag; change bag option
- [ ] Start hole: auto-suggest 1 or 10 based on time of day/Geo; manual override with hole picker
- [ ] Offline package validation: on course selected, check manifest isEffective; show warning banner if not
- [ ] "Start Round" CTA: disabled state when no course or package not ready; loading state during round creation
- [ ] Loading/empty/error states for each async selector
- [ ] Accessibility: all touch targets ≥44pt, screen reader labels, color+icon for offline state, reduced motion

### Slice C — Round Creation BLoC
**Owner: mobile/application**

Tasks:
- [ ] Create `round_setup_bloc.dart`: Events (CourseSelected, LayoutSelected, TeeSelected, PlayerAdded, PlayerRemoved, FormatChanged, ModeChanged, BagChanged, StartHoleChanged, StartRoundTapped, PackageValidationRequested)
- [ ] Create `round_setup_state.dart`: course, layouts, tees, players, format, mode, bag, startHole, packageStatus (notChecked/valid/invalid/expired/notDownloaded), validationErrors, isSubmitting
- [ ] Package validation: on CourseSelected, call PackageManifestRepository.getActiveManifest(courseId); check isEffective; emit warning if not
- [ ] StartRound: create RoundConfig → call RoundRepository.createRound(config) → on success call ActiveRoundGuard.recordRoundStart(courseId, roundId) → emit RoundStarted(navigation)
- [ ] Error handling: offline-first — if API fails, save config locally and emit LocalRoundSaved + navigation

### Slice D — Backend Round Creation API
**Owner: backend/api**

Tasks:
- [ ] Create `RoundModule` with `RoundService` and `RoundController`
- [ ] `POST /rounds` endpoint: accepts RoundCreate (courseId, startTime, playerIds, packageId, cartRequested)
- [ ] Validate courseId exists and packageId is published for that course
- [ ] Create round record in `rounds` table with status IN_PROGRESS
- [ ] Create score records for each playerId in `scores` table
- [ ] Return created Round with id, status, startedAt
- [ ] Add idempotency key support (X-Idempotency-Key header, dedupe within 24h window)
- [ ] Audit: log round creation with actor, course, playerIds

### Slice E — Offline Package Readiness Validation
**Owner: mobile/infrastructure**

Tasks:
- [ ] In `PackageManifestRepository`, add `getOfflineReadiness(courseId)` returning `PackageReadiness{isReady, reason, manifest, expiresAt}`
- [ ] `isReady` = manifest != null && manifest.isEffective && package files exist locally
- [ ] Reason codes: `ok`, `notDownloaded`, `expired`, `checksumMismatch`, `filesMissing`
- [ ] Show warning dialog if `!isReady` with reason; allow proceed with explicit acknowledgment ("Play anyway?")
- [ ] Record user's decision to proceed without valid package (telemetry)

### Slice F — Nearby Course Suggestion
**Owner: mobile/infrastructure**

Tasks:
- [ ] On RoundSetupScreen mount, request location (GPS) and query nearby downloaded courses
- [ ] `CoursePackageRepository.getNearbyDownloadedCourses(lat, lon, radiusKm)` using package manifest location
- [ ] Auto-select nearest course if exactly 1 within 5km; otherwise show course picker
- [ ] Auto-suggest start hole: hole 1 if local time < 12pm, hole 10 if ≥ 12pm (configurable)
- [ ] Fallback: last-played course from recent_courses table

### Slice G — Integration and Active Round Guard Hook
**Owner: mobile/infrastructure**

Tasks:
- [ ] After successful `POST /rounds`, call `ActiveRoundGuard.recordRoundStart(courseId, roundId: round.id)`
- [ ] Store round config in SQLite via `round_setup_store.dart` (pending Story 5.2 full persistence)
- [ ] Emit navigation event to `ActiveRoundScreen` on successful start
- [ ] If offline: save to local queue with idempotency key, navigate immediately, sync on reconnect (deferred to 5.4)

---

## Verification

### Happy path
- [ ] Select course with valid offline package → offline-ready badge shown → start round → round created, guard recorded, navigate to active round

### Negative paths
- [ ] No course selected → "Start Round" disabled
- [ ] Course selected but package not downloaded → warning banner "Offline data not ready" → proceed anyway → acknowledged and starts
- [ ] Package expired → banner "Course data may be outdated" → proceed anyway
- [ ] API fails (offline) → local save, navigate to active round, sync pending badge
- [ ] >4 players added → add button disabled, tooltip explains
- [ ] Tournament format selected → mode picker shows only Stroke Play, others locked

### Accessibility
- [ ] Screen reader announces course name, player count, format, start hole, offline status
- [ ] Touch targets ≥44pt on all interactive elements
- [ ] Color + icon for offline/sync states (not color-only)
- [ ] Reduced motion respected on all transitions

### Performance
- [ ] Round setup screen renders <500ms with cached course data
- [ ] Package validation completes <1s (local check)

---

## File Changes

### New files
```
apps/mobile/lib/domain/models/round_config.dart
apps/mobile/lib/domain/models/player.dart
apps/mobile/lib/domain/models/round_format.dart
apps/mobile/lib/features/round_setup/presentation/round_setup_screen.dart
apps/mobile/lib/features/round_setup/presentation/round_setup_bloc.dart
apps/mobile/lib/features/round_setup/presentation/round_setup_event.dart
apps/mobile/lib/features/round_setup/presentation/round_setup_state.dart
apps/mobile/lib/features/round_setup/widgets/... (player_card.dart, format_selector.dart, hole_picker.dart, package_status_banner.dart)
apps/mobile/lib/data/repositories/round_repository.dart
apps/mobile/lib/data/services/package_readiness_service.dart
apps/mobile/lib/core/storage/round_setup_store.dart
apps/api/src/.../round/RoundController.java
apps/api/src/.../round/RoundService.java
apps/api/src/.../round/RoundRepository.java
```

### Modified files
```
apps/mobile/lib/data/repositories/course_package_repository.dart   # add getOfflineReadiness
apps/mobile/lib/data/services/active_round_guard.dart             # already done, verify recordRoundStart called
apps/mobile/lib/core/navigation/app_router.dart                   # add /round-setup, /active-round routes
apps/api/src/.../Module.java                                      # add RoundModule wiring
apps/api/src/main/resources/db/migration/V13__rounds_and_scores.sql  # verify schema adequate
```

---

## Dependencies on Earlier Stories

| Story | Dependency | Gap |
|-------|-----------|-----|
| 1.1 | Repository structure, CI gates | None — done |
| 3.1 | Course/hole/tee PostGIS schema | None — done |
| 3.2 | Course search | Used for nearby course suggestion |
| 4.1 | Package manifest contract | Used for offline readiness check |
| 4.3 | Package download | Used for offline validation |
| 5.2 | Local SQLite persistence | Slice F/G writes to local store; full AC deferred to 5.2 |
| 2.3 | Golfer profile | Used for primary player (self) pre-fill |

---

## Quality Gate Alignment

- **NFR1**: Cached hole screen <2s → round setup <500ms target ✓
- **NFR3**: Full 18-hole round works offline → package validation ensures offline readiness ✓
- **NFR6**: Local persistence before sync → local round config store before API call ✓
- **NFR9**: TLS, RBAC, audit → API auth, round creation audit log ✓
- **UX-DR2**: Two-tap start → "Start Round" primary CTA, pre-filled defaults ✓
- **UX-DR3**: 44pt touch targets on player add/remove, format toggle ✓
- **UX-DR5**: GPS/offline state visible → package status banner ✓
- **UX-DR12**: Official/community/estimated visible → package accuracy class shown ✓
