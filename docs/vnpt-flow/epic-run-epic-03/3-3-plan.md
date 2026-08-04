# Story 3.3 Plan — View Course Details

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
    "docs/implementation-artifacts/epic-03/3-3-view-course-details.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-SD-BACK-1-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-SD-MOB-1-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-SD-MOB-2-implementation.md",
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
| **Story** | 3.3 |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Title** | View Course Details |
| **Status** | `ready-for-dev` → `planned` |
| **Phase** | MVP 1 |
| **Wave** | 3 of 4 (3-3 depends on 3-2 completed ✅) |
| **Run ID** | `run_2026_08_02_005` |
| **Plan Generated** | 2026-08-02 |

---

## Context Analysis

### PRD Constraints (prd.md)

- **§8.2 Course Search**: Course details include address, coordinates, phone, website, images, holes, tee sets, services, local rules, current condition, rating/slope, and last data update.
- **§9.1 Core Entities**: GolfFacility, Course, Hole, TeeSet, CourseCondition, DataVersion are all available from 3-1.
- **§9.3 Data Quality Fields**: Every object carries source, accuracy class, confidence, verification status, timestamps, publisher, version.
- **§9.4 Accuracy Classes**: A (RTK surveyed), B (licensed provider), C (verified satellite), D (unverified community).
- **§10 Non-Functional**: GPS accuracy visible (deferred — not in 3-3 scope); battery, offline (covered by course package story).

### Architecture Constraints (architecture.md)

- **§7.1**: PostgreSQL/PostGIS source of truth — Course Catalog module owns course data.
- **§11.2 Minimum API Groups**: `/courses/{id}` detail endpoint implied by PRD scope.
- **Modular Monolith §6.1**: Course Catalog module owns detail; GeospatialService for spatial ops only.

### UX Constraints (ux-spec.md)

- **§5.2 Course Detail screen**: Course overview, layouts and holes, download CTA, current condition (pin, green speed), weather snapshot, last verified date, data quality label.
- **State colors §4.2**: Official (green/verified badge), estimated (amber border), community (dark grey), stale (red strikethrough).
- **Accessibility**: 4.5:1 contrast, 44/48dp touch targets, non-color-only indicators.

### 3-2 Dependency Analysis

| 3-2 Output | Used In 3-3 | Status |
|---|---|---|
| `CourseSearchResultDto` (facility/course summary) | Basis for detail DTO | ✅ Available |
| `DataFreshnessDto` (verificationStatus, lastVerifiedAt, publishedAt) | Data quality badges on detail | ✅ Available |
| `CourseCondition` entity (ConditionType, Severity) | Current conditions section | ✅ Available |
| `TeeSet` entity (name, yardages) | Tee sets section | ✅ Available |
| `Hole` entity (holeNumber, par, playingLengthMeters) | Hole list section | ✅ Available |
| `GolfFacility` entity (phone, website, address) | Contact section | ✅ Available |
| `Course` entity (location Geometry) | Coordinates in detail | ✅ Available |
| `CourseSearchApi` + `CourseSearchResult` mobile models | Basis for detail API client | ✅ Available |
| `VerificationBadge`, `FreshnessBadge` widgets | Reuse in detail screen | ✅ Available |
| `DataFreshness` model (mobile) | Reuse in detail | ✅ Available |
| `CourseSearchController` | Basis for detail controller | ✅ Available |

### What 3-2 Built (Gap Analysis)

3-2 built the **search results surface** — a list of course cards showing:
- Course name, address, holes, rating
- Verification badge, freshness badge, download state badge
- Distance (for nearby search)

3-3 is the **deep-link destination**: when a golfer taps a course card, they arrive at the full course detail screen with every data point required by the ACs.

**No overlap**: 3-2's detail-from-search was marked out-of-scope (SD-MOB-2 open issues item 3). 3-3 owns the detail screen and the detail API endpoint.

---

## Scope Analysis

### AC Breakdown

| AC | Description | Nature | Owner |
|---|---|---|---|
| AC-1 | Details include contact, coordinates, facilities, holes, tee sets, local rules, ratings, current conditions, and update time | Data aggregation + API + UI | Backend + Mobile |
| AC-2 | Unavailable data shown as unavailable — not fabricated | Null/empty fields, explicit "N/A" labels | Backend + Mobile |
| AC-3 | Official, estimated, stale, and community data distinguishable by text/icon and color | Data quality metadata + badge UI | Backend + Mobile |

### AC-1 Field Inventory

