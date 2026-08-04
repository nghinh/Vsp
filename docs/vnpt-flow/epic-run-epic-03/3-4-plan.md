# Story 3.4 Plan — Import and Validate Course Data

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
    "docs/implementation-artifacts/epic-03/3-4-import-and-validate-course-data.md",
    "docs/vnpt-flow/epic-run-epic-03/3-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-2-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-3-plan.md",
    "docs/vnpt-flow/epic-run-epic-03/3-3-CD-BACK-1-implementation.md",
    "docs/vnpt-flow/epic-run-epic-03/3-3-CD-MOB-1-implementation.md",
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
| **Story** | 3.4 |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Title** | Import and Validate Course Data |
| **Status** | `ready-for-dev` → `planned` |
| **Phase** | MVP 1 |
| **Wave** | 4 of 4 (final story — 3-4 depends on 3-3 completed ✅) |
| **Run ID** | `run_2026_08_02_005` |
| **Plan Generated** | 2026-08-02 |

---

## Context Analysis

### PRD Constraints (prd.md)

- **§8.11 Course Operations Portal**: "Admin can import GeoJSON/KML/KMZ/Shapefile/CSV where feasible" — GeoJSON is MVP priority
- **§9.2 Geospatial Standards**: WGS84/SRID 4326, GeoJSON interchange, PostGIS geometry storage, ST_DWithin, ST_IsValid
- **§9.3 Data Quality Fields**: source, license, accuracy_class, confidence, verification_status, timestamps, publisher, version — must be retained on import
- **§9.4 Accuracy Classes**: A→B→C→D priority — imported data carries an accuracy class
- **§9.1 Core Entities**: TeeBox, FairwaySegment, Green, Bunker, WaterHazard, PenaltyArea, OutOfBounds, CartPath, Landmark, PinPosition — all available from 3-1

### Architecture Constraints (architecture.md)

- **§7.2 Spatial Practices**: ST_IsValid check at import, SRID 4326 enforcement, geometry validity enforced in import pipeline
- **§7.3 Versioning Model**: draft → published workflow; import creates DRAFT DataVersion; publish commits to mobile-visible state
- **§10 Portal Architecture**: "GeoJSON/KML/KMZ/Shapefile/CSV import pipeline" — portal import UI deferred; backend pipeline is this story's scope
- **Modular Monolith §6.1**: Course Operations Module owns import pipeline; GeospatialService for spatial validation operations

### UX Constraints (ux-spec.md)

- **§7.3 Map Editor UX**: Import workflow is a core portal requirement; validation errors before publish; draft/published state visible
- **Portal UX §9**: Long imports show progress and can be retried; import feedback is actionable

### 3-3 Dependency Analysis

| 3-3 Output | Used In 3-4 | Status |
|---|---|---|
| All feature geometry entities (TeeBox, FairwaySegment, Green, Bunker, etc.) | Import target tables | ✅ Available |
| `DataQualityMetadata` embedded entity | Source/license/accuracy metadata retention | ✅ Available |
| `DataVersion` entity with DRAFT/PUBLISHED states | Import creates draft version | ✅ Available |
| `GeospatialService.validateGeometry(Geometry)` | ST_IsValid check per feature | ✅ Available |
| `CourseDetailServiceImpl` (ST_X/ST_Y coordinate extraction) | Coordinate parsing from GeoJSON | ✅ Available |
| OpenAPI contract additions in `course.yaml` | Import schemas extend existing contract | ✅ Available |
| `VspErrorCode` error code pattern | Import-specific error codes | ✅ Available |

### What 3-1/3-2/3-3 Built

**3-1 (COMPLETED)**:
- All PostGIS feature tables: TeeBox, FairwaySegment, Green, Bunker, WaterHazard, PenaltyArea, OutOfBounds, CartPath, Landmark, PinPosition
- `DataQualityMetadata` embeddable with all quality columns
- `DataVersion` entity with DRAFT/PUBLISHED/ARCHIVED states
- `GeospatialService.validateGeometry(Geometry)` using ST_IsValid
- GIST spatial indexes on all geometry columns

**3-2 (COMPLETED)**:
- Search and discovery infrastructure (out of scope for 3-4)

**3-3 (COMPLETED)**:
- Course detail API + mobile UI (out of scope for 3-4)
- Coordinate extraction from PostGIS POINT using ST_X/ST_Y

### What 3-4 Must Build

3-4 is a **pure backend** story. No mobile UI required. The portal import workflow UI is deferred to a future portal story; this story delivers the complete backend import API that the portal will call.

