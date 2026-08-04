# Slice Plan — Story 10.4: Detect Shots with Confidence

## Story Reference
- **Story**: 10.4 — Detect Shots with Confidence
- **Epic**: 10 — Smartwatch and Shot Tracking
- **Phase**: MVP 2–3
- **Status**: `in-progress`
- **Run folder**: `docs/vnpt-flow/epic-run-run_2026_08_02_010/`
- **Created**: 2026-08-02

---

## Context Summary

### What This Story Is
Automatic shot detection suggestions using multi-signal confidence scoring. Combines GPS, movement, time, sensor, and hole-context signals to produce shot suggestions with confidence levels that drive auto/review/confirm/discard behavior.

### What This Story Is NOT
- Full AI shot intelligence (deferred to Epic 11)
- Smartwatch-native shot capture (Epic 10.1/10.2)
- Club recommendation or performance analytics (Epic 11)
- Manual shot entry UI (Story 10.3 — prerequisite)

### Dependency
- **Story 10.3** (Track Shots Manually): Must be completed first as it provides the `Shot` entity and manual shot CRUD that this story extends with automatic detection.

### Key Constraints
- Flutter mobile, MapLibre, modular-monolith backend, PostgreSQL/PostGIS
- Local-first: writes locally durable before sync
- No deferred AI, smartwatch, analytics, tournament-platform scope
- Confidence/offline states must be visible per UX requirements

---

## Slice Plan

### Slice 1: Domain Models — ShotDetection models, confidence levels, signal types

**Files to create/modify:**
- `apps/mobile/lib/domain/models/shot_detection.dart` (NEW)
  - `ShotDetectionSignalType` enum: gps, accelerometer, gyroscope, time, holeContext
  - `ShotDetectionSignal` value object: type, weight, rawValue, normalizedScore, capturedAt
  - `ShotDetectionSignals` bundle: all signals for one detection window
  - `ShotConfidenceLevel` enum: discard (0-0.2), reviewLater (0.2-0.5), confirm (0.5-0.75), automatic (0.75-1.0)
  - `ShotDetectionSuggestion` model: shotId (pending), playerId, clubId?, suggestedLie, suggestedStartLocation, suggestedEndLocation?, confidence, level, signals, reason, detectedAt, status (pending/confirmed/rejected/discarded)
  - `ShotDetectionResult` model: list of suggestions sorted by confidence, detectedAt, location
  - `ShotDetectionReason` enum: movementBurst, stationaryPause, proximityToGreen, proximityToTeeBox, patternMatch, etc.
  - `ShotFilterType` enum for exclusion categories: practiceSwing, cartMovement, nearbyGolfer, shortShot, penalty, mulligan
- `apps/mobile/lib/domain/models/shot.dart` — extend with detectionConfidence field (Story 10.3 contract)
- `apps/mobile/test/domain/models/shot_detection_test.dart` (NEW)

**Acceptance**: ShotDetection models exist with correct confidence level boundaries matching AC (automatic, review-later, confirm, discard). Signal types cover all 5 required signals.

---

### Slice 2: Shot Detection Scorer — pure confidence scoring algorithm

**Files to create:**
- `apps/mobile/lib/domain/services/shot_detection_scorer.dart` (NEW — pure function class)
  - Weighted multi-signal scoring:
    - GPS movement delta (weight: 0.30): distance traveled in detection window
    - Accelerometer/gyroscope movement signature (weight: 0.25): swing-like vs cart vs walking
    - Time interval since last shot (weight: 0.15): typical shot pacing by hole
    - Hole context proximity (weight: 0.20): proximity to green/tee/landing zones
    - GPS accuracy signal (weight: 0.10): low accuracy penalizes confidence
  - Score range: 0.0–1.0
  - Deterministic, no side effects
- `apps/mobile/test/domain/services/shot_detection_scorer_test.dart` (NEW)

**Acceptance**: Scorer returns 0.0–1.0 score. Test coverage for all 5 signals. Hole detection scorer pattern followed (per architecture precedent).

---

### Slice 3: Shot Detection Service — lifecycle management, signal aggregation

**Files to create/modify:**
- `apps/mobile/lib/application/detection/shot_detection_state.dart` (NEW)
  - `ShotDetectionStatus`: idle, active, paused, error
  - `ShotDetectionState`: status, currentResult, lastLocation, pendingSuggestions, error
  - Similar pattern to `DetectionState` (story 6.2)
- `apps/mobile/lib/application/detection/shot_detection_cubit.dart` (NEW)
  - Manages lifecycle: startDetection, pauseDetection, resumeDetection, stopDetection
  - Aggregates GPS/sensor signals per detection window
  - Calls scorer, emits state
  - Integrates with existing GPS location stream from story 6.1
- `apps/mobile/lib/features/play/services/shot_detection_service_impl.dart` (NEW — stub impl)

**Acceptance**: Service starts/stops cleanly. State transitions follow DetectionCubit pattern. GPS location stream consumed.

---

### Slice 4: Shot Filter — exclusion logic for false-positive categories

**Files to create:**
- `apps/mobile/lib/domain/services/shot_filter.dart` (NEW)
  - `ShotFilter` class with `FilterResult`: includes (true) or excludes (false) + reason
  - Filter rules:
    - `practiceSwing`: no GPS movement delta + accelerometer swing signature + within teeing ground
    - `cartMovement`: continuous GPS movement + low accelerometer variance + on cart path
    - `nearbyGolfer`: multiple GPS points within 5m with diverging trajectories
    - `shortShot`: movement delta < 10m AND proximity to green indicates putt
    - `penalty`: sudden GPS jump > 50m without corresponding club swing
    - `mulligan`: movement delta large but confidence very low AND player initiated
  - Filter order: cartMovement → practiceSwing → nearbyGolfer → shortShot → penalty → mulligan