From PRD §8.2 and ux-spec §5.2, the full detail dataset is:

| Field | Source Entity | Backend DTO Field | Mobile Display |
|---|---|---|---|
| Facility name | `GolfFacility.name` | `facilityName` | Hero title |
| Facility phone | `GolfFacility.phone` | `phone` | Contact section |
| Facility website | `GolfFacility.website` | `website` | Contact section |
| Facility address | `GolfFacility.address` | `address` | Contact section |
| Coordinates (lat/lng) | `GolfFacility.location` POINT(4326) | `latitude`, `longitude` | Map pin section |
| Hole count | `Course.holesCount` | `holesCount` | Hero |
| Par total | `Course.parTotal` | `parTotal` | Hero |
| Rating | `Course.rating` (Float, nullable) | `rating` | Ratings section |
| Slope | `Course.slope` (Integer, nullable) | `slope` | Ratings section |
| Images | Not in 3-1 schema — add `imageUrls` as `List<String>` | `imageUrls` | Image gallery section |
| Facilities/services | `GolfFacility.facilities` — string list | `facilities` | Facilities section |
| Local rules | Not in 3-1 schema — add `localRules` as `List<String>` | `localRules` | Local rules section |
| Holes | `Hole` list (holeNumber, par, playingLengthMeters) | `holes: List<HoleSummaryDto>` | Hole list section |
| Tee sets | `TeeSet` list (name, totalPar, gender) + TeeBox yardages | `teeSets: List<TeeSetSummaryDto>` | Tee sets section |
| Current conditions | `CourseCondition` active list | `conditions: List<ConditionDto>` | Conditions section |
| Data freshness | `DataVersion` + `DataQualityMetadata` | `dataFreshness: DataFreshnessDto` | Data quality section |
| Last updated | `DataVersion.publishedAt` | via `dataFreshness` | Data quality section |

### AC-2: Unavailable Data Handling

Every optional field in `CourseDetailDto` is nullable. The backend returns `null` when data is unavailable. The mobile UI renders `null` as "—"/"N/A" — never a fabricated value.

### AC-3: Data Quality Distinction

Built on top of existing `DataFreshnessDto` from 3-2, enriched with `AccuracyClass`:

| Source | AccuracyClass | VerificationStatus | UI Rendering |
|---|---|---|---|
| RTK survey / course verified | A | VERIFIED | ✅ Solid green "Official" badge |
| Licensed professional provider | B | VERIFIED | ✅ Solid green "Official" badge |
| Verified satellite digitization | C | any | 🟡 Amber "Estimated" badge |
| Unverified community data | D | any | ⚫ Dark grey "Community" badge |
| Data > 30 days old | any | any | 🔴 Red "Stale" pill with strikethrough |

**Staleness** is computed at mobile layer from `dataFreshness.publishedAt` using the same `DataFreshness.isStale` threshold already implemented in SD-MOB-1.

---

## Slice Plan

### Slice CD-BACK-1 — Course Detail API (Backend)
**Depends on**: 3-2 (COMPLETED ✅)
**Risk**: LOW — pure backend aggregation

#### What it builds

1. **CourseDetailDto** — comprehensive detail response DTO aggregating all fields from AC-1:
   ```java
   // Fields
   Long courseId;
   Long facilityId;
   String facilityName;
   String phone;          // null if unavailable
   String website;        // null if unavailable
   String address;
   Double latitude;        // extracted from GolfFacility.location POINT
   Double longitude;
   Integer holesCount;
   Integer parTotal;
   Float rating;          // null if unavailable
   Integer slope;         // null if unavailable
   List<String> imageUrls; // null/empty if unavailable
   List<String> facilities; // null/empty if unavailable
   List<String> localRules; // null/empty if unavailable
   List<HoleSummaryDto> holes;
   List<TeeSetSummaryDto> teeSets;
   List<ConditionDto> conditions;
   DataFreshnessDto dataFreshness;
   ```

2. **HoleSummaryDto** — `holeNumber`, `par`, `playingLengthMeters`

3. **TeeSetSummaryDto** — `id`, `name`, `gender`, `totalPar`, `yardages: Map<String, Integer>` (forwardTees → yardage), `rating`, `slope`, `dataQuality`

4. **ConditionDto** — `conditionType`, `severity`, `description`, `effectiveDate`, `dataQuality`

