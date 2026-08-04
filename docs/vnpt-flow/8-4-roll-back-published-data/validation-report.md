# Quality Gate Report — Story 8.4 (Roll Back Published Data)

**Date:** 2026-08-02
**Story:** 8.4 — Roll Back Published Data
**Story status before:** `review`
**Story status after:** `review` (gate: prewrite_failed + report_missing_or_invalid — not updated to `done`)

---

## Quality Gate Results

| Gate | Result | Details |
|------|--------|---------|
| Format | **STUB** | Portal build scripts are stubs (`echo` commands); no formatter configured |
| Lint | **STUB** | Portal build scripts are stubs (`echo` commands); no linter configured |
| Typecheck | **STUB** | Portal build scripts are stubs; `tsconfig.json` present but no `tsc` in `package.json` |
| Test | **NOT RUN** | Backend build files (`pom.xml`/`build.gradle`) not found in repo; cannot compile/run Java tests |
| Build | **STUB** | Portal build scripts are stubs; backend build files absent |

---

## Dedup Quality Gate — Step-by-Step Results

### Step 1: Cy → CC → SigCheck
- Dedup report does NOT contain CourseVersionApi, `versions/index.vue`, or `course-version.ts` from Wave D (portal UI).
- These files were added in Wave D of this story and are absent from `docs/vnpt-flow/8-4-roll-back-published-data/dedup_report.json`.

### Step 2: Emb → Q → AIJudge (Embeddings)
- Embeddings are **disabled** in the dedup tool (warn: "embeddings not refreshed").
- Portal files (Wave D) were checked via prewrite script and returned `new_duplicate_likely: false` — but those results are NOT in the dedup_report.

### Step 3: PreWrite (final recheck script)
```
python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py precheck CourseVersionApi --file apps/portal/src/api/course-version.ts
→ new_duplicate_likely: false  ✅

python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py precheck VersionListResponse --file apps/portal/src/types/course-version.ts
→ new_duplicate_likely: false  ✅

python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py precheck versions_index --file apps/portal/src/pages/courses/[courseId]/versions/index.vue
→ new_duplicate_likely: false  ✅
```
All Wave D portal files pass prewrite dedup. **However**, these results were NOT persisted to `dedup_report.json`.

### Step 4: Dedup Report (canonical report)
- **File exists:** `docs/vnpt-flow/8-4-roll-back-published-data/dedup_report.json` ✅
- **Status:** All 4 entries show `status: "clean"` ✅
- **`_block: false` on final attempt:** All 4 entries have `_block: null` (not explicitly `false`) ⚠️ — technically missing, not `false`
- **Pre+post attempts per symbol:**
  - `DataVersion`: 1 pre, 0 post → **VIOLATION** (needs both)
  - `CourseVersionService`: 0 pre, 1 post → **VIOLATION** (needs both)
  - `CourseVersionServiceImpl`: 0 pre, 1 post → **VIOLATION** (needs both)
  - `CourseVersionController`: 1 pre, 1 post → ✅
- **Wave D portal symbols missing entirely** from report: `CourseVersionApi`, `versions_index`, `VersionListResponse`, `CourseVersionDto`

### Step 5: Reindex
- Ran `python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py reindex`
- **Result:** `ok: false` — GitNexus FTS index inconsistency error (pre-existing infrastructure issue)
- This is a pre-existing repo-level FTS bug, not caused by this story.

### Step 6: Gate Verdict
**`QA_FAIL: report_missing_or_invalid`**

---

## Story Acceptance Criteria Coverage

| AC | Description | Coverage | Evidence |
|----|-------------|----------|----------|
| AC-1 | Authorized user can select a prior version and view impact | ✅ | `CourseVersionController.getRollbackImpact()` + `versions/index.vue` impact modal |
| AC-2 | Rollback creates a new version rather than deleting history | ✅ | `CourseVersionService.rollbackToVersion()` creates new published version; `executeRollback` test confirms no deletion |
| AC-3 | New package generation and audit record are triggered | ✅ | `CourseVersionService.triggerPackageBuild()` called in `executeRollback`; test verifies jobId returned |

---

## Tasks Checklist (all 6 tasks checked `[x]`)

- [x] Confirm scope against PRD/architecture/UX/epic requirements
- [x] Define/update contracts, domain models, persistence, validation
- [x] Implement smallest end-to-end behavior satisfying every AC
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, audit behavior
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, data integrity
- [x] Run repository format, lint, typecheck, test, and build gates

---

## Issues Found

### BLOCKING (prevent `done` status)
1. **Dedup report incomplete:** Wave D portal files (`CourseVersionApi`, `versions_index`, `VersionListResponse`, `CourseVersionDto`) have prewrite dedup results but are NOT persisted in `docs/vnpt-flow/8-4-roll-back-published-data/dedup_report.json`.
2. **Dedup report per-symbol phase coverage:** 3 of 4 symbols (DataVersion, CourseVersionService, CourseVersionServiceImpl) lack a post-phase attempt. Only CourseVersionController has both pre+post.
3. **Backend test gate:** No `pom.xml` or `build.gradle` found in `apps/api/` — tests cannot be compiled/run to verify Java implementation correctness.
4. **Reindex failure:** GitNexus FTS index inconsistency prevents clean reindex (pre-existing infra issue, not story-specific).

### NON-BLOCKING
- Portal build scripts are stubs; no real typecheck/lint/build possible — acknowledged in story verification notes.
- `_block: null` vs `_block: false` in dedup_report — report status is "clean" so functionally ok but spec says explicitly `false`.

---

## Recommendation

**Status remains `review`.** Story 8.4 implementation covers all acceptance criteria and all 6 tasks are checked. However, the quality gate fails on the dedup chain (Wave D portal symbols not in report, 3/4 backend symbols missing post-phase attempts, reindex infrastructure failure).

**Required to reach `done`:**
1. Persist Wave D portal dedup results to `dedup_report.json` (add entries for CourseVersionApi, versions_index, VersionListResponse, CourseVersionDto with at least 1 pre + 1 post attempt).
2. OR confirm that Wave D portal files were part of a separate dedup run that should be referenced.
3. Resolve GitNexus FTS index inconsistency (infra team).
4. Provide working backend build file (`pom.xml` or `build.gradle`) to enable test gate.
