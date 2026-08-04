# Slice Plan — Story 6.2: Detect Course and Hole

## Story Metadata

| Field | Value |
|-------|-------|
| Story ID | 6.2 |
| Epic | 6 — Location Acquisition |
| Title | Detect Course and Hole |
| Status | `in-progress` |
| Phase | MVP 1 |
| Source | `docs/planning-artifacts/epics.md` |
| Run Folder | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |

---

## 1. Context and Scope

### 1.1 User Story
As a golfer, I want automatic course/hole detection so that the app follows play with minimal interaction.

### 1.2 Key Requirements from Story Spec
- Detection combines proximity, hole geometry, direction, and confidence.
- Low-confidence detection does not auto-switch holes.
- User can manually select a hole; overrides and incorrect detections are logged.

### 1.3 Dependencies
| Dependency | Reason |
|---|---|
| Story 6.1 (Acquire and Qualify Location) | 6.1 delivers `QualifiedLocation` stream consumed by 6.2 for course/hole detection input |
| Story 3.1 (Model Course and Golf Geometry) | 3.1 delivers PostGIS schema + domain models for Facility, Course, Hole, TeeBox, Green geometry — required for spatial queries |

> **Note**: Story 6.1 is also `ready-for-dev`. Both are independent enough to plan in parallel. 6.2's slice plan assumes `QualifiedLocation` will be available from 6.1's output. The `HoleDetectionService` interface will be defined here and implemented once 6.1 delivers `QualifiedLocation`.

### 1.4 Out of Scope
- Automatic shot tracking
- Smart Caddie / AI recommendations
- Watch/smartwatch integration
- Tournament platform

---

## 2. Architecture and Design Decisions

### 2.1 Detection Algorithm Design

The course/hole detection follows a **multi-signal confidence scoring** approach:

```
GPS Position
    │
    ├──[Facility Filter]──► Nearest Facility (ST_DWithin 200m radius)
    │
    ├──[Course Filter]────► Nearest Course within Facility
    │
    ├──[Hole Geometry]────► Per-hole scoring:
    │                           - Distance to tee-box centroid (weight: 0.3)
    │                           - Distance to green centroid (weight: 0.3)
    │                           - Heading alignment with hole direction (weight: 0.2)
    │                           - GPS accuracy signal (weight: 0.2)
    │
    └──[Confidence Threshold]► Low-confidence lockout (< 0.6 → no auto-switch)
```

**Confidence levels:**
| Score | Level | Behavior |
|---|---|---|
| 0.0 – 0.4 | LOW | No auto-switch; prompt manual selection |
| 0.4 – 0.6 | MEDIUM | No auto-switch; show suggestion |
| 0.6 – 0.8 | HIGH | Auto-switch enabled |
| 0.8 – 1.0 | VERY_HIGH | Auto-switch with confirmation toast |

### 2.2 Data Flow

```
QualifiedLocation (from 6.1)
    │
    ▼
CourseHoleDetectionService
    │
    ├── FacilityRepository.findNearby(lat, lon, radius=200m)
    │
    ├── CourseRepository.findWithinFacility(facilityId)
    │
    ├── HoleRepository.findByCourseWithGeometry(courseId)
    │       └── Returns: List<HoleGeometry> (teeBox, green, direction)
    │
    ├── HoleDetectionScorer.score(currentLocation, holeGeometries)
    │
    └── DetectionResult { holeId, confidence, level, isAutoSwitch }
```

### 2.3 Domain Models (Flutter / Dart)

