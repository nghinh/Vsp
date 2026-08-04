# Story 3.1 Plan — Model Course and Golf Geometry

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
    "docs/implementation-artifacts/epic-03/3-1-model-course-and-golf-geometry.md",
    "docs/vnpt-flow/epic-run-epic-02/epic-summary.md",
    "docs/vnpt-flow/epic-run-epic-02/epic-state.json",
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
| **Story** | 3.1 |
| **Epic** | 3 — Course Catalog and Data Foundation |
| **Title** | Model Course and Golf Geometry |
| **Status** | `ready-for-dev` |
| **Phase** | MVP 1 |
| **Wave** | 1 of 4 (3-1 has zero dependencies) |
| **Run ID** | `run_2026_08_02_005` |
| **Plan Generated** | 2026-08-02 |

---

## Context Analysis

### PRD Constraints (prd.md)

- **Data Architecture §9.1** defines the canonical entity list: Facility, Course, Hole, Tee Set, Tee Box, Fairway, Rough, Green, Pin Position, Bunker, Water Hazard, Penalty Area, Out-of-Bounds, Cart Path, Landmark, Course Condition, Green Condition, Weather Snapshot, Data Version, Data License.
- **Data Architecture §9.3** mandates data quality fields on every object: source, license, accuracy class, confidence, verification status, created/updated/verified timestamps, effective/expiration timestamps, publisher, version.
- **Data Architecture §9.4** defines accuracy classes A→B→C→D priority.
- **Geospatial Standards §9.2** mandates WGS84/SRID 4326, GeoJSON interchange, PostGIS storage, spatial indexes, and ST_DWithin for nearby queries.
- **Core Entities** extend the PRD entity list with Course Condition, Green Condition, Weather Snapshot, Data Version, Data License.

### Architecture Constraints (architecture.md)

- **§7.1** — PostgreSQL/PostGIS is canonical source of truth for all geometry.
- **§7.2 Spatial Practices** — SRID 4326 storage, GeoJSON for API interchange, GIST indexes on spatial columns, ST_DWithin for range queries, geometry validity checks in import/publish.
- **§7.3 Versioning Model** — append-versioned: draft → published, effective/expiry dates, rollback creates new published version.
- **§7.4 Data Quality Model** — identical to PRD §9.3.
- **Modular Monolith §6.1** — Course Catalog and Geospatial modules already exist as bounded contexts. Cross-module access via service interfaces only.

### Existing Code Evidence

| Finding | Location |
|---|---|
| PostGIS extension enabled | `V1__audit_entries.sql` / `001_baseline.sql` |
| Latest migration | `V14__privacy_requests_fk.sql` → next is `V15__*.sql` |
| CourseModule exists (marker annotation) | `module/course/CourseModule.java` |
| CourseService exists (empty interface) | `module/course/CourseService.java` |
| GeospatialModule exists (marker annotation) | `module/geospatial/GeospatialModule.java` |
| GeospatialService exists (empty interface) | `module/geospatial/GeospatialService.java` |
| Modular monolith pattern | packages, module annotations, service/impl split |
| Flyway migration convention | `V{N}__*.sql` in `src/main/resources/db/migration/` |
| JPA entities in `module/*/entity/` | `module/round/entity/Round.java`, `module/bag/entity/GolfBag.java` |
| Audit infrastructure | `@Audited`, `AuditAspect`, `AuditService` |
| VersionedEntity / ETag infrastructure | `api/versioning/VersionedEntity.java` |

### UX/DESIGN.md Constraints

- **Brand**: authoritative, professional, Soft UI Evolution.
- **Typography**: Fira Sans (UI) + Fira Code (distances/metrics).
- **Badges**: official (solid green), estimated (green border), community (dark grey), stale (red strikethrough).
- **Accessibility**: 4.5:1 contrast, 44/48dp touch targets.

### Epic-02 Context

Epic-02 (Golfer Management) is fully complete. No identity/cross-epic dependencies for story 3-1. The GIS administrator persona uses Epic-01 platform foundations (design tokens, observability).

---

