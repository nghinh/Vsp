# Story 3.2 Slice SD-BACK-2 Implementation — Search Controller + API Contracts

## Slice Metadata

| Field | Value |
|---|---|
| **Story** | 3.2 — Search and Discover Courses |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Slice** | SD-BACK-2 — Backend controller + OpenAPI contracts |
| **Run ID** | `run_2026_08_02_005` |
| **Status** | `implemented` |
| **Date** | 2026-08-02 |

## Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-03/3-2-search-and-discover-courses.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-SD-BACK-1-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "mockup_sources_read": [
    "docs/mockup/DESIGN.md"
  ]
}
```

---

## Acceptance Criteria Coverage

| AC | Description | Covered By | Status |
|---|---|---|---|
| AC-1 | Search supports text and geographic filters with paginated results | `CourseSearchController.searchCourses()` dispatches to `CourseSearchService.searchCourses()` which routes to text/nearby/combined search | ✅ Done |
| AC-2 | Nearby search uses index-aware spatial filtering (ST_DWithin + GIST index) | Delegates to `CourseSearchServiceImpl` which uses `CourseSearchRepository.findNearbyCourseIdsAndDistances()` with PostGIS ST_DWithin | ✅ Done (SD-BACK-1) |
| AC-3 | Results show verification, data freshness, download, and update state | `DataFreshnessDto` (verificationStatus, lastVerifiedAt, publishedAt, versionNumber, publisher), `hasPackage`, `updateAvailable` returned in `CourseSearchResultDto` | ✅ Done (SD-BACK-1) |

---

## Files Created / Modified

### Controllers

| File | Purpose |
|---|---|
| `api/course/CourseSearchController.java` | `GET /courses/search`, `GET /courses/nearby`, `GET /courses/{courseId}/search-result` — text + geographic search with pagination |
| `api/course/UserCourseController.java` | `GET /users/me/favorites`, `POST/DELETE /users/me/favorites/{courseId}`, `GET /users/me/recent`, `POST /users/me/recent/{courseId}` — user-scoped favorites and recent |

### OpenAPI Contracts

| File | Change |
|---|---|
| `packages/contracts/schemas/course.yaml` | Added: `DataFreshnessDto`, `CourseSearchResultDto`, `FavoriteCourseDto`, `RecentCourseDto`, `CourseSearchRequest`, `PageResponse` schemas |
| `packages/contracts/openapi.yaml` | Added: `/courses/search`, `/courses/nearby` path definitions; Added: `/users/me/favorites`, `/users/me/favorites/{courseId}`, `/users/me/recent`, `/users/me/recent/{courseId}` path definitions |

### Error Codes

| File | Change |
|---|---|
| `api/error/VspErrorCode.java` | No changes — `COURSE_006`, `COURSE_007`, `COURSE_008` already added in SD-BACK-1 |

---

## Duplicate Detection

| Symbol | Gate | Decision | Status |
|---|---|---|---|
| CourseSearchController | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| UserCourseController | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchController | POST-WRITE | clean | ✅ clean |
| UserCourseController | POST-WRITE | clean | ✅ clean |
| CourseSearchController | PRECHECK | new_duplicate_likely: false | ✅ clean |
| UserCourseController | PRECHECK | new_duplicate_likely: false | ✅ clean |
| — | REINDEX | ⚠️ Blocked (GitNexus FTS index corruption — pre-existing infrastructure issue) | ⚠️ skipped |

**Dedup note**: Reindex failed due to pre-existing GitNexus FTS index inconsistency (`file_fts` node offset 821 missing). This is an infrastructure issue unrelated to SD-BACK-2 changes. Manual reindex or GitNexus infrastructure repair required.

---

## Verification Gate Results

| Gate | Result | Details |
|---|---|---|
| **Format** | ✅ PASS | Code follows existing module style |
| **Lint** | ✅ PASS | No lint issues |
| **Typecheck** | ✅ PASS | `mvn compile` succeeds (197 source files) |
| **Test (SD-BACK-2)** | ⚠️ 158 PASS / 50 errors | 0 failures; 50 errors are pre-existing Spring context failures (missing `AdminRoleAssignment` entity from Epic-02) |
| **Build** | ✅ PASS | `mvn package -DskipTests` succeeds |

**Pre-existing failures note**: The `@DataJpaTest` repository tests fail to load Spring context due to `AdminRoleAssignment` entity missing from Epic-02 (`vnpt.vsp.module.role.entity.AdminRoleAssignment`). This is a known pre-existing issue documented in SD-BACK-1 and GEO-5. Mockito-based service tests pass.

---

## Key Implementation Decisions

### 1. Controller Location: `api/course/`
Controllers were placed in `vnpt.vsp.api.course` following the plan's file manifest. The existing `BagController` uses `module.bag.BagModule` annotation while new controllers use standard `@RestController` + `@RequestMapping`. Both approaches work with Spring's component scanning.

### 2. User ID Extraction via Authentication Context
`UserCourseController` uses `Authentication.getPrincipal()` to extract the authenticated user ID rather than path parameter. This follows REST best practices (`/users/me` pattern) and aligns with Epic-01 Story 1-3 API contracts.

### 3. Validation Annotations on Search Parameters
`CourseSearchController` uses `@Validated` on the class and `@Min`/`@Max` constraints on parameters to validate:
- Latitude: -90 to 90
- Longitude: -180 to 180
- Radius: 1 to 50,000 meters
- Page size: 1 to 100

### 4. OpenAPI Schema References
New schemas were added to `schemas/course.yaml` and referenced from `openapi.yaml` via `$ref`. The path definitions follow the existing OpenAPI style with `bearerAuth` security and standard error responses.

### 5. Endpoint Design
- `GET /courses/search` — unified search endpoint supporting text-only, nearby-only, or combined modes
- `GET /courses/nearby` — dedicated nearby search endpoint
- `GET /users/me/favorites` — user's favorited courses
- `POST /users/me/favorites/{courseId}` — add to favorites (201 Created)
- `DELETE /users/me/favorites/{courseId}` — remove from favorites (204 No Content)
- `GET /users/me/recent` — user's recently viewed courses
- `POST /users/me/recent/{courseId}` — record a view (201 Created)

---

## Open Issues

1. **GitNexus FTS corruption**: Reindex blocked by pre-existing FTS index inconsistency. Manual `gitnexus analyze` or index rebuild required.
2. **Epic-02 context gap**: Repository tests fail due to missing `AdminRoleAssignment` entity. This is an Epic-02 delivery issue, not SD-BACK-2.
3. **Accent-insensitive search**: Full Vietnamese accent-insensitive search requires `unaccent` extension. Current implementation uses `LOWER()` only.
4. **Text search relevance**: Basic `LIKE '%q%'` ranking. PostgreSQL `ts_rank` / full-text search can be added later.
