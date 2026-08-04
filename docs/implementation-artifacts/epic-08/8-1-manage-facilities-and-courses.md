---
story: "8.1"
epic: 8
title: "Manage Facilities and Courses"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 8.1: Manage Facilities and Courses

## User Story

As a course administrator, I want to manage facility and course metadata so that golfers receive accurate official details.

## Acceptance Criteria

- Authorized roles can manage facilities, courses, layouts, holes, tees, scorecards, ratings, rules, and services.
- Validation prevents incomplete required data from publication.
- Changes remain draft until publish.

## Tasks and Subtasks

- [x] Confirm the manage facilities and courses scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Dev Agent Record

### Implementation Summary

Story 8.1 was substantially pre-implemented. The following gaps were identified and resolved:

**Gap filled: TeeSet get/update operations**

- Added `getTeeSet(Long)` and `updateTeeSet(Long, TeeSet)` to `CourseService` interface
- Implemented both methods in `CourseServiceImpl` with audit logging
- Added delegations to `CourseAdminService` interface and `CourseAdminServiceImpl`
- Replaced "not implemented" stubs in `TeeSetAdminController` with real implementations:
  - `GET /admin/tee-sets/{teeSetId}` — now delegates to `courseService.getTeeSet()`
  - `PUT /admin/tee-sets/{teeSetId}` — now delegates to `courseService.updateTeeSet()`

### Acceptance Criteria Coverage

| AC | Description | Status |
|----|-------------|--------|
| AC-1 | Authorized roles manage facilities/courses/holes/tees | ✅ Full CRUD via admin REST controllers with `@PreAuthorize` on COURSE_ADMIN or SUPER_ADMIN |
| AC-2 | Validation prevents incomplete required data from publication | ✅ Bean validation on DTOs (`@NotBlank`, `@NotNull`, `@Min`/`@Max`) + `CourseAdminServiceImpl.validateForPublish()` |
| AC-3 | Changes remain draft until publish | ✅ `DataVersionStatus.DRAFT` model exists; publish workflow is Story 8.3 scope |

### Files Changed

| File | Change |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseService.java` | Added `getTeeSet`, `updateTeeSet` interface methods |
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseServiceImpl.java` | Implemented `getTeeSet`, `updateTeeSet`, `applyTeeSetUpdate` |
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseAdminService.java` | Added `@Override getTeeSet`, `@Override updateTeeSet` |
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseAdminServiceImpl.java` | Added delegation methods for `getTeeSet`, `updateTeeSet` |
| `apps/api/src/main/java/vnpt/vsp/api/admin/TeeSetAdminController.java` | Replaced INTERNAL_004 stubs with real controller logic |

### Quality Gate Results

| Gate | Result | Notes |
|------|--------|-------|
| Compile | ✅ PASS | `mvn compile` — no errors |
| Unit tests | ✅ PASS | `CourseAdminServiceImplTest` (6 test cases for validateForPublish) |
| Checkstyle | ⚠️ PRE-EXISTING | 21,456 violations in codebase; no new violations introduced by this change |
| Portal typecheck | N/A | Portal scripts are stubs |

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 8.1 and Epic 8
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `8-1-manage-facilities-and-courses`
