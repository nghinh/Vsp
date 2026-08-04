# Slice Plan: 8.4 — Roll Back Published Data

## Story Reference
- **Story:** 8.4 — Roll Back Published Data
- **Epic:** 8 — Course Operations Portal
- **Status:** `in-progress`
- **Epic Run Folder:** `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

---

## 1. Context Summary

### PRD Requirements (PRD §8.11, §9.1)
- Course data is **append-versioned**: DRAFT → PUBLISHED → ARCHIVED
- Rollback creates a **new published version** referencing the prior version (never deletes history)
- Admin can roll back published course data
- Audit log for every publish/rollback action

### Architecture Requirements (Architecture §7.3)
- Published version for mobile packages
- Rollback creates new published version referencing prior data
- Audit trail on all course data mutations

### UX Requirements (UX §7.2, §7.5, §13)
- Portal "Versions & Audit" nav section shows version history
- Audit entries show: actor, role, action, object changed, before/after, timestamp, version, reason
- Portal admin can view rollback action in audit history

### Existing Code Evidence
| Asset | Path | Notes |
|---|---|---|
| `DataVersion` entity | `module/course/entity/DataVersion.java` | status=DRAFT/PUBLISHED/ARCHIVED, versionNumber, publishedAt, publishedBy, publishNote |
| `DataVersionStatus` enum | `module/course/entity/DataVersionStatus.java` | DRAFT, PUBLISHED, ARCHIVED |
| `DataVersionRepository` | `module/course/repository/DataVersionRepository.java` | `findByCourseIdOrderByVersionNumberDesc`, `findLatestPublishedByCourseId`, `findByCourseIdAndStatus` |
| `AuditAction.COURSE_ROLLBACK` | `module/audit/AuditAction.java` | Already defined |
| `CourseServiceImpl.recordCourseRollback()` | `CourseServiceImpl.java:269` | Stub — audit logging only, no actual rollback logic |
| `CourseService.recordCourseRollback()` | `CourseService.java:135` | Interface stub |
| `PackageBuildJob` | `module/pkg/entity/PackageBuildJob.java` | UUID, courseId, dataVersionId, status, triggeredBy |
| `PackageService.triggerPackageBuild()` | `module/pkg/PackageService.java` | Triggers async package build job |
| `PackageBuildController` | `module/pkg/PackageBuildController.java` | `POST /courses/{courseId}/packages/build` |
| Portal packages page | `portal/src/pages/courses/[courseId]/packages/index.vue` | Package build history UI |
| `CoursePackageManifest` | `module/pkg/entity/CoursePackageManifest.java` | Package metadata including version |

### Out of Scope (per story constraints)
- Story 8.3 publish logic (this story handles rollback only)
- Geometry editing (Story 8.2)
- Pin/green/condition scheduling (Story 8.5)
- Alert management (Story 8.6)
- Flutter mobile changes
- New AI/smartwatch/analytics scope

---

## 2. Slice Definition

### AC-1: Authorized user can select a prior version and view impact

**What "view impact" means:**
- Show which version they would roll back to
- Show which version is currently published (the one being replaced)
- Show metadata of both versions (version number, publishedAt, publishedBy, publishNote)
- No deletion of geometry or other entities — just status transitions

**API behavior:**
- `GET /courses/{courseId}/versions` — list all versions (id, versionNumber, status, publishedAt, publishedBy, publishNote)
- `GET /courses/{courseId}/versions/{versionId}` — get version detail + impact summary
- `GET /courses/{courseId}/versions/rollback-impact?targetVersionId={id}` — what would change if rolled back

**Implementation:** `CourseVersionController` + `CourseVersionService`

### AC-2: Rollback creates a new version rather than deleting history

**Key design decision (Architecture §7.3 + PRD §8.11):**
- Current PUBLISHED version → ARCHIVED (not deleted)
- Selected prior ARCHIVED version → re-PUBLISHED (new publishedAt, new publishedBy)
- No new entity created; existing archived version is re-activated
- OR: create a new version record copying data from target, marking it PUBLISHED (more explicit)

**Decision: re-activate existing archived version**
- Simpler, preserves exact prior state, matches "append-versioned" intent
- New `publishedAt` and `publishedBy` set to rollback time/actor
- Old published version → ARCHIVED

**API behavior:**
- `POST /courses/{courseId}/versions/{versionId}/rollback` — body: `{ "rollbackNote": "string" }`
- Idempotent: if target version is already PUBLISHED, return 400
- Audit: `COURSE_ROLLBACK` action with before/after JSON

### AC-3: New package generation and audit record are triggered

**Package build trigger:**
- After successful rollback, call `packageService.triggerPackageBuild(courseId, reActivatedVersion.getId(), actor)`
- Triggers async build job (existing infrastructure from Story 4.2)

**Audit record:**
- `auditService.log(AuditAction.COURSE_ROLLBACK, "DataVersion", versionId, beforeJson, afterJson, metadataJson)`
- beforeJson: `{"status": "PUBLISHED", "versionNumber": N, "publishedAt": "...", "publishedBy": "..."}`
- afterJson: `{"status": "PUBLISHED", "versionNumber": M, "publishedAt": "...", "publishedBy": "...", "rollbackNote": "..."}`

---

## 3. Slices / Wave Plan

### Wave A — Backend: Domain & Service Layer (smallest first)

1. **Add rollback domain methods to `DataVersion`**
   - `void rollbackTo(String actor, String rollbackNote)` — re-activate archived version
   - Adds rollback metadata fields to entity if needed (rollbackNote, rolledBackFromVersionId)

2. **Add `DataVersion` rollbackNote field** (optional — can store in metadata_json via audit)
   - Decision: add `rollbackNote` field to DataVersion — clean domain record

3. **Add `rollbackTo()` to `CourseService`**
   - `DataVersion rollbackToVersion(Long courseId, Long targetVersionId, String actor, String rollbackNote)`
   - Validates: target exists, is ARCHIVED, belongs to course
   - Validates: course has a current PUBLISHED version (must archive it first)
   - Archives current published version
   - Re-activates target version (status→PUBLISHED, publishedAt→now, publishedBy→actor, rollbackNote→note)
   - Calls `packageService.triggerPackageBuild()`
   - Calls `auditService.log(AuditAction.COURSE_ROLLBACK, ...)`

### Wave B — Backend: API Layer

4. **Create `CourseVersionController`**
   - `GET /courses/{courseId}/versions` — list versions (paginated, newest first)
   - `GET /courses/{courseId}/versions/{versionId}` — version detail
   - `POST /courses/{courseId}/versions/{versionId}/rollback` — execute rollback
   - `GET /courses/{courseId}/versions/rollback-impact?targetVersionId={id}` — impact preview

5. **Create DTOs**
   - `CourseVersionDto` — id, versionNumber, status, publishedAt, publishedBy, publishNote, rollbackNote, createdAt
   - `VersionListResponse` — list + pagination
   - `RollbackImpactDto` — currentVersion, targetVersion, changes summary
   - `RollbackRequest` — rollbackNote
   - `RollbackResponse` — newJobId, versionId, status

6. **Add error codes to `VspErrorCode`** if missing:
   - `VERSION_001` — version not found
   - `VERSION_002` — version not in ARCHIVED status (cannot rollback)
   - `VERSION_003` — no currently published version to replace

### Wave C — Backend: Tests

7. **Add `CourseVersionServiceTest`** (unit)
   - Rollback happy path
   - Rollback to non-archived version → 400
   - Rollback with no current published version → 400
   - Rollback idempotency (rollback to already-published version → 400)
   - Trigger package build called after rollback

8. **Add `CourseVersionControllerTest** (integration-style)
   - List versions
   - Get version detail
   - Rollback success
   - Rollback unauthorized (no auth)
   - Rollback not-found version