```dart
// QualifiedLocation — input from story 6.1
class QualifiedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? heading; // degrees, 0=North
  final LocationSource source;
  final bool isStale;
}

// CourseHoleDetectionResult
class CourseHoleDetectionResult {
  final String? facilityId;
  final String? courseId;
  final int? holeNumber;
  final String? teeBoxId;
  final String? greenId;
  final double confidence; // 0.0 – 1.0
  final ConfidenceLevel level;
  final bool canAutoSwitch;
  final CourseHoleDetectionReason reason;
  final DateTime detectedAt;
}

// ConfidenceLevel enum
enum ConfidenceLevel { low, medium, high, veryHigh }

// ManualHoleSelection — logged for audit
class ManualHoleSelection {
  final String? detectedHoleId;
  final String selectedHoleId;
  final ManualSelectionReason reason; // override, correction, userChoice
  final double confidenceBefore;
  final QualifiedLocation locationAtSelection;
  final DateTime selectedAt;
}
```

### 2.4 Persistence

- `ManualHoleSelection` entries appended to local SQLite table `hole_selection_log` — synced to backend for quality improvement.
- Detection confidence events emitted for observability (per architecture §13).

---

## 3. Slice Plan — Implementation Waves

### Wave A: Interface & Model Definitions
**Goal**: Define contracts before implementation

- [ ] Define `CourseHoleDetectionService` abstract interface
- [ ] Define `QualifiedLocation` input model (from 6.1)
- [ ] Define `CourseHoleDetectionResult` output model
- [ ] Define `ManualHoleSelection` audit model
- [ ] Add `ConfidenceLevel` enum
- [ ] Add `ManualSelectionReason` enum
- [ ] Add repository interfaces: `FacilityRepository`, `CourseRepository`, `HoleRepository`
- [ ] Add `HoleDetectionScorer` pure function class

**Files touched**: `packages/domain/lib/` new files

**Tests**: Model constructor tests, enum tests

---

### Wave B: Geospatial Query Layer
**Goal**: Efficient spatial queries for facility/course/hole lookup

- [ ] `FacilityRepository.findNearby(lat, lon, radius)` — PostGIS `ST_DWithin`
- [ ] `CourseRepository.findWithinFacility(facilityId)` — simple filter
- [ ] `HoleRepository.findByCourseWithGeometry(courseId)` — returns tee-box + green centroids + hole direction bearing

**Files touched**: `packages/domain/lib/repositories/` — new repository implementations against PostgreSQL/PostGIS

**Tests**: Spatial query unit tests with mock PostGIS

---

### Wave C: Detection Algorithm
**Goal**: Core confidence scoring and detection logic

- [ ] `HoleDetectionScorer.computeScore(QualifiedLocation, List<HoleGeometry>)` — weighted multi-signal scoring
- [ ] `CourseHoleDetectionService.detect(QualifiedLocation)` — orchestrator wiring all signals
- [ ] `CourseHoleDetectionService.detectWithManualOverride(QualifiedLocation, String manualHoleId, ManualSelectionReason)`
- [ ] Low-confidence lockout enforcement: `canAutoSwitch = confidence >= 0.6`
- [ ] Logging of incorrect detection events

**Files touched**: `packages/domain/lib/services/` new files

**Tests**: Score computation tests, edge case tests (no holes nearby, GPS accuracy low, adjacent holes)

---

### Wave D: Manual Override & Audit
**Goal**: User-initiated hole selection with logging

- [ ] `HoleSelectionLogRepository.append(ManualHoleSelection)` — SQLite append
- [ ] `HoleSelectionLogRepository.queryByRound(String roundId)` — for sync
- [ ] Manual hole selector UI component (accessible, one-hand, two-tap)
- [ ] "Switch to Hole X" confirmation dialog when auto-switch blocked

**Files touched**: `apps/mobile/lib/` — mobile layer components

**Tests**: Override flow integration tests

---

### Wave E: Integration & Offline
**Goal**: End-to-end wiring + offline resilience

- [ ] `CourseHoleDetectionService` wired to `QualifiedLocation` stream from 6.1's location service
- [ ] Offline behavior: last known detection cached in SQLite; restored on app restart
- [ ] GPS low-accuracy / stale-position handling (pass through from 6.1)
- [ ] Round-context integration: detection scoped to active round's course

