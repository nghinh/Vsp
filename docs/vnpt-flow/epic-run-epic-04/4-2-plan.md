# Story 4.2 Plan — Generate and Publish Course Packages

**Run ID:** `run_2026_08_02_008_planning`
**Epic:** Epic-04 (Offline Course Packages)
**Wave:** 4-2 (wave 2 of 4 — depends on 4-1 completed)
**Story:** `4-2-generate-and-publish-course-packages`
**Status source:** `docs/implementation-artifacts/epic-04/4-2-generate-and-publish-course-packages.md`
**Plan file:** `docs/vnpt-flow/epic-run-epic-04/4-2-plan.md`
**Planning mode:** fresh — story status `ready-for-dev`, routing decision `planning`

---

## Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md",
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/epics.md"
  ],
  "project_context_sources_read": [
    "docs/project-context.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-state.json"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-04/4-2-generate-and-publish-course-packages.md",
    "docs/implementation-artifacts/epic-04/4-1-define-course-package-contract.md",
    "docs/vnpt-flow/epic-run-epic-04/4-1-plan.md"
  ],
  "mockup_sources_read": []
}
```

---

## Scope Analysis

### What Story 4-2 Must Deliver

Story 4-1 established the **offline course package contract**: manifest schema, `CoursePackageManifest` entity, `PackageFileEntry`/`PackageLicense` entities, manifest validation, and OpenAPI discovery paths.

Story 4-2 must now **generate and publish packages** — turning a published `DataVersion` into a downloadable, immutable, versioned offline course package delivered via CDN.

### AC-to-Artifact Mapping

| AC | Requirement | Story 4-1 Artifact | Gap for 4-2 |
|----|-------------|-------------------|-------------|
| AC-1 | Publishing queues validation, build, upload, CDN | `CoursePackageManifest` entity with `tilesUrl`/`geoJsonUrl` fields | **Missing**: job queue, generation worker, storage upload, CDN publication |
| AC-2 | Build status and actionable failures visible in portal | `ManifestValidationResult` enum (client-side validation only) | **Missing**: job status tracking entity, status API, portal UI |
| AC-3 | Published package URLs immutable and versioned | `tilesUrl`, `geoJsonUrl` fields in manifest (URL pattern not specified) | **Missing**: immutable/versioned URL pattern, CDN storage paths, URL contract |

### Epic-04 Internal Dependency Chain

```
Story 4.1 (contracts) ──────────────────────────────────────┐
                                                               ▼
Story 4.2 (generate/publish) ── uses manifest schema ──────┐  │
  • PackageBuildJob entity                                  │  │
  • PackageGenerationService (async)                         │  │
  • CDN publication with immutable URLs                     │  │
  • Portal build-status UI                                  │  │
                                                               ▼
Story 4.3 (download/manage) ─────── uses manifest ───────────┘
                                                               ▼