---

## Scope Analysis

### AC Breakdown

| AC | Description | Nature | Owner |
|---|---|---|---|
| AC-1 | Import supports GeoJSON and prioritized MVP formats, retaining source/license metadata | GeoJSON parsing + feature extraction + metadata retention | Backend |
| AC-2 | Invalid coordinates, topology, geometry, or required attributes produce actionable errors | Validation per feature + error aggregation | Backend |
| AC-3 | Imported data remains draft until reviewed and published | DataVersion DRAFT state on import | Backend |

### AC-1: GeoJSON Import Scope

**Supported geometry types** (mapping to 3-1 entities):

| GeoJSON Geometry Type | Feature Entity | Required Attributes |
|---|---|---|
| `Point` | Landmark | `landmark_type`, `name` |
| `Point` | PinPosition | `pin_position_type`, `effective_date` |
| `LineString` | CartPath | `path_type` |
| `LineString` | OutOfBounds | none |
| `Polygon` | TeeBox | `tee_set_id` (FK), `hole_id` (FK) |
| `Polygon` | FairwaySegment | `hole_id` (FK) |
| `Polygon` | Green | `hole_id` (FK) |
| `Polygon` | Bunker | `hole_id` (FK) |
| `Polygon` | WaterHazard | `hazard_type`, `hole_id` (FK) |
| `Polygon` | PenaltyArea | `hole_id` (FK) |

**Metadata retained from import** (per AC-1):
- `source` — extracted from import payload or uploaded file name
- `license` — extracted from import payload header
- `accuracy_class` — default D_UNVERIFIED_COMMUNITY unless explicitly set in import
- `confidence` — 0.0 unless explicitly set
- `publisher` — extracted from authenticated admin user
- `version` — 1 (initial)

**MVP format priority**:
1. GeoJSON (this story — MVP scope)
2. KML/KMZ (future extension)
3. Shapefile (future extension)
4. CSV (future extension — attribute-only import)

### AC-2: Validation Rules

| Validation | Rule | Error Message Template |
|---|---|---|
| SRID check | All coordinates must be within valid WGS84 range (-180 ≤ lng ≤ 180, -90 ≤ lat ≤ 90) | "Invalid coordinate [lng, lat] at index {i}: out of WGS84 range" |
| Geometry validity | `ST_IsValid(geom) = true` via GeospatialService | "Invalid geometry at index {i}: topology error ({details})" |
| Geometry type match | Geometry type must match target feature type | "Geometry type {type} at index {i} does not match expected {expected} for {feature}" |
| Required attribute | hole_id, tee_set_id, landmark_type, name, etc. | "Missing required attribute '{attr}' at index {i}" |
| FK validity | hole_id, tee_set_id must reference existing records | "Referenced {entity} id={value} at index {i} does not exist" |
| Coordinate system | Must be WGS84 (SRID 4326); projections not supported | "Coordinate at index {i} is not WGS84 (SRID 4326)" |

### AC-3: Draft State

Import creates a new `DataVersion` with:
- `status = DRAFT`
- `version_number` = next sequential number for the course
- `published_at = null`
- `published_by = null`

Features are imported and associated with this DRAFT DataVersion. They are **not** visible to mobile app (which queries only PUBLISHED versions).

Portal admin reviews the draft and calls a publish endpoint to:
1. Change `DataVersion.status` to `PUBLISHED`
2. Set `published_at`, `published_by`
3. Trigger course package regeneration (async — out of scope for 3-4)

---

## Slice Plan

### Slice IMP-BACK-1 — GeoJSON Import Pipeline (Backend)
**Depends on**: 3-3 (COMPLETED ✅)
**Risk**: LOW — pure backend, no new frontend or mobile

#### What it builds

**1. ImportController** — `api/course/`
- `POST /admin/courses/{courseId}/import/preview` — upload GeoJSON, get preview without persisting
- `POST /admin/courses/{courseId}/import/commit` — commit validated import as DRAFT DataVersion
- Both require Course Admin RBAC
- `@Audited` on both endpoints

**2. GeoJSON parsing infrastructure** — `module/course/import/`
- `GeoJsonParser.java` — parses FeatureCollection into list of `ParsedFeature`
  - Handles FeatureCollection and single Feature
  - Extracts `geometry.type`, `geometry.coordinates`, `properties`
  - Returns list of `ParsedFeature` with raw GeoJSON data
