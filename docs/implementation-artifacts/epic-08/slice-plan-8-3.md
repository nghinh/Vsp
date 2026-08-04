# Slice Plan — Story 8.3: Validate and Publish Course Version

**Story:** 8.3 — Validate and Publish Course Version  
**Epic:** 8 — Course Operations Portal  
**Status:** ready-for-dev → in-progress  
**Run Folder:** `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

---

## Context Summary

**User Story:** As a course administrator, I want safe publication so that invalid geometry never reaches golfers.

**Acceptance Criteria:**
- AC-1: Pre-publish validation checks geometry, metadata, source, license, and data quality.
- AC-2: User reviews diff summary and provides publish note.
- AC-3: Publish creates immutable version, audit record, and package build job.

**Dependencies:**
- Story 8.2 (Edit Course Geometry) — output feeds into validation; 8.2 is `backlog` but validation logic is separable
- Story 4.1 (Define Course Package Contract) — `done`; `CoursePackageManifest`, `PackageBuildJob` entities already exist
- Audit infrastructure — `AuditService`, `AuditAction`, `AuditEntry` already exist
- Data versioning — `DataVersion`, `DataVersionStatus`, `DataVersionRepository` already exist

**Existing Foundation (reuse):**
- `DataVersion.java` — course data versioning entity
- `PackageService.java` / `PackageServiceImpl.java` — package manifest and build orchestration
- `PackageBuildJob.java` / `PackageBuildStatus.java` — async build job tracking
- `AuditService.java` — audit logging with `COURSE_VERSION_PUBLISHED` action
- `packages/contracts/openapi.yaml` — existing OpenAPI contracts

---

## Slice Plan

### Slice 1: PUBLISH-CONTRACT — Schema & OpenAPI Contracts

**Goal:** Define validation result types, version diff model, and publish request/response contracts.

**Files:**
1. `packages/contracts/schemas/course.yaml` — extend with:
   - `ValidationResult` — enum: `VALID`, `GEOMETRY_INVALID`, `METADATA_MISSING`, `LICENSE_MISSING`, `QUALITY_INSUFFICIENT`, `SOURCE_MISSING`, `VALIDATION_ERROR`
   - `ValidationResponse` — `{versionId, result, errors[], warnings[]}`
   - `VersionDiff` — `{added[], removed[], changed[{entity, field, oldValue, newValue}]}`
   - `PublishRequest` — `{publishNote, forcePublish}`
   - `PublishResponse` — `{newVersionId, status, auditId, buildJobId, publishedAt}`

2. `packages/contracts/openapi.yaml` — add admin paths:
   - `POST /admin/courses/{courseId}/versions/{versionId}/validate` → `ValidationResponse`
   - `GET /admin/courses/{courseId}/versions/{versionId}/diff` → `VersionDiff`
   - `POST /admin/courses/{courseId}/versions/{versionId}/publish` → `PublishResponse`
   - Error codes: `VERSION_NOT_FOUND`, `VALIDATION_FAILED`, `PUBLISH_FORBIDDEN`, `BUILD_JOB_QUEUED`

**Outcome:** Stable contract for portal UI and backend to implement against.

---

### Slice 2: PUBLISH-BACKEND — Validation, Diff, Publish Services

**Goal:** Implement pre-publish validation, diff generation, immutable version creation, audit logging, and package build job dispatch.

**Files:**
1. `apps/api/src/main/java/vnpt/vsp/module/course/ValidationService.java` (interface + impl)
   - `validateForPublish(versionId)` → `ValidationResult`
   - Checks: geometry `ST_IsValid` (PostGIS), required metadata fields present, source/license non-null, data quality class ≥ D
   - Returns field-level errors with entity and field context

2. `apps/api/src/main/java/vnpt/vsp/module/course/VersionDiffService.java` (interface + impl)
   - `generateDiff(draftVersionId, publishedVersionId)` → `VersionDiff`
   - Compares entities by type (tees, fairways, greens, bunkers, water, OB, landmarks, pins, conditions)
   - Field-level change tracking: geometry, metadata, effective dates

3. `apps/api/src/main/java/vnpt/vsp/module/course/PublishService.java` (interface + impl)
   - `publishVersion(versionId, publishNote)` → `PublishResponse`
   - Orchestrates: validate → diff (for response) → create immutable DataVersion snapshot → audit log → queue PackageBuildJob
   - `DataVersionStatus` transition: `DRAFT` → `PUBLISHED`

4. `apps/api/src/main/java/vnpt/vsp/module/course/entity/DataVersion.java` — extend if needed:
   - Add `publishNote`, `publishedBy`, `publishedAt`, `immutable` flag

5. `apps/api/src/main/java/vnpt/vsp/module/course/repository/DataVersionRepository.java` — extend:
   - `findLatestPublished(courseId)` for diff baseline
   - `findByCourseAndStatus(courseId, status)` for version lookup

6. `apps/api/src/main/java/vnpt/vsp/module/course/CourseVersionController.java` — add endpoints:
   - `POST /admin/courses/{courseId}/versions/{versionId}/validate`
   - `GET /admin/courses/{courseId}/versions/{versionId}/diff`
   - `POST /admin/courses/{courseId}/versions/{versionId}/publish`
   - RBAC: `COURSE_ADMIN` or `SUPER_ADMIN` required

7. `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` — add:
   - `COURSE_VERSION_VALIDATED`
   - `COURSE_VERSION_PUBLISHED`

**Outcome:** End-to-end backend behavior for AC-1, AC-2 (diff), AC-3 (immutable version + audit + build job).

---

### Slice 3: PUBLISH-PORTAL — Course Operations Portal UI

**Goal:** Portal UI for course administrator to validate, review diff, and publish.

**Files (portal — stack TBD; Angular assumed):**
1. `apps/portal/src/app/course-version/course-version-publish/` — new feature module
   - `course-version-publish.component.*` — main component
   - `validation-result.component.*` — displays validation errors/warnings
   - `version-diff.component.*` — shows added/removed/changed entities
   - `publish-note.component.*` — publish note textarea with required validation

2. `apps/portal/src/app/course-version/course-version-publish/course-version-publish.service.ts` — orchestrates validate → getDiff → publish flow

3. Portal route: `/courses/:courseId/versions/:versionId/publish`
   - Accessible from: course version management screen, Versions & Audit screen

**UI Behavior:**
- "Publish" button → triggers validation first
- Validation errors → inline list with entity/field context; publish blocked
- Validation warnings → non-blocking but visible
- Diff summary → expandable section with entity counts and field-level changes
- Publish note → required textarea (min 10 chars)
- Confirmation dialog before final publish
- Success → redirect to version detail with audit entry shown
- Error → retry option

**UX Compliance:**
- Loading states for validate/publish async operations
- Error states with actionable retry
- Accessibility: keyboard nav, focus management, screen reader labels
- Semantic tokens from design system

**Outcome:** Complete portal UX for AC-1 (validation display), AC-2 (diff review + publish note).

---

### Slice 4: PUBLISH-INTEGRATION — Package Build Job Hook

**Goal:** Connect published version to async package build pipeline.

**Files:**
1. `apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java` — add:
   - `queueBuildForCourse(courseId, versionId)` → `PackageBuildJob`
   - Idempotent: if build already queued for same course+version, return existing job

2. `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildJob.java` — ensure:
   - Links to `courseId`, `versionId`, `manifestId`
   - Status: `QUEUED`, `BUILDING`, `UPLOADING`, `PUBLISHED`, `FAILED`

3. `apps/api/src/main/java/vnpt/vsp/module/package/PackageBuildController.java` — add/verify:
   - `GET /admin/courses/{courseId}/packages/build-jobs/{jobId}` — job status

**Outcome:** Async package build triggered on publish; job ID returned in `PublishResponse`; portal can poll/display build status.

---

## Wave Mapping

| Wave | Slices | Focus | Dependencies |
|------|--------|-------|--------------|
| Wave 1 | PUBLISH-CONTRACT + PUBLISH-BACKEND | Schema + core backend logic | Story 4.1 foundation |
| Wave 2 | PUBLISH-PORTAL | Portal UI for validate/publish flow | Wave 1 complete |
| Wave 3 | PUBLISH-INTEGRATION | Package build job hook | Wave 1 + Story 4.2 |

---

## AC Coverage

| AC | Covered By | Evidence |
|----|------------|----------|
| AC-1: Pre-publish validation (geometry, metadata, source, license, data quality) | `ValidationService` + `ValidationResponse` contract | `ST_IsValid` check, field presence check, quality class check |
| AC-2: User reviews diff summary and provides publish note | `VersionDiffService` + portal `publish-note.component` + `PublishRequest.publishNote` | Diff response schema, portal publish form |
| AC-3: Publish creates immutable version, audit record, and package build job | `PublishService` → `DataVersion.immutable=true` + `AuditService` + `PackageGenerationService.queueBuildForCourse` | Audit action `COURSE_VERSION_PUBLISHED`, build job creation |

---

## Verification Gates

1. **Contract test:** OpenAPI schema valid; request/response shapes match code models
2. **Unit tests:** `ValidationService` — valid/invalid geometry, missing metadata, quality thresholds
3. **Unit tests:** `VersionDiffService` — added/removed/changed detection
4. **Integration test:** `PublishService` — full flow: validate → create immutable version → audit entry → job queued
5. **RBAC test:** Non-admin cannot call publish endpoint → 403
6. **Negative path:** Publish fails if validation fails → appropriate error response
7. **Idempotency:** Re-publish same version does not create duplicate immutable versions
8. **Portal UI:** Screen reader labels, keyboard nav, publish note required validation

---

## File List (Summary)

```
packages/contracts/schemas/course.yaml          # Add ValidationResult, VersionDiff, PublishRequest/Response
packages/contracts/openapi.yaml                 # Add /admin/courses/{courseId}/versions/{versionId}/validate|diff|publish
apps/api/src/main/java/vnpt/vsp/module/course/ValidationService.java
apps/api/src/main/java/vnpt/vsp/module/course/VersionDiffService.java
apps/api/src/main/java/vnpt/vsp/module/course/PublishService.java
apps/api/src/main/java/vnpt/vsp/module/course/CourseVersionController.java
apps/api/src/main/java/vnpt/vsp/module/course/entity/DataVersion.java
apps/api/src/main/java/vnpt/vsp/module/course/repository/DataVersionRepository.java
apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java
apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java
apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildJob.java
apps/portal/src/app/course-version/course-version-publish/*  (portal feature)
```

---

## Execution Order

1. **PUBLISH-CONTRACT** — establish contracts first (no backend deps)
2. **PUBLISH-BACKEND** — implement services + controller (depends on contracts)
3. **PUBLISH-PORTAL** — UI (depends on contracts + backend)
4. **PUBLISH-INTEGRATION** — build job hook (depends on backend + package module)

---

**Planner:** vnpt-epic-story-runner  
**Planned:** 2026-08-02  
**Story Status After Planning:** in-progress