### Wave D — Portal: UI Layer

9. **Create portal API client** `portal/src/api/course-version.ts`
   - `listVersions(courseId, token)` → `GET /courses/{courseId}/versions`
   - `getVersion(courseId, versionId, token)` → `GET /courses/{courseId}/versions/{versionId}`
   - `getRollbackImpact(courseId, targetVersionId, token)` → `GET /courses/{courseId}/versions/rollback-impact?targetVersionId={id}`
   - `executeRollback(courseId, versionId, rollbackNote, token)` → `POST /courses/{courseId}/versions/{versionId}/rollback`

10. **Create portal types** `portal/src/types/course-version.ts`
    - `CourseVersionDto`, `VersionListResponse`, `RollbackImpactDto`, `RollbackRequest`, `RollbackResponse`

11. **Create portal page** `portal/src/pages/courses/[courseId]/versions/index.vue`
    - Version history table: versionNumber, status badge, publishedAt, publishedBy, publishNote
    - "View Impact" button per version
    - "Roll Back" button (only shown for ARCHIVED versions with a current PUBLISHED version)
    - Rollback confirmation modal: shows impact summary, requires rollbackNote input
    - Loading, empty, error, retry states
    - Success toast/notification after rollback triggers

12. **Add portal nav link** to "Versions & Audit" section in portal navigation