- `apps/mobile/test/domain/services/shot_filter_test.dart` (NEW)

**Acceptance**: All 6 exclusion categories have test coverage. Filter is composable with scorer (filter runs before scoring decision).

---

### Slice 5: Shot Suggestion Repository — local persistence of suggestions

**Files to create/modify:**
- `apps/mobile/lib/data/local/tables/shot_detection_suggestions_table.dart` (NEW)
  - Columns: id, roundId, playerId, status, confidence, confidenceLevel, suggestedLie, suggestedClubId, suggestedStartLat, suggestedStartLon, suggestedEndLat?, suggestedEndLon?, reason, signalsJson, detectedAt, confirmedAt?, rejectedAt?, createdAt, updatedAt
- `apps/mobile/lib/data/repositories/shot_detection_repository.dart` (NEW)
  - saveSuggestion(), getPendingSuggestions(roundId), confirmSuggestion(id), rejectSuggestion(id), discardSuggestion(id)
  - Works offline, returns immediately
- `apps/mobile/test/data/repositories/shot_detection_repository_test.dart` (NEW)

**Acceptance**: Suggestions persist locally. All 4 status transitions (pending→confirmed/rejected/discarded) work offline. Idempotent.

---

### Slice 6: UI Integration — shot suggestion UI with confidence indicator

**Files to create/modify:**
- `apps/mobile/lib/presentation/widgets/shot_confidence_indicator.dart` (NEW)
  - Similar pattern to `DetectionConfidenceIndicator` (story 6.2)
  - Shows confidence level with icon + label + color
  - Non-color-only: icon + text + color
- `apps/mobile/lib/features/play/presentation/shot_suggestion_sheet.dart` (NEW)
  - Bottom sheet showing pending shot suggestion
  - Shows: club, lie, start/end location, confidence level, reason
  - Actions: Confirm, Edit, Dismiss
  - Works offline, haptic feedback
- `apps/mobile/lib/features/play/presentation/active_round_screen.dart` (MODIFY)
  - Add shot detection status chip near distance panel
  - Non-color-only: "Shot detected — review" with icon

**Acceptance**: Shot suggestion sheet appears for confirm-level detections. Confidence indicator matches design tokens. Touch targets ≥44pt. Screen reader labels present.

---

### Slice 7: Confidence Threshold Configuration — per-behavior thresholds

**Files to create/modify:**
- `apps/mobile/lib/domain/models/shot_detection_config.dart` (NEW)
  - `ShotDetectionThresholds` record: automaticMin (0.75), confirmMin (0.5), reviewLaterMin (0.2), discardMax (0.2)
  - `ShotDetectionWindows`: detectionWindowSeconds (30), minTimeBetweenShots (15), maxShortShotDistanceMeters (10)
  - `ShotDetectionFilters`: maxCartPathSpeedMs, minPracticeSwingAccelerationDelta, etc.
  - Stored in app config, settable per round mode (casual/practice/tournament)
- `apps/mobile/test/domain/models/shot_detection_config_test.dart` (NEW)

**Acceptance**: Config drives all threshold decisions. Tournament mode can tighten thresholds.

---

### Slice 8: Integration with Story 10.3 — attach detection to manual shot flow

**Files to modify:**
- After Story 10.3 completes, extend `Shot` model to include `detectionConfidence`, `detectionSignals`, `detectionSuggestionId` fields
- `ShotDetectionCubit` calls `ShotRepository` to promote suggestion → confirmed shot on user confirm
- `ShotDetectionRepository` clean up rejected/discarded suggestions

**Note**: This slice is partially blocked until Story 10.3 is complete. Implementation will be written against the expected Shot model contract from 10.3 spec. If 10.3 model differs, this slice adapts.

---

## Verification Plan

### Per-Slice Verification
1. Format: `dart format`
2. Lint: `dart analyze`
3. Typecheck: `dart analyze --fatal-infos`
4. Unit tests: `flutter test` per slice
5. Build: `flutter build` (iOS simulator)

### Story-Level Verification
- All 5 ACs addressed by at least one test:
  - [ ] AC1: Detection combines sensor, GPS, movement, time, hole context → 5 signal types in scorer + tests
  - [ ] AC2: Confidence thresholds determine behavior → 4-level enum + threshold config + UI behavior tests
  - [ ] AC3: Practice swings, cart movement, nearby golfers, short shots, penalties, mulligans → 6 filter tests
- Offline: Suggestions persist locally before sync
- Accessibility: Confidence indicator non-color-only, ≥44pt targets, screen reader labels

### Anti-Shortcut Evidence
- ShotDetectionSignals has exactly 5 signal types (gps, accelerometer, gyroscope, time, holeContext) matching AC1
- ConfidenceLevel has exactly 4 levels (discard, reviewLater, confirm, automatic) matching AC2
- ShotFilter has exactly 6 filter types matching AC3

---

## Execution Order

```
Slice 1 (domain models) →
  Slice 2 (scorer) →
    Slice 7 (config) →
      Slice 4 (filter) →
        Slice 5 (repository) →
          Slice 3 (service+cubit) →
            Slice 6 (UI) →
              Slice 8 (10.3 integration)
```

**Parallelization**: Slices 1, 2, 7 can run in parallel (pure models + pure functions, no deps). Slices 3/5/6 depend on Slice 1. Slice 8 depends on Story 10.3.

---

## Estimated Slices: 8
## Priority: HIGH — Core MVP 2 automatic shot detection
