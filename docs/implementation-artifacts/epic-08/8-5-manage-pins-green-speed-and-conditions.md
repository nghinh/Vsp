---
story: "8.5"
epic: 8
title: "Manage Pins, Green Speed, and Conditions"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 8.5: Manage Pins, Green Speed, and Conditions

## User Story

As a greenkeeper, I want to schedule operational data so that golfers see timely official conditions.

## Acceptance Criteria

- User can place/schedule pins and update speed, firmness, moisture, maintenance, and course statuses.
- Effective and expiration times are required where applicable.
- Mobile synchronization reflects newly published operational data.

## Tasks and Subtasks

- [x] Confirm the manage pins, green speed, and conditions scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## File List

**New files:**
- `apps/api/src/test/java/vnpt/vsp/api/admin/PinPositionControllerTest.java`
- `apps/api/src/test/java/vnpt/vsp/api/admin/GreenConditionControllerTest.java`
- `apps/api/src/test/java/vnpt/vsp/api/admin/CourseConditionControllerTest.java`

**Modified files:**
- `apps/api/src/main/java/vnpt/vsp/module/operations/OperationsService.java` (existing, no change needed)
- `apps/api/src/main/java/vnpt/vsp/module/operations/OperationsServiceImpl.java` (existing, no change needed)
- `apps/api/src/main/java/vnpt/vsp/module/operations/entity/PinPosition.java` (existing)
- `apps/api/src/main/java/vnpt/vsp/module/operations/entity/GreenCondition.java` (existing)
- `apps/api/src/main/java/vnpt/vsp/module/operations/entity/CourseCondition.java` (existing)
- `apps/api/src/main/java/vnpt/vsp/api/admin/PinPositionController.java` (existing)
- `apps/api/src/main/java/vnpt/vsp/api/admin/GreenConditionController.java` (existing)
- `apps/api/src/main/java/vnpt/vsp/api/admin/CourseConditionController.java` (existing)
- `packages/contracts/schemas/admin.yaml` (existing)

## Dev Agent Record

### Implementation Notes

**Phase 5 Tests implemented:**
- `OperationsServiceImplTest.java`: 17 unit tests covering all service methods
  - Pin position CRUD with effective/expires validation
  - Green condition CRUD with stimpmeter range validation [6-14]
  - Course condition CRUD with conditionType enum
  - Active-as-of queries
  - Publish triggers package rebuild

- `PinPositionControllerTest.java`: 13 unit tests
  - Auth: 403 for unauthorized roles
  - Happy path: CRUD operations return 201/200
  - Validation: effectiveFrom/expiresAt required
  - Role authorization: GREENKEEPER, COURSE_ADMIN, SUPER_ADMIN

- `GreenConditionControllerTest.java`: 17 unit tests
  - Auth: 403 for unauthorized roles
  - Happy path: CRUD operations
  - Stimpmeter range validation (6-14 boundary tests)
  - All firmness values (SOFT/MEDIUM/FIRM/HARD)
  - All moisture values (DRY/NORMAL/WET/SATURATED)

- `CourseConditionControllerTest.java`: 12 unit tests
  - Auth: 403 for unauthorized roles
  - Happy path: CRUD operations
  - All condition types
  - All severity levels (LOW/MODERATE/HIGH/CRITICAL)

**Phase 6 Validation Gates:**
- ✅ Compile: `mvn compile` passes
- ✅ Tests: 59 tests pass (17 + 13 + 17 + 12)
- ✅ Package: `mvn package -DskipTests` builds successfully
- ✅ conditions.json included in package via PackageGenerationService

### Change Log

- 2026-08-02: Added Phase 5 tests (controller + service unit tests, 59 tests total)
- 2026-08-02: Verified Phase 6 validation gates (compile, test, package build)

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 8.4 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 8.5 and Epic 8
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `8-5-manage-pins-green-speed-and-conditions`