## Scope Analysis

### AC Breakdown

| AC | Description | Nature |
|---|---|---|
| AC-1 | PostGIS schema for facilities, courses, holes, tees, fairways, rough, greens, bunkers, water, penalty areas, OB, paths, landmarks | Schema entities |
| AC-2 | SRID 4326, validity constraints, GIST indexes | Spatial properties |
| AC-3 | source, license, quality, confidence, verification, effective/expiry, publisher, version metadata | Data quality columns |

### Entity Relationships

```
GolfFacility (1) ─────< (N) Course
Course (1) ─────< (N) Hole
Hole (1) ─────< (N) TeeBox
Hole (1) ─────< (N) FairwaySegment
Hole (1) ─────< (N) Green
Hole (1) ─────< (N) Bunker
Hole (1) ─────< (N) WaterHazard
Hole (1) ─────< (N) PenaltyArea
Hole (1) ─────< (N) OutOfBounds
Hole (1) ─────< (N) CartPath
Hole (1) ─────< (N) Landmark
Course (1) ─────< (N) TeeSet
Hole (1) ─────< (N) PinPosition
Course (1) ─────< (N) CourseCondition
Course (1) ─────< (N) DataVersion
DataVersion (1) ─────< (N) DataLicense
```

### Metadata Column Group (shared by all geometry objects)

Every feature table carries:
`source`, `license`, `accuracy_class`, `confidence`, `verification_status`, `created_at`, `updated_at`, `last_verified_at`, `effective_date`, `expiry_date`, `publisher`, `version`

→ Implemented as a **shared metadata columns migration** included in the foundation slice.

### Geometry Type Mapping

| Feature | PostGIS Geometry Type | Justification |
|---|---|---|
| GolfFacility | POINT | Single coordinate centroid |
| Course | POLYGON or POINT | Per-layout boundary or centroid |
| Hole | POLYGON | Hole playing area boundary |
| TeeBox | POLYGON | Teeing ground area |
| FairwaySegment | LINESTRING or POLYGON | Centerline or full width |
| Green | POLYGON | Putting green boundary |
| Bunker | POLYGON | Sand trap area |
| WaterHazard | POLYGON or LINESTRING | Water body |
| PenaltyArea | POLYGON | Penalty area boundary |
| OutOfBounds | LINESTRING or POLYGON | OB boundary |
| CartPath | LINESTRING | Path centerline |
| Landmark | POINT | Point feature |
| PinPosition | POINT | Pin location |

### Spatial Constraints

- All geometry columns: `SRID 4326`, `NOT NULL`
- Validity constraint: `ST_IsValid(geom) = true` (check constraint or trigger)
- Index: `GIST` index on every geometry column
- For range queries: `ST_DWithin(geom, point, radius_meters)`

---

## Slice Plan

### Slice GEO-1 (Foundation) — Shared Metadata Columns + Geometry Base Types
**Independent**: ✅ (wave 1, no upstream deps)
**Risk**: LOW — pure schema, no logic

1. **Migration** `V15__course_geometry_foundation.sql`
   - Create `accuracy_class` enum: `A_RTK_SURVEYED`, `B_LICENSED_PROVIDER`, `C_VERIFIED_SATELLITE`, `D_UNVERIFIED_COMMUNITY`
   - Create `verification_status` enum: `UNVERIFIED`, `PENDING_REVIEW`, `VERIFIED`, `REJECTED`
   - Create `data_quality_metadata` **table** (shared column group):
     - `source` VARCHAR
     - `license` VARCHAR
     - `accuracy_class` FK → accuracy_class enum
     - `confidence` DECIMAL(5,2) — 0.00 to 100.00
     - `verification_status` FK → verification_status enum
     - `created_at` TIMESTAMPTZ NOT NULL DEFAULT now()
     - `updated_at` TIMESTAMPTZ NOT NULL DEFAULT now()
     - `last_verified_at` TIMESTAMPTZ
     - `effective_date` DATE NOT NULL
     - `expiry_date` DATE
     - `publisher` VARCHAR NOT NULL
     - `version` INTEGER NOT NULL DEFAULT 1
   - Add PostGIS `geometry_validity_trigger` function + trigger to enforce `ST_IsValid`
   - Create GIST index template comment

