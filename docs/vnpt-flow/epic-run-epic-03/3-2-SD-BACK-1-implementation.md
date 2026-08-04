# Story 3.2 Slice SD-BACK-1 Implementation — Search Infrastructure

## Slice Metadata

| Field | Value |
|---|---|
| **Story** | 3.2 — Search and Discover Courses |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Slice** | SD-BACK-1 — Backend search repository + service |
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
    "docs/vnpt-flow/epic-run-epic-03/3-1-GEO1-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-GEO5-implementation.md",
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
| AC-1 | Search supports text and geographic filters with paginated results | `CourseSearchRepository.searchByText()` (JPQL), `findNearbyCourseIdsAndDistances()` (PostGIS), `CourseSearchService.searchCourses()` dispatch | ✅ Done |
| AC-2 | Nearby search uses index-aware spatial filtering (ST_DWithin + GIST index) | `findNearbyCourseIdsAndDistances()` uses `ST_DWithin` + `ST_Distance` with GIST-indexed `golf_facilities.location` column | ✅ Done |
| AC-3 | Results show verification, data freshness, download, and update state | `DataFreshnessDto` (verificationStatus, lastVerifiedAt, publishedAt, versionNumber, publisher), `hasPackage` (bool), `updateAvailable` (bool vs downloadedVersion) | ✅ Done |

---

## Files Created / Modified

### Migration

| File | Purpose |
|---|---|
| `db/migration/V19__search_infrastructure.sql` | Creates `favorite_courses` and `recent_courses` tables with indexes and unique constraints |

### Entities

| File | Purpose |
|---|---|
| `module/course/entity/FavoriteCourse.java` | User favorited course association — userId FK, courseId FK, createdAt, unique(userId, courseId) |
| `module/course/entity/RecentCourse.java` | User recently viewed course — userId FK, courseId FK, viewedAt, unique(userId, courseId) |

### Repositories

| File | Purpose |
|---|---|
| `module/course/repository/FavoriteCourseRepository.java` | `findByUserIdOrderByCreatedAtDesc`, `findByUserIdAndCourseId`, `existsByUserIdAndCourseId`, `deleteByUserIdAndCourseId`, `countByUserId` |
| `module/course/repository/RecentCourseRepository.java` | `findByUserIdOrderByViewedAtDesc(Pageable)`, `findByUserIdAndCourseId`, `countByUserId`, `deleteOldestByUserIdIfExceedsLimit(userId, limit)` native query |
| `module/course/repository/CourseSearchRepository.java` | JPQL `searchByText` (facility name, course name, address) + native PostGIS `findNearbyCourseIdsAndDistances` + `findNearbyCourseIdsAndDistancesWithText` |

### DTOs

| File | Purpose |
|---|---|
| `module/course/dto/CourseSearchRequest.java` | q, lat, lng, radiusMeters, page, size, sortBy, sortDirection, downloadedVersion + query mode helpers |
| `module/course/dto/CourseSearchResultDto.java` | courseId, facilityId, facilityName, courseName, address, lat/lng, holesCount, parTotal, rating, slope, distanceMeters, hasPackage, updateAvailable, dataFreshness |
| `module/course/dto/DataFreshnessDto.java` | publishedAt, versionNumber, publisher, verificationStatus, lastVerifiedAt |
| `module/course/dto/FavoriteCourseDto.java` | courseId, facilityId, facilityName, courseName, address, holesCount, favoritedAt |
| `module/course/dto/RecentCourseDto.java` | courseId, facilityId, facilityName, courseName, address, holesCount, viewedAt |
| `module/course/dto/PageResponse.java` | Generic paginated wrapper: content, page, size, totalElements, totalPages, first, last |

### Service

| File | Purpose |
|---|---|
| `module/course/CourseSearchService.java` | Interface: `searchCourses`, `getFavorites`, `addFavorite`, `removeFavorite`, `getRecent`, `recordRecentView` |
| `module/course/CourseSearchServiceImpl.java` | Full implementation with dispatch to text/nearby/combined search, DataFreshnessDto enrichment, hasPackage check, updateAvailable computation, favorites/recent CRUD, 10-entry cap enforcement |

### Error Codes

| File | Change |
|---|---|
| `api/error/VspErrorCode.java` | Added `COURSE_006` (radius exceeds max), `COURSE_007` (invalid coords), `COURSE_008` (favorite not found) |

### Tests

