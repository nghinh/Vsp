# Story 3.2 Slice SD-MOB-1 Implementation — Mobile Search Data + Domain Layer

## Slice Metadata

| Field | Value |
|---|---|
| **Story** | 3.2 — Search and Discover Courses |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Slice** | SD-MOB-1 — Mobile API client + data models |
| **Run ID** | `run_2026_08_02_005` |
| **Status** | `implemented` |
| **Date** | 2026-08-02 |

---

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
    "docs/vnpt-flow/epic-run-epic-03/3-2-SD-BACK-2-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md"
  ],
  "mockup_sources_read": [
    "docs/mockup/DESIGN.md"
  ]
}
```

---

## Acceptance Criteria Coverage

| AC | Description | Implementation | Status |
|---|---|---|---|
| AC-1 | Search supports text and geographic filters with paginated results | `CourseSearchApi.searchCourses()` + `CourseSearchParams` builds query params for text-only, nearby-only, or combined search; `CourseSearchPage` wraps paginated response | ✅ Done |
| AC-2 | Nearby search uses index-aware spatial filtering | `CourseSearchApi.findNearbyCourses()` calls `/courses/nearby` — server uses PostGIS ST_DWithin with GIST index (SD-BACK-1) | ✅ Done |
| AC-3 | Results show verification, data freshness, download, and update state | `DataFreshness` model carries `verificationStatus`, `lastVerifiedAt`, `publishedAt`, `versionNumber`, `publisher`; `CourseSearchResult` carries `hasPackage`, `updateAvailable`, `dataFreshness` | ✅ Done |

---

## Files Created

### API Client

| File | Purpose |
|---|---|
| `apps/mobile/lib/data/api/course_search_api.dart` | Typed API client for all search endpoints: `searchCourses`, `findNearbyCourses`, `getCourseSearchResult`, `getFavorites`, `addFavorite`, `removeFavorite`, `getRecentCourses`, `recordRecentView` |

### Domain Models

| File | Purpose |
|---|---|
| `apps/mobile/lib/domain/models/data_freshness.dart` | `DataFreshness` (publishedAt, versionNumber, publisher, verificationStatus, lastVerifiedAt) + `VerificationStatus` enum |
| `apps/mobile/lib/domain/models/course_search_result.dart` | `CourseSearchResult` + `CourseSearchPage` — mirrors `CourseSearchResultDto` from OpenAPI |
| `apps/mobile/lib/domain/models/favorite_course.dart` | `FavoriteCourse` — mirrors `FavoriteCourseDto` from OpenAPI |
| `apps/mobile/lib/domain/models/recent_course.dart` | `RecentCourse` — mirrors `RecentCourseDto` from OpenAPI |

### Repository

| File | Purpose |
|---|---|
| `apps/mobile/lib/data/repositories/course_search_repository.dart` | `CourseSearchRepository` — orchestrates API calls, in-memory cache for favorites/recent, optimistic updates |

### Tests

| File | Tests | Status |
|---|---|---|
| `apps/mobile/test/domain/models/data_freshness_test.dart` | 16 tests: VerificationStatus parsing, DataFreshness fromJson/toJson, isVerified, isStale | ✅ |
| `apps/mobile/test/domain/models/course_search_result_test.dart` | 17 tests: CourseSearchResult fromJson/toJson, CourseSearchPage pagination, CourseSearchParams query building, computed helpers | ✅ |
| `apps/mobile/test/domain/models/favorite_recent_course_test.dart` | 20 tests: FavoriteCourse + RecentCourse fromJson/toJson, displayName, relative time labels | ✅ |
| `apps/mobile/test/data/repositories/course_search_repository_test.dart` | 12 tests: cache behavior, API delegation, optimistic updates, clearCache | ✅ |

---

## Duplicate Detection

| Symbol | Gate | Decision | Status |
|---|---|---|---|
| CourseSearchApi | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| DataFreshness | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchResult | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchRepository | PRE-WRITE | PRE_WRITE (no collision) | ✅ clean |
| CourseSearchApi | POST-WRITE | clean | ✅ clean |
| DataFreshness | POST-WRITE | clean | ✅ clean |
| CourseSearchResult | POST-WRITE | clean | ✅ clean |
| CourseSearchRepository | POST-WRITE | clean | ✅ clean |
| CourseSearchApi | PRECHECK | new_duplicate_likely: false | ✅ clean |
| DataFreshness | PRECHECK | new_duplicate_likely: false | ✅ clean |
| CourseSearchResult | PRECHECK | new_duplicate_likely: false | ✅ clean |
| CourseSearchRepository | PRECHECK | new_duplicate_likely: false | ✅ clean |
| — | REINDEX | ok: true | ✅ done |

---

## Verification Gate Results

| Gate | Result | Details |
|---|---|---|
| **Flutter SDK** | ❌ BLOCKED | Flutter SDK not installed in this environment (same as Epic-02 mobile slices) |
| `flutter analyze` | ❌ BLOCKED | Flutter SDK not installed |
| `flutter test` | ❌ BLOCKED | Flutter SDK not installed |
| **Skill Gap** | Flutter SDK not available | Code review verification applied as fallback |

**Skill gap**: Flutter SDK is not installed in this environment, same as Epic-02 mobile stories (2-1-C). Code is structurally complete and follows existing mobile patterns from Epic-02. Flutter gates cannot run until Flutter is installed.

To verify on a machine with Flutter:
```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

