# Slice Matrix — Story 4.2: Generate and Publish Course Packages

**Story:** `4-2-generate-and-publish-course-packages`
**Epic:** Epic-04 (Offline Course Packages)
**Status:** `review`
**Implementation Date:** 2026-08-02

---

## Slice Execution

| Slice ID | Name | Files Changed | Dedup Status | Attempt |
|----------|-------|---------------|---------------|---------|
| PKG-PUBLISH-1 | Package Build Job Infrastructure | 5 files | `clean` | 1 |
| PKG-PUBLISH-2 | Package Generation and Storage | 3 files | `clean` | 1 |
| PKG-PUBLISH-3 | API Contracts for Package Build Status | 4 files | `clean` | 2 |
| PKG-PUBLISH-4 | Portal Build Status UI | 4 files | `clean` | 2 |

---

## duplicate_detection_outcome

### PKG-PUBLISH-1
- **gate chain:** Cy → Emb(no) → pre_write_check
- **candidate symbols:** `PackageBuildJob`, `PackageBuildStatus`, `PackageBuildJobRepository`
- **pre-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 1)
- **post-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 1)
- **LLM verdict:** All new symbols unique — no collisions with existing codebase symbols.

### PKG-PUBLISH-2
- **gate chain:** Cy → Emb(no) → pre_write_check
- **candidate symbols:** `PackageGenerationService`, `ObjectStorageService`, `PackageModuleConfig`
- **pre-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 1)
- **post-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 2)
- **LLM verdict:** All new symbols unique — no collisions.

### PKG-PUBLISH-3
- **gate chain:** Cy → Emb(no) → pre_write_check
- **candidate symbols:** `PackageBuildJobDto`, `PackageBuildController`
- **pre-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 1)
- **post-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 2)
- **LLM verdict:** All new symbols unique — no collisions with existing OpenAPI schemas or controller classes.

### PKG-PUBLISH-4
- **gate chain:** Cy → Emb(no) → pre_write_check
- **candidate symbols:** `BuildStatusPanel`, `PackageHistoryPage`
- **pre-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 1)
- **post-write:** `clean` (decision: PRE_WRITE, _block: false, attempt 2)
- **LLM verdict:** All new symbols unique — portal is a new scaffold with no prior components.

### Reindex
- **Command:** `python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py reindex`
- **Result:** `ok: false` — pre-existing FTS index corruption in gitnexus (node offset 987 inconsistency). Not a code issue.
- **Mitigation:** Precheck for `PackageBuildJob` returned `new_duplicate_likely: false`. Dedup report `docs/vnpt-flow/epic-run-epic-04/4-2/dedup_report.json` exists with `status: clean`.

---

## File List

### PKG-PUBLISH-1 (Backend)
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildJob.java` — **NEW**
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildStatus.java` — **NEW**
- `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageBuildJobRepository.java` — **NEW**
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageService.java` — **MODIFIED** (added 3 interface methods)
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageServiceImpl.java` — **MODIFIED** (implemented 3 new methods)

### PKG-PUBLISH-2 (Backend)
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java` — **NEW**
- `apps/api/src/main/java/vnpt/vsp/module/package/storage/ObjectStorageService.java` — **NEW**
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageModuleConfig.java` — **NEW**

### PKG-PUBLISH-3 (Contracts + Backend)
- `packages/contracts/openapi.yaml` — **MODIFIED** (added 3 new paths: POST /courses/{courseId}/packages/build, GET /courses/{courseId}/packages/build/jobs, GET /courses/{courseId}/packages/build/jobs/{jobId})
- `packages/contracts/schemas/course.yaml` — **MODIFIED** (added PackageBuildJobDto, TriggerBuildRequest, TriggerBuildResponse, PackageBuildJobListResponse)
- `packages/contracts/schemas/common.yaml` — **MODIFIED** (added BUILD_ALREADY_IN_PROGRESS, BUILD_NOT_FOUND, COURSE_NOT_PUBLISHED error codes)
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageBuildController.java` — **NEW**

### PKG-PUBLISH-4 (Portal)
- `apps/portal/src/types/package-build.ts` — **NEW**
- `apps/portal/src/api/package-build.ts` — **NEW**
- `apps/portal/src/components/package/BuildStatusPanel.vue` — **NEW**
- `apps/portal/src/pages/courses/[courseId]/packages/index.vue` — **NEW**

---

## Verification Summary

| AC | Requirement | Implementation |
|----|-------------|----------------|
| AC-1 | Publishing queues validation, build, upload, CDN | `triggerPackageBuild()` creates `PackageBuildJob(QUEUED)` → scheduled worker → `PackageGenerationService.processBuildJob()` → VALIDATING → BUILDING → ASSEMBLING → UPLOADING → PUBLISHING → COMPLETED |
| AC-2 | Build status and actionable failures visible in portal | `PackageBuildJob.status/errorCode/errorMessage/errorDetail` surfaced via GET endpoints → `BuildStatusPanel.vue` with badge + progress + error detail + retry button |
| AC-3 | Published package URLs immutable and versioned | CDN URL pattern `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/...` with version in path, no query-param versioning |

**No changes** to: `apps/mobile/`, `packages/course-package/`, `packages/mobile-theme/`, `packages/design-tokens/`, `packages/map-style/`.
