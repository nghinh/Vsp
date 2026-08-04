# Story 3.4 Slice IMP-BACK-1 Implementation — GeoJSON Import Pipeline (Backend)

## Slice Metadata

| Field | Value |
|---|---|
| **Story** | 3.4 — Import and Validate Course Data |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Slice** | IMP-BACK-1 — Backend GeoJSON import pipeline |
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
    "docs/implementation-artifacts/epic-03/3-4-import-and-validate-course-data.md",
    "docs/vnpt-flow/epic-run-epic-03/3-4-plan.md"
  ],
  "mockup_sources_read": []
}
```

---

## Acceptance Criteria Coverage

| AC | Description | Covered By | Status |
|---|---|---|---|
| AC-1 | Preview returns validation report with feature-level errors and geometry type breakdown | `ImportPreviewDto` + `ValidationReportDto` + `CourseImportServiceImpl.previewImport()` | ✅ Done |
| AC-2 | Preview token valid for 30 minutes, stored in-memory | `PreviewTokenStore` (ConcurrentHashMap) with TTL logic in service | ✅ Done |
| AC-3 | Preview errors do NOT persist; commit errors DO persist | Service layer: rollback on validation failure during commit | ✅ Done |
| AC-4 | TeeBox mapped to correct hole via holeNumber + teeSetName | `FeatureTypeMapper.mapToTeeBox()` parses `holeNumber` + `teeSetName` from properties | ✅ Done |
| AC-5 | FairwaySegment built as polyline from ordered coordinates | `FeatureTypeMapper.mapToFairwaySegment()` + WKT LINESTRING building | ✅ Done |
| AC-6 | Bunker/water/hazards mapped to Polygon or MultiPolygon | `FeatureTypeMapper.mapToBunker()` etc. → WKT POLYGON/MULTIPOLYGON | ✅ Done |
| AC-7 | Out-of-bounds coordinates rejected | `ImportValidator.validateCoordinates()` checks SRID 4326 longitude [-180,180] and latitude [-90,90] | ✅ Done |
| AC-8 | Missing required attributes rejected | `ImportValidator.validateAttributes()` checks required fields per entity type | ✅ Done |
| AC-9 | Invalid foreign keys (holeNumber not found) reported as VSP-ERR-COURSE-IMPORT-003 | `ImportValidator.validateForeignKeys()` + `VspErrorCode` enum entry | ✅ Done |
| AC-10 | All 5 error codes implemented | `VspErrorCode` enum: COURSE_IMPORT_001 through COURSE_IMPORT_005 | ✅ Done |

---

## Files Created / Modified

### DTOs

| File | Purpose |
|---|---|
| `module/course/dto/ImportPreviewDto.java` | Preview response: previewToken, expiresAt, summary counts, geometry breakdown, validation report |
| `module/course/dto/ImportResultDto.java` | Commit response: success flag, entitiesCreated, errors |
| `module/course/dto/ValidationReportDto.java` | Validation report: totalFeatures, validCount, errorCount, errors list |
| `module/course/dto/ValidationErrorDto.java` | Per-feature error: featureIndex, featureId, errorCode, message, coordinates |
| `module/course/dto/GeometryTypeBreakdownDto.java` | Geometry counts by type: point/line/polygon counts |

### Import Infrastructure

| File | Purpose |
|---|---|
| `module/course/imports/GeoJsonParser.java` | Parses GeoJSON FeatureCollection/Feature to `ParsedFeature` list; handles parse errors |
| `module/course/imports/ParsedFeature.java` | Value object: geometry type, coordinates (raw + extracted), properties map, source JSON |
| `module/course/imports/FeatureTypeMapper.java` | Maps geometry type + properties to `TargetEntity` enum (10 entity types) |
| `module/course/imports/ValidationError.java` | Validation error value object: code, message, coordinates |
| `module/course/imports/ValidationErrorCode.java` | Enum: MISSING_REQUIRED_FIELD, INVALID_GEOMETRY_TYPE, INVALID_COORDINATES, INVALID_FOREIGN_KEY, UNSUPPORTED_GEOMETRY |
| `module/course/imports/ImportValidator.java` | 5-pass validator: coordinates, geometry type, type mapping, attributes, foreign keys |

### Service

| File | Purpose |
|---|---|
| `module/course/CourseImportService.java` | Interface: `previewImport()` + `commitImport()` |
| `module/course/CourseImportServiceImpl.java` | Full implementation: preview token generation/validation, WKT building, entity persistence, DataVersion management |

### Controller

| File | Purpose |
|---|---|
| `api/course/CourseImportController.java` | `POST /admin/courses/{courseId}/import/preview` + `POST /admin/courses/{courseId}/import/commit` |

### Error Codes

| File | Change |
|---|---|
| `api/error/VspErrorCode.java` | Added COURSE_IMPORT_001 (invalid JSON), COURSE_IMPORT_002 (invalid geometry), COURSE_IMPORT_003 (invalid FK), COURSE_IMPORT_004 (validation errors), COURSE_IMPORT_005 (preview token invalid/expired) |

### OpenAPI

| File | Change |
|---|---|
| `packages/contracts/schemas/course.yaml` | Added `GeoJsonImportRequest`, `ImportPreviewResponse`, `ImportCommitRequest`, `ImportResultResponse`, `ValidationError` schemas |

### Tests

| File | Tests | Status |
|---|---|---|
| `test/java/vnpt/vsp/module/course/imports/GeoJsonParserTest.java` | 8 tests: FeatureCollection parsing, Feature parsing, coordinate extraction, geometry type detection, invalid JSON | ✅ All pass |
| `test/java/vnpt/vsp/module/course/imports/FeatureTypeMapperTest.java` | 19 tests: all 10 entity types, property extraction, hole number parsing, tee set mapping | ✅ All pass |
| `test/java/vnpt/vsp/module/course/imports/ImportValidatorTest.java` | 8 tests: coordinate validation, attribute validation, FK validation, error accumulation | ✅ All pass |
| `test/java/vnpt/vsp/module/course/imports/CourseImportServiceTest.java` | 7 tests: preview/commit flow, token validation, course not found, rollback on errors | ✅ All pass |
| `test/java/vnpt/vsp/api/course/CourseImportControllerTest.java` | 6 tests: preview endpoint, commit endpoint, invalid token, course not found | ✅ All pass |

---

## Verification Gate Results

| Gate | Result | Details |
|---|---|---|
| **Format** | ✅ PASS | Code follows existing module style |
| **Lint** | ✅ PASS | No lint issues |
| **Typecheck** | ✅ PASS | `mvn compile` succeeds |
| **Test (IMP-BACK-1)** | ✅ 48 PASS / 0 FAIL | 8 + 19 + 8 + 7 + 6 tests, all pass |
| **Build** | ✅ PASS | `mvn package` succeeds |
| **Full suite** | ⚠️ 50 pre-existing errors | All errors are pre-existing Spring context failures (missing `AdminRoleAssignment` entity from Epic-02, documented in SD-BACK-1) |

---

## Duplicate Detection

| Symbol | Gate | Decision | Status |
|---|---|---|---|
| ImportPreviewDto | PRE-WRITE | clean | ✅ clean |
| ImportResultDto | PRE-WRITE | clean | ✅ clean |
| ValidationReportDto | PRE-WRITE | clean | ✅ clean |
| ValidationErrorDto | PRE-WRITE | clean | ✅ clean |
| GeometryTypeBreakdownDto | PRE-WRITE | clean | ✅ clean |
| GeoJsonParser | PRE-WRITE | clean | ✅ clean |
| ParsedFeature | PRE-WRITE | clean | ✅ clean |
| FeatureTypeMapper | PRE-WRITE | clean | ✅ clean |
| ValidationError | PRE-WRITE | clean | ✅ clean |
| ValidationErrorCode | PRE-WRITE | clean | ✅ clean |
| ImportValidator | PRE-WRITE | clean | ✅ clean |
| CourseImportService | PRE-WRITE | clean | ✅ clean |
| CourseImportServiceImpl | PRE-WRITE | clean | ✅ clean |
| CourseImportController | PRE-WRITE | clean | ✅ clean |
| All symbols | POST-WRITE | clean | ✅ clean |
| — | REINDEX | ok: true | ✅ done |

Dedup report: `docs/vnpt-flow/epic-run-epic-03/dedup_report.json`

---

## Key Implementation Decisions

### 1. Feature Entity Navigation via hole→course
Feature entities (TeeBox, FairwaySegment, etc.) have `hole` FK, NOT `course` field. Navigation: `feature.hole.course`. The `CourseImportServiceImpl.commitImport()` resolves `Hole` by `courseId + holeNumber` then associates each feature.

### 2. WKT Storage with JTS Geometry
All spatial features are stored as `com.vividsolutions.jts.geom.Geometry` (WKT format) via Hibernate Spatial. `FeatureTypeMapper` builds WKT strings (POINT, LINESTRING, POLYGON, MULTIPOLYGON) and `CourseImportServiceImpl` wraps them: `wktReader.read(wkt)`.

### 3. Preview Token In-Memory Store (MVP)
`PreviewTokenStore` uses `ConcurrentHashMap<String, ImportPreviewDto>` with TTL checked on commit. No Redis or DB needed for MVP. Tokens are UUIDs generated by `UUID.randomUUID()`.

### 4. Coordinate Validation
`validateCoordinates()` handles three cases:
- Simple `[x, y]` → 2-element array (Point)
- Position array `[[x, y]]` → single position (polygon vertex)
- Full position list `[[[x1,y1], [x2,y2], ...]]` → polygon ring

Longitude validated: [-180, 180]. Latitude validated: [-90, 90].

### 5. 10-Entity Type Mapping
`FeatureTypeMapper.map()` dispatches to 10 specialized methods:
- `mapToTeeBox()` — Point + holeNumber + teeSetName
- `mapToFairwaySegment()` — LineString + holeNumber
- `mapToBunker()` / `mapToWaterHazard()` / `mapToLateralWater()` / `mapToBush()` / `mapToTree()` / `mapToOutOfBounds()` / `mapToBuilding()` / `mapToPath()` — Polygon/MultiPolygon + holeNumber

### 6. DataVersion Draft Persistence
On commit, `CourseImportServiceImpl` creates `DataVersion` with `status = DRAFT`. Each feature entity stores `dataVersion` reference. `DataQualityMetadata` is created with `accuracyClass = USER_TRACED` and `verificationStatus = UNVERIFIED`.

### 7. Transactional Commit with Rollback
`commitImport()` is `@Transactional`. If any `persist()` call throws, the entire transaction rolls back. Validation errors from `ImportValidator` return error DTO without persisting.

---

## Open Issues

1. **Preview token TTL not enforced by eviction**: `PreviewTokenStore` checks TTL on access but does not actively evict expired entries. For MVP this is acceptable; a future story can add scheduled cleanup.
2. **DataVersion not published**: DataVersion remains DRAFT after commit. A future story can add a publish workflow.
3. **Pre-existing test failures**: 50 errors in full test suite are pre-existing Spring context failures due to missing `AdminRoleAssignment` entity (Epic-02 gap), documented in SD-BACK-1 implementation notes.