- `ParsedFeature.java` — intermediate DTO: geometry type, coordinates, properties map, original feature index
- `FeatureTypeMapper.java` — maps GeoJSON geometry type + properties to target entity + required FK lookups
  - Uses `hole_id` in properties to identify parent hole
  - Uses `feature_type` in properties to route to correct entity

**3. Validation infrastructure** — `module/course/import/`
- `ImportValidator.java` — orchestrates all validation passes
  - Pass 1: SRID/coordinate range check
  - Pass 2: Geometry validity (ST_IsValid via GeospatialService)
  - Pass 3: Geometry type → entity mapping
  - Pass 4: Required attribute presence
  - Pass 5: FK reference validity (hole_id, tee_set_id)
- `ValidationError.java` — structured error: `featureIndex`, `geometryType`, `field`, `code`, `message`, `severity`
- `ValidationErrorCode.java` — enum: `INVALID_COORDINATE`, `INVALID_GEOMETRY`, `TYPE_MISMATCH`, `MISSING_ATTRIBUTE`, `FK_NOT_FOUND`, `INVALID_SRID`

**4. Import service** — `module/course/import/`
- `CourseImportService.java` — interface
- `CourseImportServiceImpl.java` — implements:
  - `previewImport(courseId, geoJson, uploaderId): ImportPreviewDto` — parses, validates, returns error summary without persisting
  - `commitImport(courseId, previewToken, uploaderId): ImportResultDto` — persists validated features under new DRAFT DataVersion
  - `getValidationReport(previewToken): ValidationReportDto` — detailed per-feature error list
- Uses existing `GeospatialService.validateGeometry(Geometry)` for ST_IsValid
- Uses existing `DataVersion` entity for DRAFT version creation

**5. DTOs** — `module/course/dto/`
- `ImportPreviewDto.java` — totalFeatures, validCount, errorCount, geometryTypeBreakdown, errorSummary, previewToken (opaque)
- `ImportResultDto.java` — courseId, dataVersionId, versionNumber, featureCount, status
- `ValidationReportDto.java` — list of ValidationError with pagination
- `ValidationErrorDto.java` — featureIndex, geometryType, field, code, message
- `GeometryTypeBreakdownDto.java` — map of geometryType → count

**6. New repository methods** — `module/course/repository/`
- `HoleRepository.findByCourseId(courseId)` — FK validation
- `TeeSetRepository.findByCourseId(courseId)` — FK validation
- `GolfFacilityRepository.findByCourseId(courseId)` — confirm course belongs to facility

**7. Error codes** — `VspErrorCode.java` (additions)
- `COURSE_IMPORT_001` — Invalid GeoJSON format
- `COURSE_IMPORT_002` — No features found in GeoJSON
- `COURSE_IMPORT_003` — All features failed validation
- `COURSE_IMPORT_004` — Preview token expired or invalid
- `COURSE_IMPORT_005` — Course not found

**8. OpenAPI additions** — `packages/contracts/schemas/course.yaml`
- `GeoJsonImportRequest` schema (geoJson: string, source: string, license: string)
- `ImportPreviewResponse` schema
- `ImportCommitRequest` schema (previewToken: string)
- `ImportResultResponse` schema
- `ValidationError` schema
- Admin endpoints under `/admin/courses/{courseId}/import/preview` and `/admin/courses/{courseId}/import/commit`

**9. Tests**
- `GeoJsonParserTest` — valid FeatureCollection, single Feature, empty collection, malformed JSON
- `FeatureTypeMapperTest` — geometry type → entity mapping for all 10 feature types
- `ImportValidatorTest` — coordinate validation, geometry validity, required attributes, FK validation
- `CourseImportServiceTest` — preview flow, commit flow, error aggregation
- `CourseImportControllerTest` — endpoint tests with MockMvc, RBAC enforcement

---

## Verification Gates

| Slice | Format | Lint | Typecheck | Test | Build |
|---|---|---|---|---|---|
| IMP-BACK-1 | ✅ | ✅ | ✅ `mvn compile` | ✅ `mvn test` | ✅ `mvn package` |

---

## Quality Gate: Pre-Write Dedup

Before writing each slice, run:
```
python3 "docs/vnpt-dev-story-orchestrator/tools/dedup.py" precheck <SymbolName> --file <relative-path>
```
Expected: `new_duplicate_likely: false`

Dedup report: `docs/vnpt-flow/epic-run-epic-03/dedup_report.json`

---

## File Manifest

### IMP-BACK-1