**Files touched**: `apps/mobile/lib/` — integration wiring

**Tests**: Offline restart recovery test, round-context test

---

### Wave F: Observability & Validation
**Goal**: Metrics, error handling, accessibility

- [ ] Detection confidence emitted to telemetry
- [ ] Incorrect detection events logged with location snapshot
- [ ] Accessibility: screen reader announces hole change, non-color-only confidence indicator
- [ ] Error: no facility found → empty state with manual search CTA
- [ ] Error: GPS unavailable → graceful degradation message

**Files touched**: across layers

**Tests**: A11y smoke test, error state test

---

## 4. Verification Plan

### 4.1 Automated Tests

| Wave | Test Type | Coverage |
|---|---|---|
| A | Unit | Model validation, enum exhaustiveness |
| B | Unit | Spatial query construction, SRID correctness |
| C | Unit | Confidence scoring boundaries, low-confidence lockout |
| C | Unit | Adjacent hole disambiguation, heading alignment |
| D | Integration | Manual override → log append |
| E | Integration | Offline restart → cached detection restored |
| E | Unit | Stale GPS → detection blocked |
| F | A11y | Screen reader, color-only-free confidence UI |

### 4.2 Manual Verification Checklist

- [ ] Distance to each hole geometry centroid computed correctly
- [ ] Heading alignment computed from tee-box → green bearing
- [ ] Low-confidence (< 0.6) prevents auto-switch on simulator
- [ ] Manual override logged and appears in round audit
- [ ] Detection survives app restart with offline package
- [ ] Hole switch confirmation dialog appears correctly

---

## 5. File List (Planned)

| File | Purpose | Layer |
|---|---|---|
| `packages/domain/lib/models/course_hole_detection.dart` | Detection result + enums | Domain |
| `packages/domain/lib/models/qualified_location.dart` | Location input model | Domain |
| `packages/domain/lib/models/manual_hole_selection.dart` | Audit log model | Domain |
| `packages/domain/lib/repositories/facility_repository.dart` | Facility query interface | Domain |
| `packages/domain/lib/repositories/course_repository.dart` | Course query interface | Domain |
| `packages/domain/lib/repositories/hole_repository.dart` | Hole geometry query interface | Domain |
| `packages/domain/lib/services/course_hole_detection_service.dart` | Main detection orchestrator | Domain |
| `packages/domain/lib/services/hole_detection_scorer.dart` | Pure confidence scoring | Domain |
| `packages/domain/lib/repositories/hole_selection_log_repository.dart` | SQLite audit log | Infrastructure |
| `apps/mobile/lib/features/play/services/course_hole_detection_service_impl.dart` | Mobile implementation | Mobile |
| `apps/mobile/lib/features/play/widgets/hole_switch_confirmation_dialog.dart` | Manual override UI | Mobile |
| `apps/mobile/test/course_hole_detection_test.dart` | Unit + integration tests | Test |

---

## 6. Open Decisions

| Decision | Options | Recommendation |
|---|---|---|
| Detection update frequency | Every location update vs. 5s interval | Every qualified location update from 6.1 |
| Adjacent hole tie-breaking | Use heading + distance combo | Heading alignment as tiebreaker |
| Manual override persistence | SQLite only vs. sync to backend | SQLite first, sync when online |
| Confidence weight distribution | Fixed weights vs. adaptive | Fixed weights for MVP; adaptive deferred |

---

## 7. Anti-Shortcuts Evidence

- [x] Did NOT assume 6.1 is complete — defined `QualifiedLocation` interface that 6.1 will implement
- [x] Did NOT skip spatial query layer — PostGIS `ST_DWithin` + GIST indexes required for performance
- [x] Did NOT defer logging — incorrect detection events are part of AC (logged for quality improvement)
- [x] Did NOT skip accessibility — screen reader hole-change announcements required per UX spec §10
- [x] Did NOT skip offline resilience — cached detection on restart is required for continuous round experience