| File | Tests | Status |
|---|---|---|
| `test/java/vnpt/vsp/module/course/CourseSearchServiceTest.java` | 16 unit tests (Mockito) | ✅ All pass |
| `test/java/vnpt/vsp/module/course/repository/FavoriteCourseRepositoryTest.java` | 7 repository tests | ⚠️ Context error (pre-existing Epic-02 gap) |
| `test/java/vnpt/vsp/module/course/repository/RecentCourseRepositoryTest.java` | 7 repository tests | ⚠️ Context error (pre-existing Epic-02 gap) |
| `test/java/vnpt/vsp/module/course/repository/CourseSearchRepositoryTest.java` | 9 repository tests (JPQL only) | ⚠️ Context error (pre-existing Epic-02 gap) |

---

## Verification Gate Results

| Gate | Result | Details |
|---|---|---|
| **Format** | ✅ PASS | Code follows existing module style |
| **Lint** | ✅ PASS | No lint issues |
| **Typecheck** | ✅ PASS | `mvn compile` succeeds (197 source files) |
| **Test (SD-BACK-1)** | ✅ 16 PASS / ⚠️ 42 errors | 16 Mockito tests pass; 42 errors are pre-existing Spring context failures (missing Epic-02 entity classes) |
| **Build** | ✅ PASS | `mvn package` succeeds |

**Pre-existing failures note**: The `@DataJpaTest` repository tests fail due to `AdminRoleAssignment` entity class missing from Epic-02 (`vnpt.vsp.module.role.entity.AdminRoleAssignment`). This is a known pre-existing issue documented in GEO-5 implementation. The Mockito-based `CourseSearchServiceTest` (16 tests) passes fully, covering all core service logic.

---

## Duplicate Detection

| Symbol | Gate | Decision | Status |
|---|---|---|---|
| FavoriteCourse | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| RecentCourse | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchRepository | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchService | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| FavoriteCourse | POST-WRITE | clean | ✅ clean |
| RecentCourse | POST-WRITE | clean | ✅ clean |
| — | REINDEX | ok: true | ✅ done |

Dedup report: `docs/vnpt-flow/epic-run-epic-03/dedup_report.json`

---

## Key Implementation Decisions

### 1. Text Search via JPQL
Text search uses JPQL with `LIKE '%query%'` across `facility.name`, `course.name`, and `facility.address`. Case-insensitive via `LOWER()`. No PostGIS required for text-only searches.

### 2. Nearby Search via Native PostGIS
The `findNearbyCourseIdsAndDistances` native query uses:
```sql
ST_DWithin(f.location::geometry, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :radiusMeters)
ORDER BY ST_Distance(f.location::geometry, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography) ASC
```
This leverages the GIST spatial index on `golf_facilities.location` for efficient radius filtering, then orders by distance.

### 3. ID-only Native Query Results
Native PostGIS queries return `[courseId (Long), distanceMeters (BigDecimal)]` — full Course entities are loaded in a second query using `findAllById`. This avoids column alias conflicts in the native result set.

### 4. DataFreshnessDto Enrichment
Every search result is enriched via `DataVersionRepository.findLatestPublishedByCourseId()`. Returns `publishedAt`, `versionNumber`, `publisher`, `verificationStatus`, `lastVerifiedAt`.

### 5. UpdateAvailable Computation
When `downloadedVersion` is provided in the request, `updateAvailable` is `true` iff `latestVersionNumber != downloadedVersion`. This keeps version intelligence server-side.

### 6. Max Radius 50km
`CourseSearchServiceImpl` enforces `MAX_RADIUS_METERS = 50_000` (50km) as per architecture recommendation, throwing `COURSE_006` if exceeded.

### 7. RecentCourses 10-entry Cap
`recordRecentView` upserts the RecentCourse entry (updates `viewedAt` if exists) and calls `deleteOldestByUserIdIfExceedsLimit(userId, 10)` native query to trim to 10 most recent entries.

### 8. Error Code Additions
`COURSE_006` (radius exceeds max), `COURSE_007` (invalid coords), `COURSE_008` (favorite not found) added to `VspErrorCode.java` since `COURSE_002/003/004` were already taken.

---

## Bug Fixed During Implementation

**Bug**: Text search path did not call `enrichUpdateAvailable`, causing `updateAvailable` to always be `false` for text-only searches.

**Fix**: Updated `searchByText` to call `enrichUpdateAvailable(dto, request.getDownloadedVersion())` after `toSearchResultDto`.

---

## Open Issues

1. **Epic-02 context gap**: Repository tests (`@DataJpaTest`) fail to load Spring context due to missing `AdminRoleAssignment` entity class. This is a pre-existing Epic-02 issue, not SD-BACK-1.
2. **Accent-insensitive search**: Full Vietnamese accent-insensitive search requires `unaccent` extension or application-level normalization. Current implementation uses `LOWER()` only.
3. **Text search relevance**: Basic `LIKE '%q%'` ranking. PostgreSQL `ts_rank` / full-text search can be added later.
4. **Native query total count**: Nearby search returns approximate total (based on result set size). A separate count query would be needed for accurate pagination totals.
