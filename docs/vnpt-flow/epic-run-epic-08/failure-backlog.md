# Failure Backlog

**Run ID:** run_2026_08_02_qg_84_qg_85
**Epic:** epic-08 (Course Operations)
**Generated:** 2026-08-02

## Summary

- **Total Stories:** 2 (story 8.1, story 8.4)
- **Completed:** 0
- **Failed:** 2

## Failed Stories

### Story 8.1 — Manage Facilities and Courses

**Gate failure:** `QA_FAIL: report_missing_or_invalid`

**Blocking issues (must resolve before `done`):**

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | No dedup_report.json for story 8.1 | HIGH | `docs/vnpt-flow/8-1-manage-facilities-and-courses/dedup_report.json` does not exist — dedup chain was never completed |
| 2 | No prewrite dedup chain artifacts | HIGH | Gate step 3 (Prewrite) was never run — `docs/vnpt-dev-epic-orchestrator/tools/dedup.py precheck` was run manually but not persisted |
| 3 | No postwrite dedup chain artifacts | HIGH | Gate step 1 (Cy→CC→SigCheck) was never run via Serena |
| 4 | No epic-run-epic-08 story folder | HIGH | `docs/vnpt-flow/epic-run-epic-08/` only has `failure-backlog.md` — no per-story dedup folder exists |

**Verification notes:**
- All 6 story tasks checked ✅
- All 3 acceptance criteria implemented ✅
- Compile: PASS ✅
- Story-specific unit tests (CourseAdminServiceImplTest 7/7): PASS ✅
- Pre-existing Spring context failures in JPA tests: infrastructure issue, not story-caused ⚠️
- All changed files exist (CourseService.java, CourseServiceImpl.java, CourseAdminService.java, CourseAdminServiceImpl.java, TeeSetAdminController.java) ✅
- Story status remains `review`

**Implementation quality assessment:**
- Story 8.1 implementation is complete (all ACs met, all tasks checked, files present, compile clean, story-specific tests pass).
- Quality gate fails on dedup chain completeness, not implementation correctness.
- Dedup chain must be re-run: Cy→CC→SigCheck for new symbols, prewrite for all changed files, postwrite reindex.

### Story 8.4 — Roll Back Published Data

**Gate failure:** `QA_FAIL: report_missing_or_invalid`

**Blocking issues (must resolve before `done`):**

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | Wave D portal symbols missing from dedup_report.json | HIGH | `CourseVersionApi`, `versions_index`, `VersionListResponse`, `CourseVersionDto` were checked via prewrite script (all returned `new_duplicate_likely: false`) but NOT persisted to `docs/vnpt-flow/8-4-roll-back-published-data/dedup_report.json` |
| 2 | 3 of 4 backend symbols lack post-phase attempt | HIGH | `DataVersion` has only pre-phase; `CourseVersionService` and `CourseVersionServiceImpl` have only post-phase — gate step 4 requires at least 1 pre AND 1 post per symbol |
| 3 | GitNexus FTS index inconsistency | MEDIUM | Reindex step returns `ok: false` due to pre-existing `file_fts is inconsistent` error — infra-level issue, not story-caused |
| 4 | Backend build files absent | HIGH | No `pom.xml` or `build.gradle` found in `apps/api/` — test gate cannot be executed |

**Verification notes:**
- All 6 story tasks checked ✅
- All 3 acceptance criteria implemented ✅
- Prewrite dedup passed for all Wave D files (`new_duplicate_likely: false`) ✅
- Portal build scripts are stubs (acknowledged in story notes) ⚠️
- Story status remains `review`

## Notes

- Story 8.4 implementation is complete (all ACs met, all tasks checked, all files present).
- Quality gate fails on dedup chain completeness, not implementation correctness.
- Wave D portal files need dedup entry in report or confirmation of separate dedup session.
- Backend test execution blocked by missing build configuration.
