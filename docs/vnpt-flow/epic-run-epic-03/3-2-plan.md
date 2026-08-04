# Story 3.2 Plan — Search and Discover Courses

## Runner Evidence

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
    "docs/vnpt-flow/epic-run-epic-03/3-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-GEO1-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-GEO3-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-GEO5-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/epic-summary.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "mockup_sources_read": [
    "docs/mockup/DESIGN.md"
  ]
}
```

## Story Metadata

| Field | Value |
|---|---|
| **Story** | 3.2 |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Title** | Search and Discover Courses |
| **Status** | `ready-for-dev` → `planned` |
| **Phase** | MVP 1 |
| **Wave** | 2 of 4 (3-2 depends on 3-1 completed ✅) |
| **Run ID** | `run_2026_08_02_005` |
| **Plan Generated** | 2026-08-02 |

---

## Context Analysis

### PRD Constraints (prd.md)

- **§8.2 Course Search**: Users search by course name, province/city, nearby location, country, favorites, and recently played. Course details include address, coordinates, phone, website, images, holes, tee sets, services, local rules, current condition, rating/slope, and last data update.
- **§9.1 Core Entities**: GolfFacility, Course, Hole, TeeSet, CourseCondition, DataVersion are all available from 3-1.
- **§9.2 Geospatial Standards**: WGS84/SRID 4326, ST_DWithin for nearby queries — satisfied by existing GIST indexes.
- **§9.3 Data Quality Fields**: `verificationStatus`, `lastVerifiedAt`, `effectiveDate`, `expiryDate`, `version` on DataQualityMetadata — available on all course entities.
- **§10.1 Accuracy**: GPS accuracy visible — deferred to GPS story (not in 3-2 scope).

### Architecture Constraints (architecture.md)

- **§7.1**: PostgreSQL/PostGIS source of truth — spatial queries via GeospatialService.
- **§7.2 Spatial Practices**: ST_DWithin for nearby queries — GeospatialService already has this.
- **§11.2 Minimum API Groups**: `/courses/*` endpoints required.
- **Modular Monolith §6.1**: Course Catalog module owns search; GeospatialService for spatial ops only.

### 3-1 Dependency Analysis

| 3-1 Output | Used In 3-2 | Status |
|---|---|---|
| `GolfFacility` entity + `location` POINT(4326) | Nearby search via facility location | ✅ Available |
| `Course` entity + `location` Geometry(4326) | Nearby search via course location | ✅ Available |
| GIST indexes on `golf_facilities.location`, `courses.location` | ST_DWithin index-aware filtering | ✅ Available |
| `GeospatialService.findFeaturesWithinRadius()` | Find nearby facilities | ✅ Available |
| `GeospatialService.findNearestFeature()` | Find nearest course | ✅ Available |
| `DataQualityMetadata` (`verificationStatus`, `lastVerifiedAt`) | Verification badge + freshness | ✅ Available |
| `DataVersion` entity (`publishedAt`, `versionNumber`) | Data freshness timestamp | ✅ Available |
| `CourseRepository` | Base for search queries | ✅ Available (no search methods yet) |
| `CourseService` | Base for course lookups | ✅ Available (no search methods yet) |

### UX/DESIGN.md Constraints

- **Course Search screen** (ux-spec §5.2): Search bar with nearby shortcut, favorites section, recent section, course status badges.
- **Course status badges**: downloaded, update available, official data, stale data.
- **Typography**: Fira Sans (UI) + Fira Code (distances/metrics).
- **Badges**: official (solid green), estimated (green border), community (dark grey), stale (red strikethrough).
- **Accessibility**: 4.5:1 contrast, 44/48dp touch targets.

### Epic-02 Context

Epic-02 (Golfer Management) is fully complete. User entity and authentication are available. Favorites and recent features require user-scoped persistence.

---

## Scope Analysis

### AC Breakdown

| AC | Description | Nature | Owner |
|---|---|---|---|
| AC-1 | Search supports text and geographic filters with paginated results | API + query | Backend |
| AC-2 | Nearby search uses index-aware spatial filtering | PostGIS GIST + ST_DWithin | Backend |
| AC-3 | Results show verification, data freshness, download, and update state | DTO fields + API response | Backend |

### What "Results show X" Means in API Context

The API response for each course result includes:
- **verification**: `verificationStatus` (from DataQualityMetadata) + `lastVerifiedAt` timestamp
- **data freshness**: `publishedAt` from latest DataVersion + `versionNumber`
- **download state**: `hasPackage` boolean (does a published DataVersion exist with a package?) — package detail is 3-3 scope; here we surface existence
- **update state**: `latestVersionNumber` vs mobile-reported `downloadedVersionNumber` (passed as optional request param) — compared server-side, returned as `updateAvailable: boolean`

### Search Modes

1. **Text search**: `?q=<name>` — searches GolfFacility.name, Course.name, GolfFacility.address, facility city
2. **Nearby search**: `?lat=<>&lng=<>&radius=<>` — ST_DWithin on GolfFacility.location POINT
3. **Favorites**: `GET /users/{userId}/favorites` — user-scoped course list
4. **Recent**: `GET /users/{userId}/recent` — user-scoped last-10 courses viewed
5. **Combined**: text + nearby in single request

### User-Scoped Entities Required

Favorites and Recent require two new JPA entities:
- `FavoriteCourse`: `userId`, `courseId`, `createdAt`
- `RecentCourse`: `userId`, `courseId`, `viewedAt`

These use the authenticated user ID from Epic-02 context.

### Data Freshness Model

For each course in search results, return:
```json
{
  "dataFreshness": {
    "publishedAt": "2026-07-15T10:00:00Z",
    "versionNumber": 3,
    "publisher": "Thuyle Golf Club",
    "verificationStatus": "VERIFIED",
    "lastVerifiedAt": "2026-07-14T08:30:00Z"
  }
}
```

### Download/Update State

The `hasPackage` flag is computed from whether a DataVersion with status=PUBLISHED has an associated package. Full package download tracking (mobile-side) is story 3-3. For 3-2, the API surfaces:
- `hasPackage: boolean` — published package exists
- `updateAvailable: boolean` — requires `downloadedVersion` in request; compared against latest `versionNumber`

---

## Slice Plan

### Slice SD-BACK-1 — Search Infrastructure (Repository + Service + DTOs)
**Depends on**: 3-1 (COMPLETED ✅)
**Risk**: LOW — pure backend query layer

1. **New entities** — `module/course/entity/`
   - `FavoriteCourse.java` — userId (FK), courseId (FK), createdAt; unique constraint on (userId, courseId)
   - `RecentCourse.java` — userId (FK), courseId (FK), viewedAt; unique constraint on (userId, courseId)

2. **New repositories** — `module/course/repository/`
   - `FavoriteCourseRepository.java` — `findByUserId(userId)`, `existsByUserIdAndCourseId`, `deleteByUserIdAndCourseId`
   - `RecentCourseRepository.java` — `findByUserIdOrderByViewedAtDesc(userId, Pageable)`, `findByUserIdAndCourseId`, `deleteOldestByUserIdIfExceedsLimit(userId, limit)`

3. **CourseSearchRepository** — extends `CourseRepository`
   - JPQL text search: facility name, course name, facility address/city (case-insensitive, accent-insensitive where possible)
   - Native PostGIS query: ST_DWithin on `golf_facilities.location` POINT with radius in meters, ordered by distance ASC
   - Combined query: text filter + ST_DWithin in single native query

4. **DTOs** — `module/course/dto/`
   - `CourseSearchResultDto.java` — id, name, address, location (lat/lng), holesCount, rating, slope, hasPackage, updateAvailable, dataFreshness (nested)
   - `CourseSearchRequest.java` — q, lat, lng, radiusMeters, page, size, sortBy, downloadedVersion
   - `PageResponse.java` — standard paginated wrapper (content, page, size, totalElements, totalPages)
   - `DataFreshnessDto.java` — publishedAt, versionNumber, publisher, verificationStatus, lastVerifiedAt
   - `FavoriteCourseDto.java` — course summary + favoritedAt
   - `RecentCourseDto.java` — course summary + viewedAt

5. **CourseSearchService** — `module/course/`
   - `searchCourses(request: CourseSearchRequest): PageResponse<CourseSearchResultDto>`
     - Dispatches to text search or nearby search or combined
     - Enriches each result with DataFreshnessDto from DataQualityMetadata + DataVersion
     - Computes hasPackage from DataVersionRepository (latest published version has package?)
     - Computes updateAvailable when downloadedVersion is provided
   - `getFavorites(userId: Long): List<FavoriteCourseDto>`
   - `addFavorite(userId: Long, courseId: Long): FavoriteCourse`
   - `removeFavorite(userId: Long, courseId: Long): void`
   - `getRecent(userId: Long, limit: int): List<RecentCourseDto>`
   - `recordRecentView(userId: Long, courseId: Long): void` — upserts RecentCourse, trims to 10 most recent

6. **Tests**
   - `CourseSearchServiceTest` — text search, nearby search, combined search, pagination
   - `CourseSearchRepositoryTest` — JPQL text search, native PostGIS nearby search
   - `FavoriteCourseRepositoryTest` — CRUD + unique constraint
   - `RecentCourseRepositoryTest` — upsert + trim to limit

---

### Slice SD-BACK-2 — Search Controller + API Contracts
**Depends on**: SD-BACK-1 ✅
**Risk**: LOW — thin controller layer

1. **CourseSearchController** — `api/course/`
   - `GET /courses/search?q=&lat=&lng=&radius=&page=&size=` — text + geographic search
   - `GET /courses/nearby?lat=&lng=&radius=&page=&size=` — pure nearby search
   - `GET /courses/{id}/search-result` — single course search result with freshness

2. **UserCourseController** — `api/course/`
   - `GET /users/{userId}/favorites` — list favorites
   - `POST /users/{userId}/favorites/{courseId}` — add favorite
   - `DELETE /users/{userId}/favorites/{courseId}` — remove favorite
   - `GET /users/{userId}/recent` — list recent (last 10)
   - `POST /users/{userId}/recent/{courseId}` — record recent view

3. **OpenAPI additions** — `contracts/`
   - Add CourseSearchRequest/Response schemas to existing courses spec
   - Add FavoriteCourseDto, RecentCourseDto, DataFreshnessDto schemas

4. **Error codes** — `VspErrorCode.java`
   - `COURSE_001` — Course not found
   - `COURSE_002` — Search radius exceeds maximum (50km)
   - `COURSE_003` — Invalid coordinates
   - `COURSE_004` — Favorite not found

5. **Tests**
   - `CourseSearchControllerTest` — endpoint tests with MockMvc
   - `UserCourseControllerTest` — favorites/recent CRUD tests

---

### Slice SD-MOB-1 — Mobile Search Data + Domain Layer
**Depends on**: SD-BACK-2 (API contracts finalized)
**Risk**: MEDIUM — Flutter not installed; code review verification only

1. **API client** — `mobile/lib/data/api/`
   - `course_search_api.dart` — typed API client for all search endpoints

2. **Models** — `mobile/lib/domain/models/`
   - `course_search_result.dart` — mirrors CourseSearchResultDto
   - `data_freshness.dart` — mirrors DataFreshnessDto
   - `favorite_course.dart`
   - `recent_course.dart`

3. **Repository** — `mobile/lib/data/repositories/`
   - `course_search_repository.dart` — API calls + local caching strategy

4. **Tests**
   - Model serialization tests (fromJson/toJson)
   - Repository mock tests

---

### Slice SD-MOB-2 — Mobile Search UI
**Depends on**: SD-MOB-1 ✅
**Risk**: MEDIUM — Flutter not installed; code review verification only

1. **Course Search Screen** — `mobile/lib/presentation/screens/`
   - `course_search_screen.dart` — search bar, nearby button, results list, favorites tab, recent tab
   - Bottom navigation integration (Courses tab)

2. **BLoC / State** — `mobile/lib/presentation/bloc/`
   - `course_search_bloc.dart` — handles search query, location, pagination events
   - `course_search_state.dart` — states: initial, loading, loaded, error, empty

3. **Widgets** — `mobile/lib/presentation/widgets/`
   - `search_bar_widget.dart` — text input + clear + submit
   - `nearby_button.dart` — GPS location trigger
   - `course_card.dart` — course name, address, distance, verification badge, freshness badge, download badge
   - `verification_badge.dart` — VERIFIED (green solid), PENDING_REVIEW (amber border), UNVERIFIED (grey)
   - `freshness_badge.dart` — "Updated X days ago" or "Stale" for >30 days
   - `download_state_badge.dart` — downloaded (green check), update available (amber), not downloaded (grey)
   - `favorite_button.dart` — toggle favorite
   - `recent_course_tile.dart` — course name + viewed-at timestamp
   - `empty_search_state.dart` — empty results illustration + messaging

4. **Design system compliance**
   - Fira Sans / Fira Code typography per DESIGN.md
   - Semantic color tokens per ux-spec.md
   - 44/48dp touch targets
   - 4.5:1 contrast

5. **Tests**
   - Widget tests for CourseCard, VerificationBadge, FreshnessBadge
   - BLoC unit tests

---

## Verification Gates

| Slice | Format | Lint | Typecheck | Test | Build |
|---|---|---|---|---|---|
| SD-BACK-1 | ✅ | ✅ | ✅ `mvn compile` | ✅ `mvn test` | ✅ `mvn package` |
| SD-BACK-2 | ✅ | ✅ | ✅ `mvn compile` | ✅ `mvn test` | ✅ `mvn package` |
| SD-MOB-1 | ✅ | `flutter analyze` (skill gap) | `flutter analyze` (skill gap) | model tests | — |
| SD-MOB-2 | ✅ | `flutter analyze` (skill gap) | `flutter analyze` (skill gap) | widget tests | `flutter build apk` (skill gap) |

**Skill gap note**: Flutter SDK is not installed in this environment (same as Epic-02 stories with mobile slices). Code will be written and reviewed via code review workflow; `flutter analyze` gates cannot run until Flutter is installed.

---

## Quality Gate: Pre-Write Dedup

Before writing each slice, run:
```
python3 "docs/vnpt-flow/epic-run-epic-03/tools/dedup.py" precheck <EntityName> --file apps/api/src/main/java/vnpt/vsp/module/course/entity/<EntityName>.java
```
Expected: `new_duplicate_likely: false`

---

## File Manifest

### SD-BACK-1

**Entities:**
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/FavoriteCourse.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/RecentCourse.java`

**Repositories:**
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/FavoriteCourseRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/RecentCourseRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/CourseSearchRepository.java`

**DTOs:**
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseSearchRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseSearchResultDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/DataFreshnessDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/FavoriteCourseDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/RecentCourseDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/PageResponse.java`

**Service:**
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseSearchService.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseSearchServiceImpl.java`

**Tests:**
- `apps/api/src/test/java/vnpt/vsp/module/course/CourseSearchServiceTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/CourseSearchRepositoryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/FavoriteCourseRepositoryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/RecentCourseRepositoryTest.java`

### SD-BACK-2

**Controllers:**
- `apps/api/src/main/java/vnpt/vsp/api/course/CourseSearchController.java`
- `apps/api/src/main/java/vnpt/vsp/api/course/UserCourseController.java`

**Error codes:**
- `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` (additions)

**OpenAPI:**
- `packages/contracts/src/main/resources/openapi/courses.yaml` (additions)

**Tests:**
- `apps/api/src/test/java/vnpt/vsp/api/course/CourseSearchControllerTest.java`
- `apps/api/src/test/java/vnpt/vsp/api/course/UserCourseControllerTest.java`

### SD-MOB-1

**API client:**
- `apps/mobile/lib/data/api/course_search_api.dart`

**Models:**
- `apps/mobile/lib/domain/models/course_search_result.dart`
- `apps/mobile/lib/domain/models/data_freshness.dart`
- `apps/mobile/lib/domain/models/favorite_course.dart`
- `apps/mobile/lib/domain/models/recent_course.dart`

**Repository:**
- `apps/mobile/lib/data/repositories/course_search_repository.dart`

**Tests:**
- `apps/mobile/test/domain/models/course_search_result_test.dart`
- `apps/mobile/test/data/repositories/course_search_repository_test.dart`

### SD-MOB-2

**Screen:**
- `apps/mobile/lib/presentation/screens/course_search_screen.dart`

**BLoC:**
- `apps/mobile/lib/presentation/bloc/course_search_bloc.dart`
- `apps/mobile/lib/presentation/bloc/course_search_event.dart`
- `apps/mobile/lib/presentation/bloc/course_search_state.dart`

**Widgets:**
- `apps/mobile/lib/presentation/widgets/search_bar_widget.dart`
- `apps/mobile/lib/presentation/widgets/nearby_button.dart`
- `apps/mobile/lib/presentation/widgets/course_card.dart`
- `apps/mobile/lib/presentation/widgets/verification_badge.dart`
- `apps/mobile/lib/presentation/widgets/freshness_badge.dart`
- `apps/mobile/lib/presentation/widgets/download_state_badge.dart`
- `apps/mobile/lib/presentation/widgets/favorite_button.dart`
- `apps/mobile/lib/presentation/widgets/recent_course_tile.dart`
- `apps/mobile/lib/presentation/widgets/empty_search_state.dart`

**Tests:**
- `apps/mobile/test/presentation/widgets/course_card_test.dart`
- `apps/mobile/test/presentation/widgets/verification_badge_test.dart`
- `apps/mobile/test/presentation/bloc/course_search_bloc_test.dart`

---

## Decision Log

| Decision | Rationale |
|---|---|
| FavoriteCourse + RecentCourse as new JPA entities | User-scoped course associations require persistence; Epic-02 user entity is available |
| `hasPackage` computed from DataVersionRepository | Avoids coupling to package generation pipeline (3-3 scope); boolean flag is sufficient for search results |
| `updateAvailable` computed server-side | Mobile passes `downloadedVersion` param; server compares against latest version — keeps intelligence on backend |
| `downloadedVersion` as optional request param | Backward compatible; mobile can omit for simple searches |
| RecentCourse trimmed to 10 per user | UX convention; prevents unbounded growth; enforced at repository layer |
| Separate `CourseSearchController` + `UserCourseController` | Separates public course search from user-scoped operations; matches API group structure |
| Text search via JPQL (not native) | Facility name/address search doesn't require PostGIS; JPQL sufficient and portable |
| Nearby search via native PostGIS ST_DWithin | Requires PostGIS spatial functions; GIST index already exists on `golf_facilities.location` |
| Search results include facility-level + course-level data | UX needs facility name/address for display; course entity provides geometry for distance |
| Max search radius 50km enforced at service layer | Prevents accidentally expensive ST_DWithin scans; architecture recommends reasonable limits |

---

## Constraints Respecting Existing Architecture

- Repository interfaces in `module/course/repository/`
- Service impls in `module/course/` + `module/course/impl/`
- DTOs in `module/course/dto/`
- Controllers in `api/course/`
- OpenAPI contracts in `packages/contracts/`
- Flyway migrations follow `V{N}__*.sql` convention (next available: V19__)
- Mobile follows existing `apps/mobile/lib/` structure
- No changes to Epic-01 or Epic-02 module code
- Spatial operations go through `GeospatialService` interface only
- Audit on write operations (favorites add/remove, recent view record)

---

## Story Status After Planning

`ready-for-dev` → `planned`

**Plan file**: `docs/vnpt-flow/epic-run-epic-03/3-2-plan.md`

**Next action**: `vnpt-dev-epic-orchestrator` dispatches implementer for slice SD-BACK-1.

---

## Open Issues for Implementer

1. **Flutter SDK gap**: Mobile slices SD-MOB-1 and SD-MOB-2 cannot have Flutter gates run until Flutter SDK is installed (same as Epic-02 mobile stories). Code review verification will be applied as fallback.
2. **Epic-02 GolfBag gap**: Some repository tests failed in 3-1 due to missing `GolfBag` entity from Epic-02. This may affect Spring context loading for new repository tests — implementer should use `@WebMvcTest` or mock-based tests to avoid context loading issues where possible.
3. **Search ranking**: Text search relevance ranking is basic (LIKE '%q%'). More sophisticated ranking (PostgreSQL full-text search, ts_rank) can be added in a later iteration if needed.
4. **Accent-insensitive search**: Full accent-insensitive search on Vietnamese text requires `unaccent` extension or application-level normalization. Basic case-insensitive JPQL is implemented first.
