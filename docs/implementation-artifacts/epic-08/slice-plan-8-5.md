# Slice Plan — Story 8.5: Manage Pins, Green Speed, and Conditions

## Story Metadata

| Field | Value |
|-------|-------|
| Story ID | 8.5 |
| Epic | 8 — Course Operations Portal |
| Title | Manage Pins, Green Speed, and Conditions |
| Status | `ready-for-dev` → `in-progress` |
| Phase | MVP 1 |
| Run Folder | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |
| Dependency | Story 8.4 (Roll Back Published Data) — outputs required as foundation |

## User Story

As a greenkeeper, I want to schedule operational data so that golfers see timely official conditions.

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|---------------|
| AC-1 | User can place/schedule pins with effective + expiration times | API contract test |
| AC-2 | User can update green speed (stimpmeter), firmness, moisture, maintenance, course status | API contract test |
| AC-3 | Effective and expiration times are required where applicable | Validation test |
| AC-4 | Mobile sync reflects newly published operational data | Package manifest / sync integration test |

## Context from PRD, Architecture, UX

### PRD §8.11 — Course Operations Portal
- Admin can update pin positions, green speed, conditions, and alerts.
- Every published change creates version history and audit log.
- FR15: Course operators can schedule pin positions and update green/course conditions.

### Architecture §6 — Modular Monolith
- `Course Operations Module` is a bounded module.
- Course data is append-versioned: draft → validate → publish → package → distribute.
- Effective and expiration dates for pins, green speed, weather snapshots, and conditions.
- Portal must use admin RBAC from day one: Greenkeeper role can update pins/conditions.

### Architecture §7 — Data Model
- Pin Position entity with effective/expiration timestamps.
- Green Condition entity: speed (stimpmeter), firmness, moisture.
- Course Condition entity: overall status, maintenance, alerts.
- Data quality fields: confidence, verification status, accuracy class, source, publisher.

### UX Spec §7.2 — Portal Navigation
- Portal has "Pin Positions" and "Green & Course Conditions" as primary modules.

### Story 7.3 Context (Conditions Display)
- Conditions display shows: official status, source, effective/expiry time, confidence, stale state.
- Cached conditions remain available offline.
- Expired exact pin data is never presented as current official data.
- These ACs are the consumer side of 8.5's write operations.

### Conditions snapshot already in package manifest
- `packages/contracts/schemas/course.yaml` defines `ConditionDto` with `conditionType`, `severity`, `description`, `effectiveDate`, `dataQuality`.
- `CoursePackageManifest` has `conditionsUrl` pointing to `conditions.json` snapshot.

## Gap Analysis — What Exists vs. What's Needed

| Area | Status | Gap |
|------|--------|-----|
| `PinPosition` entity | Does not exist | Must be created |
| `GreenCondition` entity | Does not exist | Must be created |
| `CourseCondition` entity | Partial — `ConditionDto` in API schema | Need backend entity + repo |
| OperationsService stub | Empty interface | Must implement |
| Admin REST endpoints | No pin/condition endpoints | Must create |
| OpenAPI schemas | `ConditionDto` exists | Must add `PinPositionDto`, update `ConditionDto` |
| Package manifest | Has `conditionsUrl` | Need to populate `conditions.json` in package build |
| RBAC | Greenkeeper role defined in architecture | Must enforce on endpoints |

## Slice Plan

### Phase 1: Domain & Contract Layer (no-op safe, shared)

**1.1** Add OpenAPI schemas:
- `PinPositionDto` — holeNumber, position (GeoJSON Point), effectiveFrom, expiresAt, publishedBy, confidence, dataQuality
- `GreenSpeedDto` — holeNumber, stimpmeterReading, firmness, moisture, effectiveFrom, expiresAt, publishedBy
- `CourseConditionItemDto` — conditionType (enum), severity, description, effectiveFrom, expiresAt, publishedBy
- Update `admin.yaml` with request/response DTOs for CRUD operations

**1.2** Create domain entities in `apps/api/src/main/java/vnpt/vsp/module/operations/entity/`:
- `PinPosition.java` — hole reference, geometry (SRID 4326 Point), effectiveFrom, expiresAt, publishedBy, confidence, dataQuality
- `GreenCondition.java` — hole reference, stimpmeterReading, firmness (enum), moisture (enum), effectiveFrom, expiresAt, publishedBy
- `CourseCondition.java` — course reference, conditionType, severity, description, effectiveFrom, expiresAt, publishedBy

**1.3** Create repositories:
- `PinPositionRepository.java`
- `GreenConditionRepository.java`
- `CourseConditionRepository.java`

**1.4** Extend `CoursePackageManifest` to include conditions snapshot in package build output.

---

### Phase 2: Service Layer

**2.1** Implement `OperationsService` methods:
- `createPinPosition(courseId, holeNumber, position, effectiveFrom, expiresAt, publishedBy)` — saves PinPosition, returns DTO
- `updatePinPosition(id, position, effectiveFrom, expiresAt)` — updates existing
- `getPinPositions(courseId, holeNumber, asOfDate)` — returns active pins as of date
- `createGreenCondition(courseId, holeNumber, stimpmeter, firmness, moisture, effectiveFrom, expiresAt, publishedBy)`
- `updateGreenCondition(id, values)` — updates existing
- `getGreenConditions(courseId, holeNumber, asOfDate)` — returns active conditions
- `createCourseCondition(courseId, conditionType, severity, description, effectiveFrom, expiresAt, publishedBy)`
- `updateCourseCondition(id, values)`
- `getCourseConditions(courseId, asOfDate)` — returns active conditions
- `publishOperationalData(courseId)` — triggers async package rebuild with new conditions snapshot

