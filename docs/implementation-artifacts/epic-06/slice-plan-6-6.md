# Slice Plan — Story 6.6: Validate Pilot GPS Accuracy and Battery

**Story**: 6.6  
**Epic**: 6 — Live Golf GPS Experience  
**Status**: `ready-for-dev`  
**Phase**: MVP 1  
**Run Folder**: `docs/vnpt-flow/epic-run-run_2026_08_02_010/`  
**Planned**: 2026-08-02  

---

## 1. Story Analysis

### 1.1 What This Story Actually Does

This is a **validation and telemetry infrastructure story** — NOT a feature-implementation story.  
It does not add new golfer-facing UI or business logic. Instead it:

1. **Defines a field test protocol** for comparing displayed distances against agreed RTK (Real-Time Kinematic) survey checkpoints at pilot courses.
2. **Builds telemetry recording** so the app records GPS accuracy, map rendering latency, and battery consumption during real rounds.
3. **Documents acceptance criteria** for the 95% critical-point mapping accuracy and 18-hole battery target.

### 1.2 Dependencies Analysis

| Story | Title | Status | Dependency Weight |
|-------|-------|--------|-------------------|
| 6.1 | Acquire and Qualify Location | `backlog` | **BLOCKING** — provides GPS location model + accuracy qualification |
| 6.2 | Detect Course and Hole | `backlog` | **BLOCKING** — provides hole detection confidence |
| 6.3 | Render Strategic Hole Map | `backlog` | **BLOCKING** — provides map rendering + latency source |
| 6.4 | Calculate Green and Hazard Distances | `backlog` | **BLOCKING** — provides distance display output to validate |
| 6.5 | Place and Move a Target | `backlog` | **BLOCKING** — provides target distance output to validate |

**All 5 prerequisite stories are `backlog`** — none have been implemented yet.

### 1.3 What CAN Be Built Before Prerequisite Stories

Certain infrastructure can be built independently:

- **Telemetry domain models** (battery telemetry, GPS quality telemetry, map latency events)
- **Telemetry service interface** (abstract recording API that 6.1–6.5 will call)
- **Field test protocol documentation** (markdown spec for RTK checkpoint validation methodology)
- **Validation thresholds** defined as constants/config

### 1.4 Slices

#### Slice A: Telemetry Domain Models and Contracts
**Goal**: Define telemetry data structures for GPS quality, map latency, and battery telemetry before GPS is implemented.

- `packages/contracts/lib/src/dto/gps_telemetry_dto.dart` — DTO for GPS quality telemetry events
- `packages/contracts/lib/src/dto/battery_telemetry_dto.dart` — DTO for battery consumption events
- `packages/contracts/lib/src/dto/map_latency_dto.dart` — DTO for map rendering latency events
- `packages/domain/lib/src/telemetry/gps_quality_telemetry.dart` — domain model
- `packages/domain/lib/src/telemetry/battery_telemetry.dart` — domain model
- `packages/domain/lib/src/telemetry/map_latency_telemetry.dart` — domain model

#### Slice B: Telemetry Service Interface + Local Persistence
**Goal**: Define the telemetry recording service that GPS (6.1), map (6.3), and battery infrastructure will call.

- `apps/mobile/lib/data/services/telemetry_service.dart` — abstraction for recording telemetry events
- `apps/mobile/lib/data/local/daos/telemetry_dao.dart` — SQLite DAO for persisting telemetry locally before sync
- `apps/mobile/lib/data/local/tables/telemetry_table.dart` — table definition
- `apps/mobile/lib/data/repositories/telemetry_repository.dart` — repository implementation

#### Slice C: Field Test Protocol Documentation
**Goal**: Author the field validation protocol that the product team will execute at pilot courses.

- `docs/implementation-artifacts/epic-06/field-test-protocol.md` — RTK checkpoint validation methodology, pass/fail thresholds, test procedures, reporting template

#### Slice D: GPS Accuracy and Battery Validation Specification
**Goal**: Document the quantitative acceptance criteria as executable validation specs.

- `docs/implementation-artifacts/epic-06/gps-accuracy-validation-spec.md` — 95% critical point mapping accuracy spec with checkpoint categories
- `docs/implementation-artifacts/epic-06/battery-validation-spec.md` — 18-hole battery target spec with device matrix

### 1.5 Dependency Chain

```
Slice A (telemetry models)
    ↓
Slice B (telemetry service + persistence)
    ↓
Stories 6.1–6.5 (call telemetry service)
    ↓
Slice C+D (validation docs reference telemetry outputs from 6.1–6.5)
```

### 1.6 Story Status After Planning

`status: in-progress` — slice plan created, implementation can begin on Slice A independently.

---

## 2. Acceptance Criteria Mapping