2. **JPA Entities** — `module/course/entity/`
   - `DataQualityMetadata.java` — embeddable entity with all metadata columns
   - `AccuracyClass.java` — enum
   - `VerificationStatus.java` — enum

3. **Tests**
   - `DataQualityMetadataTest` — field defaults, nullability
   - Flyway migration test — verify V15 applies cleanly on clean schema

---

### Slice GEO-2 (Facility + Course + Hole) — Core Hierarchy Entities
**Independent**: ✅ (no cross-slice runtime dependency; all add new tables)
**Risk**: LOW — pure schema + JPA

1. **Migration** `V16__facilities_courses_holes.sql`
   - `golf_facilities` — id, name, address, phone, website, location POINT(4326), created_at, updated_at, plus FK to data_quality_metadata (one-to-one)
   - `courses` — id, facility_id FK, name, holes_count, par_total, location POINT(4326) or POLYGON(4326), created_at, updated_at, plus data_quality_metadata FK
   - `holes` — id, course_id FK, hole_number INTEGER NOT NULL, par INTEGER NOT NULL, teeing_ground_location POINT(4326), green_location POINT(4326), playing_length_meters DECIMAL, created_at, updated_at, plus data_quality_metadata FK

2. **JPA Entities** — `module/course/entity/`
   - `GolfFacility.java`
   - `Course.java`
   - `Hole.java`

3. **Repository interfaces** — `module/course/repository/`
   - `GolfFacilityRepository.java`
   - `CourseRepository.java`
   - `HoleRepository.java`

4. **Tests**
   - `GolfFacilityRepositoryTest` — CRUD + spatial index
   - `CourseRepositoryTest` — CRUD + FK cascade
   - `HoleRepositoryTest` — hole_number uniqueness per course, par range [1,9]

---

### Slice GEO-3 (Golf Feature Geometry) — All Spatial Feature Tables
**Independent**: ✅ (all features reference Hole or Course)
**Risk**: LOW — pure schema

1. **Migration** `V17__golf_feature_geometry.sql`
   - `tee_boxes` — id, hole_id FK, tee_set_id FK (nullable), location POLYGON(4326), created_at, updated_at, data_quality_metadata FK
   - `fairway_segments` — id, hole_id FK, location POLYGON(4326) or LINESTRING(4326), created_at, updated_at, data_quality_metadata FK
   - `greens` — id, hole_id FK, location POLYGON(4326), created_at, updated_at, data_quality_metadata FK
   - `bunkers` — id, hole_id FK, location POLYGON(4326), created_at, updated_at, data_quality_metadata FK
   - `water_hazards` — id, hole_id FK, location POLYGON(4326) or LINESTRING(4326), hazard_type VARCHAR, created_at, updated_at, data_quality_metadata FK
   - `penalty_areas` — id, hole_id FK, location POLYGON(4326), created_at, updated_at, data_quality_metadata FK
   - `out_of_bounds` — id, hole_id FK, location LINESTRING(4326) or POLYGON(4326), created_at, updated_at, data_quality_metadata FK
   - `cart_paths` — id, hole_id FK, location LINESTRING(4326), path_type VARCHAR, created_at, updated_at, data_quality_metadata FK
   - `landmarks` — id, hole_id FK, location POINT(4326), landmark_type VARCHAR, name VARCHAR, created_at, updated_at, data_quality_metadata FK
   - `tee_sets` — id, course_id FK, name VARCHAR, total_par INTEGER, created_at, updated_at, data_quality_metadata FK
   - `pin_positions` — id, hole_id FK, location POINT(4326), pin_position_type VARCHAR, effective_date DATE, expiry_date DATE, created_at, updated_at, data_quality_metadata FK