**2.2** Add audit logging for all write operations.

**2.3** Enforce RBAC: only GREENKEEPER or higher role can call write endpoints.

---

### Phase 3: Controller Layer

**3.1** Create `PinPositionController.java`:
- `POST /admin/courses/{courseId}/holes/{holeNumber}/pins`
- `PUT /admin/courses/{courseId}/holes/{holeNumber}/pins/{pinId}`
- `GET /admin/courses/{courseId}/holes/{holeNumber}/pins`
- `GET /admin/courses/{courseId}/pins` (all holes)

**3.2** Create `GreenConditionController.java`:
- `POST /admin/courses/{courseId}/holes/{holeNumber}/green-conditions`
- `PUT /admin/courses/{courseId}/holes/{holeNumber}/green-conditions/{conditionId}`
- `GET /admin/courses/{courseId}/holes/{holeNumber}/green-conditions`
- `GET /admin/courses/{courseId}/green-conditions` (all holes)

**3.3** Create `CourseConditionController.java`:
- `POST /admin/courses/{courseId}/conditions`
- `PUT /admin/courses/{courseId}/conditions/{conditionId}`
- `GET /admin/courses/{courseId}/conditions`

---

### Phase 4: Integration — Package Build

**4.1** Modify `PackageGenerationService` to include conditions snapshot:
- Query active PinPositions, GreenConditions, CourseConditions as of `effectiveFrom`
- Write `conditions.json` with pin positions + all conditions
- Add to `PackageFileEntry` with `contentType: CONDITIONS`

---

### Phase 5: Tests

**5.1** Unit tests for service layer:
- Pin position CRUD with effective/expires validation
- Green condition CRUD with stimpmeter range validation [6-14]
- Course condition CRUD with conditionType enum
- Active-as-of queries return correct temporal slice
- Publish triggers package rebuild

**5.2** Controller integration tests:
- Auth: unauthorized returns 403
- Validation: missing effective/expires returns 400
- Happy path: CRUD round-trip

**5.3** Repository tests with embedded PostgreSQL (if test container available).

---

### Phase 6: Validation Gates

**6.1** Format: `mvn fmt:format` or equivalent
**6.2** Lint: `mvn checkstyle:check`
**6.3** Compile: `mvn compile`
**6.4** Tests: `mvn test`
**6.5** Package build: verify `conditions.json` included in manifest

## Constraints & Notes

- **8.4 dependency**: If 8.4 is not yet complete, fall back to existing version/publish infrastructure from 8.3. The rollback story provides rollback ACs; 8.5 is write-only on operational data and does not require rollback to function.
- **Effective/expires required**: Validation must reject requests without effectiveFrom. expiresAt is required for pins (Temporal Validation AC).
- **No geospatial fabrication**: Pin coordinates must be valid SRID 4326 points. Use `ST_SetSRID(ST_MakePoint(lng, lat), 4326)` with PostGIS validation.
- **Stale pin handling**: Query returns only pins where `now() BETWEEN effectiveFrom AND expiresAt` (or expiresAt IS NULL for indefinite).
- **Audit**: All write operations logged via existing `AuditModule`.
- **Portal UI**: Not in scope for this story (backend only). Portal screens are separate implementation work.

## File Changes

```
NEW:
  apps/api/src/main/java/vnpt/vsp/module/operations/entity/PinPosition.java
  apps/api/src/main/java/vnpt/vsp/module/operations/entity/GreenCondition.java
  apps/api/src/main/java/vnpt/vsp/module/operations/entity/CourseCondition.java
  apps/api/src/main/java/vnpt/vsp/module/operations/repository/PinPositionRepository.java
  apps/api/src/main/java/vnpt/vsp/module/operations/repository/GreenConditionRepository.java
  apps/api/src/main/java/vnpt/vsp/module/operations/repository/CourseConditionRepository.java
  apps/api/src/main/java/vnpt/vsp/module/operations/PinPositionController.java
  apps/api/src/main/java/vnpt/vsp/module/operations/GreenConditionController.java
  apps/api/src/main/java/vnpt/vsp/module/operations/CourseConditionController.java
  apps/api/src/main/java/vnpt/vsp/module/operations/OperationsServiceImpl.java (extend)
  packages/contracts/schemas/admin.yaml (add PinPositionDto, GreenSpeedDto, CourseConditionItemDto)

MODIFY:
  apps/api/src/main/java/vnpt/vsp/module/operations/OperationsService.java (add methods)
  apps/api/src/main/java/vnpt/vsp/module/operations/OperationsModule.java (wire beans)
  packages/contracts/openapi.yaml (add /admin/courses/{id}/pins, /admin/courses/{id}/green-conditions, /admin/courses/{id}/conditions paths)
  apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java (include conditions snapshot)
```

## Anti-Shortcuts

- ❌ Do NOT skip entity modeling and use Map<String,Object> — domain model must be proper JPA entities
- ❌ Do NOT skip expiresAt requirement for pins — temporal correctness is an explicit AC
- ❌ Do NOT skip RBAC — greenkeeper role enforcement is required
- ❌ Do NOT skip audit logging — all mutations must be auditable per architecture
- ❌ Do NOT publish to mobile without package rebuild — conditions must flow through package build pipeline
- ❌ Do NOT use hardcoded course IDs — all operations are course-scoped