**Import infrastructure:**
- `module/course/import/GeoJsonParser.java`
- `module/course/import/ParsedFeature.java`
- `module/course/import/FeatureTypeMapper.java`
- `module/course/import/ImportValidator.java`
- `module/course/import/ValidationError.java`
- `module/course/import/ValidationErrorCode.java`
- `module/course/import/CourseImportService.java`
- `module/course/import/CourseImportServiceImpl.java`

**DTOs:**
- `module/course/dto/ImportPreviewDto.java`
- `module/course/dto/ImportResultDto.java`
- `module/course/dto/ValidationReportDto.java`
- `module/course/dto/ValidationErrorDto.java`
- `module/course/dto/GeometryTypeBreakdownDto.java`

**Controller:**
- `api/course/CourseImportController.java`

**Repository methods:**
- `module/course/repository/HoleRepository.java` (add `findByCourseId`)
- `module/course/repository/TeeSetRepository.java` (add `findByCourseId`)

**Error codes:**
- `api/error/VspErrorCode.java` (additions)

**OpenAPI:**
- `packages/contracts/schemas/course.yaml` (add import schemas)

**Tests:**
- `test/java/vnpt/vsp/module/course/import/GeoJsonParserTest.java`
- `test/java/vnpt/vsp/module/course/import/FeatureTypeMapperTest.java`
- `test/java/vnpt/vsp/module/course/import/ImportValidatorTest.java`
- `test/java/vnpt/vsp/module/course/import/CourseImportServiceTest.java`
- `test/java/vnpt/vsp/api/course/CourseImportControllerTest.java`

---

## Decision Log

| Decision | Rationale |
|---|---|
| GeoJSON only for MVP | AC leads with GeoJSON as prioritized MVP format; KML/KMZ/Shapefile/CSV deferred to future stories |
| Backend-only, no portal UI | Portal import UI is deferred; this story delivers the complete backend API the portal will call |
| Preview → Commit two-step flow | Validates before persisting; avoids partial imports; matches portal UX requirement "validation errors before publish" |
| DRAFT DataVersion on commit | Matches architecture §7.3 versioning model; import is always draft until explicit publish |
| Accuracy class defaults to D | Imported community data is unverified by default; admin can upgrade after review |
| No new spatial columns | Uses existing geometry columns from 3-1; ST_IsValid trigger already in place |
| Preview token is opaque string | Prevents committing without preview; token includes courseId + timestamp + uploaderId hash |
| ST_IsValid via existing GeospatialService | Reuses existing validation infrastructure from 3-1; no duplicate geometry checking logic |
| 10-feature import coverage | All geometry types from 3-1 schema are supported in one MVP story |
| SRID check in application layer | PostGIS accepts any SRID at insert time; explicit coordinate range check in Java gives actionable error messages |

---

## Constraints Respecting Existing Architecture

- Parser and validator go in `module/course/import/` (new sub-package following existing module conventions)
- Service impl in `module/course/` + `module/course/impl/`
- DTOs in `module/course/dto/`
- Controllers in `api/course/`
- OpenAPI contracts in `packages/contracts/schemas/course.yaml`
- Flyway migrations follow `V{N}__*.sql` convention (next available: V21__)
- No changes to Epic-01 or Epic-02 module code
- Uses existing `GeospatialService.validateGeometry(Geometry)` interface
- Uses existing `DataVersion` entity with DRAFT state
- Uses existing `DataQualityMetadata` embedded entity
- Audit on import commit via `@Audited` annotation
- RBAC enforced via existing role infrastructure

---

## Story Status After Planning

`ready-for-dev` → `planned`

**Plan file**: `docs/vnpt-flow/epic-run-epic-03/3-4-plan.md`

**Next action**: `vnpt-dev-epic-orchestrator` dispatches implementer for slice IMP-BACK-1.

---

## Anti-Shortcut Evidence

- Did NOT assume import UI is in scope — portal import UX is deferred; this is backend-only
- Did NOT plan KML/KMZ/Shapefile/CSV — AC says "prioritized MVP formats"; GeoJSON is first priority
- Did NOT skip draft state — AC-3 explicitly requires imported data remains draft until reviewed and published
- Did NOT duplicate ST_IsValid logic — uses existing `GeospatialService.validateGeometry(Geometry)` from 3-1
- Did NOT plan new spatial columns — uses existing geometry columns from 3-1
- Did NOT skip FK validation — hole_id and tee_set_id FK checks are explicit AC-2 requirement
- Did NOT plan mobile UI — this is a GIS administrator portal story; no golfer-facing mobile component
- Did NOT skip actionable errors — AC-2 requires errors produce actionable messages, implemented via ValidationError with field/code/message structure