2. **JPA Entities** — `module/course/entity/`
   - `TeeBox.java`
   - `FairwaySegment.java`
   - `Green.java`
   - `Bunker.java`
   - `WaterHazard.java`
   - `PenaltyArea.java`
   - `OutOfBounds.java`
   - `CartPath.java`
   - `Landmark.java`
   - `TeeSet.java`
   - `PinPosition.java`

3. **Repository interfaces** — `module/course/repository/`
   - `TeeBoxRepository.java`, `FairwaySegmentRepository.java`, `GreenRepository.java`, `BunkerRepository.java`, `WaterHazardRepository.java`, `PenaltyAreaRepository.java`, `OutOfBoundsRepository.java`, `CartPathRepository.java`, `LandmarkRepository.java`, `TeeSetRepository.java`, `PinPositionRepository.java`

4. **Tests**
   - Geometry validity constraint test per feature type
   - SRID enforcement test
   - FK cascade delete test (deleting Hole removes associated features)
   - PinPosition effective/expiry date range test

---

### Slice GEO-4 (Course Condition + Versioning) — State + Audit Tables
**Independent**: ✅ (adds course condition + version/license tables)
**Risk**: LOW

1. **Migration** `V18__course_condition_and_versioning.sql`
   - `course_conditions` — id, course_id FK, condition_type VARCHAR, severity VARCHAR, description TEXT, effective_date DATE, expiry_date DATE, created_at, updated_at, data_quality_metadata FK
   - `data_versions` — id, course_id FK, version_number INTEGER NOT NULL, status VARCHAR (DRAFT/PUBLISHED/ARCHIVED), published_at TIMESTAMPTZ, published_by VARCHAR, publish_note TEXT, created_at, updated_at, data_quality_metadata FK
   - `data_licenses` — id, data_version_id FK, license_type VARCHAR, licensee VARCHAR, license_key VARCHAR, effective_date DATE, expiry_date DATE, created_at, updated_at, data_quality_metadata FK

2. **JPA Entities** — `module/course/entity/`
   - `CourseCondition.java`
   - `DataVersion.java`
   - `DataLicense.java`

3. **Repository interfaces** — `module/course/repository/`
   - `CourseConditionRepository.java`
   - `DataVersionRepository.java`
   - `DataLicenseRepository.java`

4. **Tests**
   - `DataVersionTest` — DRAFT → PUBLISHED state transition, version_number increment
   - `CourseConditionTest` — effective/expiry date range validation

---

### Slice GEO-5 (CourseService + GeospatialService) — Interface Implementation
**Independent**: ✅ (activates the empty service interfaces with actual methods)
**Risk**: LOW

1. **CourseServiceImpl** — implement `module/course/CourseService.java`
   - `createFacility`, `updateFacility`, `getFacility`, `listFacilities`
   - `createCourse`, `updateCourse`, `getCourse`, `listCoursesByFacility`
   - `createHole`, `updateHole`, `getHole`, `listHolesByCourse`
   - `createTeeSet`, `getTeeSetsByCourse`
   - `createPinPosition`, `getActivePinPosition`
   - `createCourseCondition`, `getActiveConditions`

2. **GeospatialServiceImpl** — implement `module/geospatial/GeospatialService.java`
   - `validateGeometry(Geometry)` — ST_IsValid check
   - `calculateDistance(Geometry, Geometry, unit)` — ST_Distance with SRID 4326
   - `findFeaturesWithinRadius(Point, radiusMeters, featureType)` — ST_DWithin
   - `findNearestFeature(Point, featureType)` — ST_DWithin ordering

3. **Tests**
   - `CourseServiceImplTest` — CRUD coverage for all entity types
   - `GeospatialServiceImplTest` — geometry validity, distance calculation, ST_DWithin query

---

## Verification Gates

| Slice | Format | Lint | Typecheck | Test | Build |
|---|---|---|---|---|---|
| GEO-1 | ✅ | ✅ | ✅ (migration dry-run) | ✅ | — |
| GEO-2 | ✅ | ✅ | ✅ | ✅ | ✅ |
| GEO-3 | ✅ | ✅ | ✅ | ✅ | ✅ |
| GEO-4 | ✅ | ✅ | ✅ | ✅ | ✅ |
| GEO-5 | ✅ | ✅ | ✅ | ✅ | ✅ (full compile) |