Story 4.4 (incremental update) ─── uses manifest ──────────────┘
```

### PRD Requirements Traced

| PRD Section | Requirement | Coverage in 4-2 |
|-------------|-------------|-----------------|
| §8.3 | Package includes metadata, hole geometry, vector maps, scorecards, local rules, pin positions, course conditions, weather snapshot | Package generation assembles all these file types into a package |
| §10.6 | CDN-backed course package delivery | CDN publication with immutable/versioned URLs |
| Architecture §9.2 | Package generation pipeline: validate → async worker generates tiles/PMTiles and manifest → object storage → CDN | Implemented in 4-2 |
| Architecture §9.2 | Package URLs immutable and versioned | CDN URL pattern `/packages/{courseId}/{version}/...` |

### Architecture Requirements from Architecture Doc

- **Async workers/queue** for package builds (§6, §9.2)
- **Object storage + CDN** for course package distribution (§6, §10.6)
- **Append-versioned** course data: draft → published → package (§7.3)
- **Modular monolith** — `pkg` module owns package generation (§6.1)
- **Audit** — package builds are auditable events (§10.11)

### Portal Integration Point

Epic 8 Story 8.3 ("Validate and Publish Course Version") owns the pre-publish validation and publish trigger. Story 4-2 must **hook into the publish workflow** — when a course admin publishes a data version, a `PackageBuildJob` is created and queued. The portal's publish UI gains a "package build status" panel showing job progress and errors.

### Gap: No Async/Job Infrastructure Exists

The entire async/job infrastructure is absent from the codebase:
- No `PackageBuildJob` entity
- No `@Async` worker pattern
- No job queue
- No storage service for CDN upload

Story 4-2 must introduce these foundations cleanly within the modular monolith, without over-engineering a full distributed job system.

---

## Slice Plan

### Slice 1 — Package Build Job Infrastructure (`PKG-PUBLISH-1`)

**Scope:** `PackageBuildJob` entity, repository, and job lifecycle. No generation yet.

**Changes:**

1. **New entity:** `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildJob.java`
   - Fields: `id (UUID)`, `courseId (Long)`, `dataVersionId (Long)`, `manifestVersion (String — semver)`, `status (enum: QUEUED, VALIDATING, BUILDING, ASSEMBLING, UPLOADING, PUBLISHING, COMPLETED, FAILED)`, `createdAt (Instant)`, `startedAt (Instant?)`, `completedAt (Instant?)`, `errorCode (String?)`, `errorMessage (String?)`, `errorDetail (String?)` (stack trace or actionable fix hint), `triggeredBy (String — operator username)`, `buildDurationMs (Long?)`
   - Indexes: `(courseId, createdAt)` for listing; `(status)` for worker polling
   - JPA validation: `@NotNull` on required fields

2. **New repository:** `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageBuildJobRepository.java`
   - `Optional<PackageBuildJob> findFirstByCourseIdAndStatusIn(courseId, List<Status> statuses)` — for idempotency (don't enqueue duplicate running jobs for same course)
   - `List<PackageBuildJob> findByCourseIdOrderByCreatedAtDesc(courseId)` — job history for portal
   - `Optional<PackageBuildJob> findFirstByStatusInOrderByCreatedAtAsc(List<Status> statuses)` — worker picks up oldest QUEUED job
   - `Optional<PackageBuildJob> findByIdAndCourseId(UUID id, Long courseId)` — portal polling by job ID

3. **New enum:** `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildStatus.java`
   - Values: `QUEUED`, `VALIDATING`, `BUILDING`, `ASSEMBLING`, `UPLOADING`, `PUBLISHING`, `COMPLETED`, `FAILED`

4. **`PackageService` interface additions** — add generation-triggering methods:
   - `UUID triggerPackageBuild(Long courseId, Long dataVersionId, String triggeredBy)` — creates `PackageBuildJob` with status QUEUED, returns job ID (idempotent — no-op if a job for same course is already QUEUED/BUILDING/etc.)
   - `PackageBuildJob getBuildJob(UUID jobId)` — portal/status polling
   - `List<PackageBuildJob> getBuildHistory(Long courseId)` — portal job history

5. **Idempotency**: `triggerPackageBuild` checks for existing non-terminal job; if one exists, returns that job ID without creating a duplicate.

**AC served:** AC-1 (queues job), AC-2 (job entity carries status and error fields for portal visibility)

**Verification:**
- Unit test: `triggerPackageBuild` returns existing job ID when a non-terminal job for the same course already exists (idempotency)
- Unit test: `triggerPackageBuild` creates new job when no active job exists
- Unit test: status enum covers all pipeline stages

---

### Slice 2 — Package Generation and Storage (`PKG-PUBLISH-2`)

**Scope:** `PackageGenerationService` — tile/GeoJSON generation, file assembly, object storage upload, CDN publication. Async execution via `@Async`.

**Changes:**

1. **New service:** `apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java`
   - `void processBuildJob(UUID jobId)` — main async entry point; called by `@Async` worker
   - Internal methods:
     - `validateInputs(job)` — validates course exists, data version is published, geometry is complete
     - `generateTiles(job)` — generates PMTiles from PostGIS hole geometry (ST_AsMVT or external tool invocation)
     - `assemblePackageFiles(job)` — assembles manifest JSON, GeoJSON geometry subset, scorecard JSON, rules JSON, conditions JSON, metadata JSON
     - `uploadToStorage(job)` — uploads each file to object storage at path `packages/{courseId}/{manifestVersion}/{contentType}/{filename}`
     - `publishToCDN(job)` — triggers CDN cache warming/publish for the package prefix
   - Updates `PackageBuildJob.status` after each stage

2. **New service:** `apps/api/src/main/java/vnpt/vsp/module/package/storage/ObjectStorageService.java`
   - Interface for object storage operations
   - `String uploadFile(byte[] data, String path, String contentType)` — returns CDN-accessible URL
   - `void deletePackage(Long courseId, String manifestVersion)` — cleanup on failure
   - Path pattern: `packages/{courseId}/{manifestVersion}/{contentType}/{filename}`
   - Content-type mapping: `METADATA→application/json`, `GEOMETRY→application/geo+json`, `TILES→application/x-protobuf`, `SCORECARD→application/json`, `RULES→application/json`, `CONDITIONS→application/json`, `WEATHER→application/json`, `SATELLITE→image/*`

3. **Package URL pattern** (immutable and versioned):
   - CDN base: `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/`
   - Manifest URL: `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/manifest.json`
   - Tiles URL: `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/tiles.pmtiles`
   - GeoJSON URL: `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/geometry.geojson`
   - **Immutable**: version in URL never changes after publish; old versions remain accessible
   - **Versioned**: each publish creates a new `manifestVersion` (semver based on data version + build counter)

4. **Package manifest version strategy**:
   - Format: `{dataVersionMajor}.{dataVersionMinor}.{buildNumber}` (e.g., `1.3.0`, `1.3.1`)
   - `buildNumber` increments when multiple packages are built for the same data version
   - Ensures every published package has a unique, immutable URL

5. **`PackageServiceImpl` additions** — implement new interface methods from Slice 1

6. **Async execution**:
   - In `PackageModule` or a shared `AsyncConfig`, define a `ThreadPoolTaskExecutor` bean named `packageBuildExecutor` with core=2, max=4, queue=100
   - `PackageGenerationService.processBuildJob()` annotated with `@Async("packageBuildExecutor")`
   - Alternatively: `@EventListener(ApplicationReadyEvent.class)` + `@Scheduled(fixedDelay=30_000)` polling `findFirstByStatusInOrderByCreatedAtAsc` for QUEUED jobs — avoids Spring Events dependency; simpler for MVP

7. **Job failure handling**:
   - On any exception in `processBuildJob`, set status to FAILED, set `errorCode` (from predefined set), `errorMessage` (human-readable), `errorDetail` (actionable fix hint)
   - Error codes: `VALIDATION_ERROR`, `GEOMETRY_INCOMPLETE`, `TILE_GENERATION_FAILED`, `ASSEMBLY_FAILED`, `STORAGE_UPLOAD_FAILED`, `CDN_PUBLISH_FAILED`
   - Never leave job in indeterminate state

**AC served:** AC-1 (full pipeline: validate → build → upload → CDN), AC-3 (immutable versioned CDN URLs)

**Verification:**
- Unit test: `generateTiles` is called after `validateInputs` succeeds
- Unit test: exception during `uploadToStorage` causes FAILED status with `STORAGE_UPLOAD_FAILED` error code
- Unit test: CDN URL follows immutable/versioned pattern
- Integration test: full pipeline run (mocked storage) produces valid manifest with correct URLs

---

### Slice 3 — API Contracts for Package Build Status (`PKG-PUBLISH-3`)

**Scope:** OpenAPI paths for build status and job management. Hooks the build into the existing course publish workflow.

**Changes:**

1. **`packages/contracts/openapi.yaml`** — Add paths:
   - `POST /courses/{courseId}/packages/build` — trigger a package build (body: `{ dataVersionId, triggeredBy }`); returns `{ jobId }`
   - `GET /courses/{courseId}/packages/build/jobs` — list build jobs for a course (paginated), returns `PackageBuildJobListResponse`
   - `GET /courses/{courseId}/packages/build/jobs/{jobId}` — get specific job status, returns `PackageBuildJobResponse`

2. **`packages/contracts/schemas/course.yaml`** — Add schemas:
   - `PackageBuildJobDto`: id, courseId, dataVersionId, manifestVersion, status, createdAt, startedAt, completedAt, errorCode, errorMessage, errorDetail, triggeredBy, buildDurationMs
   - `PackageBuildJobListResponse`: jobs[], total, page, pageSize
   - `TriggerBuildRequest`: dataVersionId, triggeredBy

3. **Error codes** (extend `packages/contracts/schemas/common.yaml`):
   - `BUILD_ALREADY_IN_PROGRESS` — idempotency rejection (non-terminal job exists)
   - `BUILD_NOT_FOUND` — job ID not found
   - `COURSE_NOT_PUBLISHED` — cannot build package for unpublished course

4. **Backend controller** — `apps/api/src/main/java/vnpt/vsp/module/package/PackageBuildController.java`:
   - `POST /courses/{courseId}/packages/build` — calls `PackageService.triggerPackageBuild()`
   - `GET /courses/{courseId}/packages/build/jobs` — calls `PackageService.getBuildHistory()`
   - `GET /courses/{courseId}/packages/build/jobs/{jobId}` — calls `PackageService.getBuildJob()`
   - All endpoints: authenticated, course-scoped, RBAC (`COURSE_ADMIN` or higher)

5. **Epic 8 integration** — `POST /admin/courses/{courseId}/versions/{versionId}/publish` (from Epic 8.3) should call `PackageService.triggerPackageBuild()` as the last step after successful publish, so package build is queued automatically when a course operator publishes.

**AC served:** AC-1 (API to trigger build), AC-2 (API for portal to poll build status)

**Verification:**
- OpenAPI validation passes
- Controller methods delegate to service (no business logic in controller)
- RBAC enforced on all endpoints

---

### Slice 4 — Portal Build Status UI (`PKG-PUBLISH-4`)

**Scope:** Portal UI components showing build status, errors, and retry action for course operators.

**Changes:**

1. **New portal component:** `apps/portal/src/components/package/BuildStatusPanel.vue`
   - Props: `courseId`, `currentJobId` (optional)
   - Shows: job status badge (QUEUED/BUILDING/PUBLISHING/COMPLETED/FAILED), stage label, progress bar (for in-progress stages), created time, duration (for completed/failed), triggered by
   - Error state: red badge, error code, human-readable error message, **actionable fix hint** (e.g., "Geometry incomplete — complete all hole geometry before publishing")
   - Completed state: green badge, manifest version, link to manifest JSON on CDN
   - Retry button: visible only in FAILED state; calls `POST /courses/{courseId}/packages/build` to re-queue

2. **Integration point** — Add `BuildStatusPanel` to the course version detail page (from Epic 8.3 publish flow):
   - After successful publish, show the panel with current job status
   - Portal polls `GET /courses/{courseId}/packages/build/jobs` every 10 seconds while a job is in non-terminal state

3. **Job history page:** `apps/portal/src/pages/courses/[courseId]/packages/index.vue`
   - Lists all build jobs for a course (newest first)
   - Each row: status badge, manifest version, triggered by, created at, duration, error (if failed)
   - Click row → job detail with full error information

4. **Accessibility and UX**:
   - Status badges use icon + text + color (not color alone)
   - Error messages are human-readable Vietnamese/English
   - Touch targets ≥44pt
   - Loading skeleton while fetching job status
   - Empty state: "No package builds yet. Publish a course version to start."

**AC served:** AC-2 (build status and actionable failures visible in portal)

**Verification:**
- UI renders correct status badge for each `PackageBuildStatus` value
- Error detail is displayed for FAILED jobs
- Retry button re-queues a failed build
- Polling updates status without page reload

---

## Quality Gate

**Gate type:** detect-duplicate flow (Serena exact-name match → CC → SigCheck + Emb → Q → AIJudge + PreWrite → Report → Reindex)

**Chain steps:**
1. **Serena (Cy):** Query for `PackageBuildJob`, `PackageBuildStatus`, `PackageGenerationService`, `ObjectStorageService`, `PackageBuildJobRepository`, `PackageBuildController`, `PackageBuildJobDto`, `TriggerBuildRequest`, `PackageBuildJobListResponse` across all source files. Any exact-name collision with differing signature → reject.
2. **Serena (CC):** Verify `PackageService.triggerPackageBuild()` interface additions don't break callers. Verify `PackageGenerationService` is injected only where needed.
3. **SigCheck:** Verify `PackageBuildStatus` enum covers all pipeline stages; verify CDN URL pattern is immutable (version in path, no query params for versioning).
4. **Emb (embeddings):** Query with "package build job status portal async". Check top-3 semantic matches for intent-equivalent existing symbols (e.g., `PackageManifestRepository` vs new `PackageBuildJobRepository`) that should be reused instead of created.
5. **PreWrite (precheck):** Run pre-write duplicate detection via Serena pattern search for new top-level symbols before code is written.
6. **Report:** Verify `docs/vnpt-flow/epic-run-epic-04/4-2/dedup_report.json` exists, status is `clean` or `resolved`, `_block: false`, attempts between 1–3, includes pre-phase and post-phase attempts.
7. **Reindex:** If dedup tool exists, verify `reindex` returned `ok: true` and was run exactly once after the final write.

**Gate verdict:** Return `QA_PASS` or `QA_FAIL: <step>` per runner rules.

---

## Anti-Shortcut Evidence

- Did NOT treat package generation as synchronous within the publish request — AC-1 explicitly says "queues" which means async
- Did NOT skip job failure states — AC-2 requires "actionable failures" visible in portal, which means `errorCode` + `errorMessage` + `errorDetail` fields on `PackageBuildJob`
- Did NOT use a polling HTTP endpoint for the async worker — `@Async` with `ThreadPoolTaskExecutor` is the standard Spring approach without introducing a separate queue infrastructure
- Did NOT make CDN URLs mutable — URL pattern uses version in path; no query-param versioning
- Did NOT skip Epic 8 integration — the publish endpoint from Epic 8.3 must call `triggerPackageBuild()` as the last step
- Did NOT create a separate "job service" module — `PackageBuildJob` lives in the `pkg` module alongside `CoursePackageManifest`
- Did NOT plan tile/GeoJSON generation algorithm details — this is internal to `PackageGenerationService` and should use PostGIS `ST_AsMVT` or invoke a PMTiles generation tool
- Did NOT plan mobile changes in Story 4-2 — mobile uses the manifest URLs from Story 4-1 API contracts (CDN URLs are consumed in Story 4-3/4-4)
- Idempotency in `triggerPackageBuild` is explicit — prevents duplicate builds for the same course

---

## File Changes Summary

| Slice | Layer | Files Changed |
|-------|-------|--------------|
| PKG-PUBLISH-1 | Backend | `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildJob.java`, `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageBuildStatus.java`, `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageBuildJobRepository.java`, `apps/api/src/main/java/vnpt/vsp/module/package/PackageService.java` (interface additions), `apps/api/src/main/java/vnpt/vsp/module/package/PackageServiceImpl.java` (new method implementations) |
| PKG-PUBLISH-2 | Backend | `apps/api/src/main/java/vnpt/vsp/module/package/PackageGenerationService.java`, `apps/api/src/main/java/vnpt/vsp/module/package/storage/ObjectStorageService.java`, `apps/api/src/main/java/vnpt/vsp/module/package/PackageModule.java` (async config) |
| PKG-PUBLISH-3 | Contracts + Backend | `packages/contracts/openapi.yaml` (new paths), `packages/contracts/schemas/course.yaml` (new DTOs), `packages/contracts/schemas/common.yaml` (new error codes), `apps/api/src/main/java/vnpt/vsp/module/package/PackageBuildController.java` |
| PKG-PUBLISH-4 | Portal | `apps/portal/src/components/package/BuildStatusPanel.vue`, `apps/portal/src/pages/courses/[courseId]/packages/index.vue` |

**No changes** to: `apps/mobile/`, `packages/course-package/`, `packages/mobile-theme/`, `packages/design-tokens/`, `packages/map-style/`.

---

## Story Status After Planning

- Story source status: **`in-progress`** (update from `ready-for-dev`)
- Epic-04 wave: 4-2 → `in-progress`; waves 4-3/4-4 remain `ready-for-dev`
- Plan output: `docs/vnpt-flow/epic-run-epic-04/4-2-plan.md`
- Runner output: `READY_FOR_IMPLEMENTER_DISPATCH` for wave 4-2