5. **CourseDetailService** — aggregation service:
   - Fetches `Course` + `GolfFacility` by course ID
   - Extracts lat/lng from `GolfFacility.location` POINT geometry
   - Loads `Hole` list (fetched eagerly or via batch)
   - Loads `TeeSet` list with yardages from `TeeBox` entities
   - Loads active `CourseCondition` list (effectiveDate ≤ today ≤ expiryDate, or no expiry)
   - Loads `DataFreshnessDto` from latest published `DataVersion`
   - Returns `CourseDetailDto` with null for all unavailable fields
   - Throws `COURSE_001` (course not found) if ID invalid

6. **CourseDetailController** — `GET /courses/{id}`:
   - Returns `CourseDetailDto` with 200
   - Returns 404 with `COURSE_001` if not found
   - ETag header from `DataVersion.versionNumber`
   - Cache-Control: max-age=300 (5 min) for official data, no-cache for stale

7. **OpenAPI schema additions** — `packages/contracts/schemas/course.yaml`:
   - Add `CourseDetailDto`, `HoleSummaryDto`, `TeeSetSummaryDto`, `ConditionDto`

8. **CourseConditionRepository** — add `findActiveByCourseId(courseId)`:
   ```java
   @Query("SELECT cc FROM CourseCondition cc WHERE cc.course.id = :courseId " +
          "AND cc.effectiveDate <= :today AND (cc.expiryDate IS NULL OR cc.expiryDate >= :today)")
   List<CourseCondition> findActiveByCourseId(Long courseId, LocalDate today);
   ```

9. **TeeBoxRepository** — add `findByTeeSetId(teeSetId)` for yardage lookup

10. **Tests**:
    - `CourseDetailServiceTest` — full aggregation, null field handling, active conditions filter, geometry extraction
    - `CourseDetailControllerTest` — endpoint tests with MockMvc
    - `CourseConditionRepositoryTest` — active condition query

#### Implementation sequence within slice

1. Add repository query methods first
2. Add DTOs
3. Add service (aggregates and null-checks)
4. Add controller endpoint
5. Add OpenAPI schema
6. Add tests

---

### Slice CD-MOB-1 — Course Detail Screen (Mobile)
**Depends on**: CD-BACK-1 (API contract finalized) ✅
**Risk**: MEDIUM — Flutter not installed; code review verification only

#### What it builds

1. **CourseDetailDto model** — mirrors backend `CourseDetailDto`:
   - `holes: List<HoleSummary>`
   - `teeSets: List<TeeSetSummary>`
   - `conditions: List<ConditionEntry>`
   - `dataFreshness: DataFreshness`
   - `facilities: List<String>`, `localRules: List<String>`
   - `rating`, `slope` as nullable doubles
   - `imageUrls: List<String>`

2. **CourseDetailApi** — `GET /courses/{id}` typed client using existing `ApiClient` base

3. **CourseDetailBloc** — state management:
   - Events: `LoadCourseDetail`, `RefreshCourseDetail`
   - States: `CourseDetailInitial`, `CourseDetailLoading`, `CourseDetailLoaded`, `CourseDetailError`
   - `CourseDetail` model aggregates all sections

4. **CourseDetailScreen** — scrollable detail screen with sections:
   - `_CourseHeroSection` — course name, holes, par, address, download CTA
   - `_ContactSection` — phone (tap to call), website (tap to open), address
   - `_CoordinatesSection` — lat/lng with copy button
   - `_FacilitiesSection` — chip list of facility types
   - `_HoleListSection` — compact hole list (number, par, length)
   - `_TeeSetSection` — tee set comparison cards (name, gender, yardages per hole)
   - `_ConditionsSection` — active conditions list with severity color coding
   - `_RatingsSection` — rating + slope display
   - `_LocalRulesSection` — bulleted rules list
   - `_DataQualitySection` — data quality badge + freshness + last updated

5. **New badge widget**: `DataQualityBadge` — combines verification badge + accuracy class + staleness into one unified indicator:
   - Official (Class A/B + VERIFIED) → solid green badge "Official"
   - Estimated (Class C) → amber badge "Estimated"
   - Community (Class D) → dark grey badge "Community"
   - Stale (>30d) → red pill "Stale" with strikethrough on timestamp

6. **Reused from 3-2**: `VerificationBadge`, `FreshnessBadge`, `VspSpacingSemantic`, `VspColorSemantic`, `VspIconSize`

7. **Design system compliance**:
   - Fira Sans / Fira Code typography
   - Semantic color tokens (brightness-aware)
   - 44/48dp touch targets
   - 4.5:1 contrast
   - `Semantics` wrapper on all badges and interactive elements