---

## Quality Gate: Pre-Write Dedup

Before writing each slice, run:
```
python3 "docs/vnpt-flow/epic-run-epic-03/tools/dedup.py" precheck <EntityName> --file apps/api/src/main/java/vnpt/vsp/module/course/entity/<EntityName>.java
```
Expected: `new_duplicate_likely: false`

---

## File Manifest (per slice)

### GEO-1
- `apps/api/src/main/resources/db/migration/V15__course_geometry_foundation.sql`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/AccuracyClass.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/VerificationStatus.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/DataQualityMetadata.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/entity/DataQualityMetadataTest.java`

### GEO-2
- `apps/api/src/main/resources/db/migration/V16__facilities_courses_holes.sql`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/GolfFacility.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/Course.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/Hole.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/GolfFacilityRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/CourseRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/HoleRepository.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/GolfFacilityRepositoryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/CourseRepositoryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/HoleRepositoryTest.java`

### GEO-3
- `apps/api/src/main/resources/db/migration/V17__golf_feature_geometry.sql`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/TeeBox.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/FairwaySegment.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/Green.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/Bunker.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/WaterHazard.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/PenaltyArea.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/OutOfBounds.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/CartPath.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/Landmark.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/TeeSet.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/PinPosition.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/TeeBoxRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/FairwaySegmentRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/GreenRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/BunkerRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/WaterHazardRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/PenaltyAreaRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/OutOfBoundsRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/CartPathRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/LandmarkRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/TeeSetRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/PinPositionRepository.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/GeometryConstraintTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/repository/HoleFeatureCascadeTest.java`

### GEO-4
- `apps/api/src/main/resources/db/migration/V18__course_condition_and_versioning.sql`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/CourseCondition.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/DataVersion.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/entity/DataLicense.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/CourseConditionRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/DataVersionRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/course/repository/DataLicenseRepository.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/entity/DataVersionTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/entity/CourseConditionTest.java`

### GEO-5
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseServiceImpl.java`
- `apps/api/src/main/java/vnpt/vsp/module/geospatial/GeospatialServiceImpl.java`
- `apps/api/src/test/java/vnpt/vsp/module/course/CourseServiceImplTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/geospatial/GeospatialServiceImplTest.java`

---

## Decision Log

| Decision | Rationale |
|---|---|
| Embeddable `DataQualityMetadata` instead of per-table columns | Eliminates repetition across 15+ feature tables; JPA `@Embedded` / `@AttributeOverride` pattern matches existing entity style |
| Geometry validity via SQL trigger `ST_IsValid` | Enforces at DB level; Hibernate Spatial validates on flush |
| `accuracy_class` as FK enum table | Matches Epic-01 patterns (roles as enum tables); allows future extension |
| Separate `pin_positions` table with effective/expiry | Supports portal pin scheduling (PRD §8.11); versioning requirement |
| `fairway_segments` accepts POLYGON or LINESTRING | Some courses model fairway as centerline, others as full area |
| No Flyway undo scripts | Append-only versioning model; rollback via new published version |

---

## Constraints Respecting Existing Architecture

- All new entities follow existing package convention: `module/course/entity/`, `module/course/repository/`
- All migrations follow `V{N}__*.sql` Flyway naming convention (existing: V1–V14)
- Service impl follows `module/*/*ServiceImpl.java` pattern
- No changes to `module/identity/` or `module/profile/` (Epic-02 scope)
- `@GeospatialModule` and `@CourseModule` annotations preserved
- Audit infrastructure (`@Audited`) applied to entities that are user-facing via portal
- Existing versioning infrastructure (`VersionedEntity`) NOT inherited — course versioning uses `DataVersion` entity per architecture §7.3

---

## Story Status After Planning

`ready-for-dev` → `planned`

**Plan file**: `docs/vnpt-flow/epic-run-epic-03/3-1-plan.md`

**Next action**: `vnpt-dev-epic-orchestrator` dispatches implementer for slice GEO-1.