| AC | Description | Slices | Evidence Required |
|----|-------------|--------|-------------------|
| AC-1 | Test protocol compares displayed distances against agreed RTK checkpoints | Slice C | `field-test-protocol.md` exists and defines RTK checkpoint procedure |
| AC-2 | At least 95% of critical points meet agreed mapping criteria | Slice D | `gps-accuracy-validation-spec.md` defines 95% threshold and critical point categories |
| AC-3 | Target devices complete 18 holes within battery goal; GPS/map latency telemetry is recorded | Slices B, D | Battery telemetry DTO + service + DAO; `battery-validation-spec.md` defines 18-hole target |

---

## 3. Files to Create/Modify

### New Files

```
packages/contracts/lib/src/dto/gps_telemetry_dto.dart
packages/contracts/lib/src/dto/battery_telemetry_dto.dart
packages/contracts/lib/src/dto/map_latency_dto.dart
apps/mobile/lib/domain/models/telemetry/gps_quality_telemetry.dart
apps/mobile/lib/domain/models/telemetry/battery_telemetry.dart
apps/mobile/lib/domain/models/telemetry/map_latency_telemetry.dart
apps/mobile/lib/data/services/telemetry_service.dart
apps/mobile/lib/data/local/daos/telemetry_dao.dart
apps/mobile/lib/data/local/tables/telemetry_table.dart
apps/mobile/lib/data/repositories/telemetry_repository.dart
docs/implementation-artifacts/epic-06/field-test-protocol.md
docs/implementation-artifacts/epic-06/gps-accuracy-validation-spec.md
docs/implementation-artifacts/epic-06/battery-validation-spec.md
```

### Modified Files

```
docs/implementation-artifacts/epic-06/6-6-validate-pilot-gps-accuracy-and-battery.md  — update status to in-progress
docs/implementation-artifacts/sprint-status.yaml  — update 6-6-validate-pilot-gps-accuracy-and-battery: backlog → in-progress
```

---

## 4. Non-Functional Requirements Coverage

| NFR | Source | Coverage |
|-----|--------|----------|
| NFR7: GPS accuracy visible; stale/>10m positions trigger warning | PRD §10 | Telemetry captures accuracy; 6.1 UI will surface it |
| NFR8: ≥95% critical points correctly mapped at pilot courses | PRD §10, §11 | Documented in Slice D spec |
| NFR4: Mobile devices complete 18 holes within battery target | PRD §10 | Documented in Slice D spec |
| NFR15: Telemetry covers GPS quality, map load, battery | PRD §13 | Implemented in Slices A+B |

---

## 5. Constraints and Open Decisions

### 5.1 Blockers
- **Stories 6.1–6.5 are all `backlog`** — telemetry service cannot be fully wired to GPS/map rendering until those stories implement their surfaces.
- **Pilot courses not yet defined** — RTK checkpoint locations require physical course survey data from pilot partners (open decision #1 in PRD).
- **Target devices not specified** — battery validation requires a defined device matrix (open decision deferred to field team).

### 5.2 What This Story Does NOT Include
- No actual GPS location acquisition logic (→ story 6.1)
- No actual map rendering (→ story 6.3)
- No actual distance calculation (→ story 6.4)
- No actual target placement (→ story 6.5)
- No physical RTK survey execution — this is a documentation + telemetry infrastructure story

---

## 6. Verification Plan

| Slice | Verification |
|-------|--------------|
| Slice A | All telemetry DTOs parse/serialize correctly; domain models validate invariants |
| Slice B | TelemetryService interface is callable; DAO writes/reads from SQLite; repository persists |
| Slice C | Field test protocol document covers RTK procedure, checkpoint categories, pass/fail criteria, reporting template |
| Slice D | GPS accuracy spec defines 95% threshold + critical point categories; battery spec defines 18-hole target + device matrix |

---

## 7. Planning Evidence

| Evidence | Source |
|----------|--------|
| Stories 6.1–6.5 are all `backlog` | `docs/implementation-artifacts/sprint-status.yaml` lines 55–60 |
| Epic 6 is `backlog` not `in-progress` | `sprint-status.yaml` line 54 |
| GPS telemetry requirement from PRD | `docs/planning-artifacts/prd.md` lines 318–323 (NFR7, NFR8) |
| Battery telemetry requirement from PRD | `docs/planning-artifacts/prd.md` lines 359–366 (NFR4, battery observability) |
| GPS and battery telemetry in architecture | `docs/planning-artifacts/architecture.md` lines 196–202 |
| Observability telemetry requirement | `docs/planning-artifacts/architecture.md` lines 305–319 (NFR15) |
| 95% pilot mapping accuracy target | `docs/planning-artifacts/prd.md` line 335, `epics.md` line 442 |
| 18-hole battery target | `docs/planning-artifacts/prd.md` line 361, `epics.md` line 443 |
| No existing GPS domain models | `glob apps/mobile/lib/**/gps*.dart` and `location*.dart` returned 0 results |
| No existing telemetry models | No `telemetry` domain models found in codebase |

---

**Status**: `in-progress`  
**Next Action**: Dispatch implementer for Slice A (telemetry domain models + contracts)  
**Ready for**: Implementer dispatch by `vnpt-dev-epic-orchestrator`