---

## 4. Acceptance Criteria Mapping

| AC | Implementation | Verification |
|---|---|---|
| AC-1: Select prior version and view impact | `GET /courses/{courseId}/versions` + `GET .../rollback-impact` | Unit test + API contract test |
| AC-2: Rollback creates new version, not delete | `DataVersion.rollbackTo()` + `CourseService.rollbackToVersion()` | Unit test verifies entity state transitions |
| AC-3: Package build + audit triggered | `packageService.triggerPackageBuild()` + `auditService.log(COURSE_ROLLBACK)` | Unit test verifies both called |

---

## 5. File Changes

### New Backend Files
```
apps/api/src/main/java/vnpt/vsp/api/course/CourseVersionController.java
apps/api/src/main/java/vnpt/vsp/module/course/CourseVersionService.java        # interface
apps/api/src/main/java/vnpt/vsp/module/course/CourseVersionServiceImpl.java
apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseVersionDto.java
apps/api/src/main/java/vnpt/vsp/module/course/dto/RollbackImpactDto.java
apps/api/src/main/java/vnpt/vsp/module/course/dto/RollbackRequest.java
apps/api/src/main/java/vnpt/vsp/module/course/dto/RollbackResponse.java
apps/api/src/test/java/vnpt/vsp/module/course/CourseVersionServiceImplTest.java
apps/api/src/test/java/vnpt/vsp/api/course/CourseVersionControllerTest.java
```

### Modified Backend Files
```
apps/api/src/main/java/vnpt/vsp/module/course/entity/DataVersion.java           # +rollbackNote field +rollbackTo()
apps/api/src/main/java/vnpt/vsp/module/course/entity/DataVersionStatus.java     # no change needed
apps/api/src/main/java/vnpt/vsp/module/course/CourseService.java               # no change needed (stub exists)
apps/api/src/main/java/vnpt/vsp/module/course/CourseServiceImpl.java          # no change needed (stub exists)
apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java                   # + VERSION_001/002/003
```

### New Portal Files
```
apps/portal/src/api/course-version.ts
apps/portal/src/types/course-version.ts
apps/portal/src/pages/courses/[courseId]/versions/index.vue
```

---

## 6. Verification Gates

1. **Unit tests pass** — `CourseVersionServiceImplTest` covers rollback state machine
2. **API contract** — `CourseVersionController` endpoints respond with correct DTOs + HTTP status codes
3. **Audit trail** — `COURSE_ROLLBACK` entry written to audit log
4. **Package trigger** — `triggerPackageBuild()` called after rollback
5. **Portal accessibility** — version list + rollback flow accessible, loading/error states present
6. **No regression** — existing `DataVersionRepository` queries still work

---

## 7. Constraints & Dependencies

- **Dependency on Story 8.3:** Rollback depends on the versioning model established in 8.3 (DataVersion entity, PUBLISHED/ARCHIVED status). Story 8.3 is in `backlog` per sprint-status, so this slice assumes its output will be available. If 8.3 is not complete, rollback still works conceptually against the existing DataVersion entity.
- **Package module dependency:** `PackageService.triggerPackageBuild()` must be callable from course module without circular dependency. Architecture has explicit module boundaries — CourseServiceImpl already injects AuditService; PackageService injection follows same pattern.
- **RBAC:** All endpoints require COURSE_ADMIN or higher (reuse existing auth pattern from PackageBuildController)
- **No mobile changes** — rollback is a portal/admin-only operation