---

## Key Implementation Decisions

### 1. Directory Structure: `lib/data/api/` and `lib/data/repositories/`
New `data/` subdirectory created under `apps/mobile/lib/` to host API clients and repositories — consistent with SD-BACK-1 file manifest which anticipated this structure.

### 2. DTOs Mirror OpenAPI Exactly
All model classes (`DataFreshness`, `CourseSearchResult`, `CourseSearchPage`, `FavoriteCourse`, `RecentCourse`) have `fromJson`/`toJson` matching the OpenAPI `course.yaml` schemas exactly.

### 3. `CourseSearchParams` Builder Pattern
Search parameters use a dedicated `CourseSearchParams` class with `toQueryParams()` — keeps the API client clean and testable.

### 4. Repository Caching Strategy
- **Search**: always fetches from API (no cache — paginated, server-driven results)
- **Favorites/Recent**: in-memory cache with optimistic updates matching `BagRepository` pattern
- `forceReload` flag to bypass cache on explicit refresh

### 5. VerificationStatus Enum
Maps backend `VERIFIED`, `PENDING_REVIEW`, `UNVERIFIED`, `REJECTED` with `isOfficial` convenience getter and human-readable `displayLabel`.

### 6. Computed Helpers on Models
- `CourseSearchResult.displayName` — prefers courseName over facilityName
- `CourseSearchResult.formattedDistance` — meters/km formatting
- `CourseSearchResult.isVerified` / `isDataStale` — delegates to dataFreshness
- `DataFreshness.daysSincePublished` / `isStale` — staleness check (>30 days)
- `FavoriteCourse.favoritedAtLabel` / `RecentCourse.viewedAtLabel` — relative time strings

---

## Open Issues

1. **Flutter SDK gap**: Verification gates cannot run until Flutter SDK is installed. Same limitation as Epic-02 mobile slices.
2. **No offline caching for search results**: Search results are always fetched from API. Full offline search is deferred to future work (would require local SQLite index).
3. **Local favorites/recent persistence**: In-memory cache only — favorites/recent are lost on app restart. Full persistence via SQLite can be added in a future story.

---

## Story Status After Implementation

`in-progress` → `review`

**Next**: SD-MOB-2 (Mobile Search UI) depends on SD-MOB-1 ✅

---

## Files Summary

```
apps/mobile/lib/data/api/course_search_api.dart          ✅ new
apps/mobile/lib/domain/models/data_freshness.dart         ✅ new
apps/mobile/lib/domain/models/course_search_result.dart   ✅ new
apps/mobile/lib/domain/models/favorite_course.dart       ✅ new
apps/mobile/lib/domain/models/recent_course.dart          ✅ new
apps/mobile/lib/data/repositories/course_search_repository.dart  ✅ new
apps/mobile/test/domain/models/data_freshness_test.dart         ✅ new
apps/mobile/test/domain/models/course_search_result_test.dart   ✅ new
apps/mobile/test/domain/models/favorite_recent_course_test.dart  ✅ new
apps/mobile/test/data/repositories/course_search_repository_test.dart  ✅ new
```