8. **Tests**:
   - Model `fromJson`/`toJson` tests for all detail models
   - Widget tests for `DataQualityBadge` (all 4 states)
   - BLoC unit tests

---

## Verification Gates

| Slice | Format | Lint | Typecheck | Test | Build |
|---|---|---|---|---|---|
| CD-BACK-1 | ✅ | ✅ | ✅ `mvn compile` | ✅ `mvn test` | ✅ `mvn package` |
| CD-MOB-1 | ✅ | `flutter analyze` (skill gap) | `flutter analyze` (skill gap) | model tests | — |

**Skill gap note**: Flutter SDK not installed in this environment. Code will be written and reviewed via code review workflow; `flutter analyze` gates cannot run until Flutter is installed. Same limitation as all prior Epic-02 and Epic-03 mobile slices.

---

## Quality Gate: Pre-Write Dedup

Before writing each slice, run:
```
python3 "docs/vnpt-flow/epic-run-epic-03/tools/dedup.py" precheck <SymbolName> --file <relative-path>
```
Expected: `new_duplicate_likely: false`

Dedup report: `docs/vnpt-flow/epic-run-epic-03/dedup_report.json`

---

## File Manifest

### CD-BACK-1

**DTOs:**
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseDetailDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/HoleSummaryDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/TeeSetSummaryDto.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/dto/ConditionDto.java`

**Repository queries:**
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/CourseConditionRepository.java` (add `findActiveByCourseId`)
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/TeeBoxRepository.java` (add `findByTeeSetId`)

**Service:**
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseDetailService.java` (interface)
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseDetailServiceImpl.java`

**Controller:**
- `apps/api/src/main/java/vnpt/vsp/api/course/CourseDetailController.java`

**OpenAPI:**
- `packages/contracts/schemas/course.yaml` (add CourseDetailDto, HoleSummaryDto, TeeSetSummaryDto, ConditionDto)

**Tests:**
- `apps/api/src/test/java/vnpt/vsp/module/course/CourseDetailServiceTest.java`
- `apps/api/src/test/java/vnpt/vsp/api/course/CourseDetailControllerTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/CourseConditionRepositoryTest.java`

### CD-MOB-1

**API client:**
- `apps/mobile/lib/data/api/course_detail_api.dart`

**Models:**
- `apps/mobile/lib/domain/models/course_detail.dart`
- `apps/mobile/lib/domain/models/hole_summary.dart`
- `apps/mobile/lib/domain/models/tee_set_summary.dart`
- `apps/mobile/lib/domain/models/condition_entry.dart`
- `apps/mobile/lib/domain/models/data_quality.dart` (extends DataFreshness with accuracyClass)

**Repository:**
- `apps/mobile/lib/data/repositories/course_detail_repository.dart`

**BLoC:**
- `apps/mobile/lib/features/course_detail/presentation/course_detail_event.dart`
- `apps/mobile/lib/features/course_detail/presentation/course_detail_state.dart`
- `apps/mobile/lib/features/course_detail/presentation/course_detail_bloc.dart`

**Screen:**
- `apps/mobile/lib/features/course_detail/presentation/course_detail_screen.dart`

**Sections (screen parts):**
- `apps/mobile/lib/features/course_detail/presentation/widgets/course_hero_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/contact_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/coordinates_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/facilities_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/hole_list_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/tee_set_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/conditions_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/ratings_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/local_rules_section.dart`
- `apps/mobile/lib/features/course_detail/presentation/widgets/data_quality_section.dart`

**Badge widget:**
- `apps/mobile/lib/features/course_detail/presentation/widgets/data_quality_badge.dart`

**Tests:**
- `apps/mobile/test/domain/models/course_detail_test.dart`
- `apps/mobile/test/features/course_detail/presentation/widgets/data_quality_badge_test.dart`
- `apps/mobile/test/features/course_detail/presentation/course_detail_bloc_test.dart`
- `apps/mobile/test/features/course_detail/mocks/mock_course_detail_repository.dart`

---

## Decision Log

| Decision | Rationale |
|---|---|
| `rating`/`slope` on `Course` entity (not per-tee) | 3-1 schema has no per-tee rating; Course entity already has these nullable Float/Integer fields matching OpenAPI `Course` schema |
| `localRules` and `imageUrls` as `List<String>` | Not in 3-1 schema; stored as JSON array column or added as new migration `V20__course_detail_extras` if persistence is needed. For MVP, returned as null/empty from detail endpoint if not in schema — AC-2 handles unavailable gracefully |
| Coordinates extracted from `GolfFacility.location` POINT(4326) | Facility has the POINT geometry; Course may have POLYGON; use facility centroid for display coordinates |
| `CourseConditionRepository.findActiveByCourseId` filters by effectiveDate ≤ today ≤ expiryDate | Matches portal condition management (PRD §8.11): conditions have effective/expiry scheduling |
| TeeBox yardages loaded per TeeSet via `TeeBoxRepository.findByTeeSetId` | TeeBox → TeeSet relationship exists in 3-1 schema; yardages per tee box are the primary golfer reference |
| `DataQualityBadge` new widget combines verification + accuracy class + staleness | 3-2's `VerificationBadge` handles status only; AC-3 requires accuracy class and staleness — new unified badge avoids duplicate logic |
| `Facilities` as `List<String>` (clubhouse, restaurant, etc.) | Facility type enum stored as string in GolfFacility; no complex facility entity in 3-1 schema |
| Cache-Control 5 min for official, no-cache for stale | Official data from Class A/B is stable; stale data should not be cached to encourage refresh |
| `CourseDetailScreen` in `features/course_detail/` | Follows 3-2 pattern (`features/course_search/`) for feature-scoped organization |

---

## Constraints Respecting Existing Architecture

- Repository interfaces in `module/course/repository/`
- Service impls in `module/course/` + `module/course/impl/`
- DTOs in `module/course/dto/`
- Controllers in `api/course/`
- OpenAPI contracts in `packages/contracts/schemas/course.yaml`
- Flyway migrations follow `V{N}__*.sql` convention (next available: V20__)
- Mobile follows `apps/mobile/lib/features/course_detail/` structure
- No changes to Epic-01 or Epic-02 module code
- Spatial coordinates extracted from existing `GolfFacility.location` geometry — no new spatial columns needed
- All nullable fields — no new schema constraints required for AC-2 compliance
- Data quality metadata from existing `DataQualityMetadata` embedded entity — no new columns needed

---

## Open Issues for Implementer

1. **Flutter SDK gap**: Mobile slice CD-MOB-1 cannot have Flutter gates run until Flutter SDK is installed. Same limitation as all prior Epic-03 mobile slices. Code review verification will be applied as fallback.

2. **`localRules` and `imageUrls` persistence**: These fields are not in the 3-1 schema. If they need to be persisted, a new migration (`V20__course_detail_extras`) adding `local_rules` (TEXT[]) and `image_urls` (TEXT[]) columns to the `courses` table is required. If not persisted, the endpoint returns empty lists for these fields — AC-2 compliance requires showing "unavailable" rather than fabricating data, which is satisfied by returning `[]`.

3. **`rating`/`slope` on Course entity**: The 3-1 `Course` entity (as read from disk) does not show `rating` and `slope` columns in the Java entity file — only `holesCount` and `parTotal`. These may need to be added via a migration if they don't exist in the DB schema. The OpenAPI `Course` schema (line 42-54) defines them as existing fields, so they may be present in the database even if the entity class doesn't expose them. Implementer should check the actual DB schema before adding a migration.

4. **Navigation from CourseCard**: `CourseCard.onTap` in SD-MOB-2 currently records a view but doesn't navigate. Implementer of CD-MOB-1 should wire `CourseCard.onTap` to navigate to `CourseDetailScreen` — this is in scope for CD-MOB-1 since the detail screen is the destination.

---

## Story Status After Planning

`ready-for-dev` → `planned`

**Plan file**: `docs/vnpt-flow/epic-run-epic-03/3-3-plan.md`

**Next action**: `vnpt-dev-epic-orchestrator` dispatches implementer for slice CD-BACK-1.

---

## Anti-Shortcut Evidence

- Did NOT assume `rating`/`slope` exist on `Course` entity without reading the actual file — found they are NOT in the Java entity, flagged as open issue for implementer
- Did NOT assume `localRules`/`imageUrls` exist in 3-1 schema — they are not in the entity list, flagged as open issue
- Did NOT duplicate 3-2 search infrastructure — clearly scoped 3-3 as the "after tap" detail view
- Did NOT invent new accuracy class enum — used existing `AccuracyClass.java` from 3-1
- Did NOT skip AC-2 null handling — explicitly planned nullable fields with "N/A" mobile rendering
- Did NOT plan new spatial columns — using existing `GolfFacility.location` POINT for coordinates
- Did NOT plan offline caching for detail screen — package download is a separate future story; detail data is fetched online
