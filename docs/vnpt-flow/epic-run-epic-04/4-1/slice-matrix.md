# Slice Matrix — Story 4.1: Define Course Package Contract

## Story Info
- **Story ID:** 4-1
- **Epic:** Epic-04 (Offline Course Packages)
- **Status after implementation:** review
- **Plan:** `docs/vnpt-flow/epic-run-epic-04/4-1-plan.md`

## Slice Execution Summary

| Slice ID | Layer | Symbol | File | Pre Gate | Post Gate | Status |
|----------|-------|--------|------|----------|-----------|--------|
| PKG-CONTRACT-1 | Schema | `CoursePackageManifestDto` | `packages/contracts/schemas/course.yaml` | PRE_WRITE (clean) | PRE_WRITE (clean) | ✅ clean |
| PKG-CONTRACT-1 | Schema | `CoursePackageManifest` | `packages/course-package/manifest.schema.json` | PRE_WRITE (clean) | PRE_WRITE (clean) | ✅ clean |
| PKG-CONTRACT-2 | Backend | `CoursePackageManifest` | `apps/api/src/main/java/vnpt/vsp/module/package/entity/CoursePackageManifest.java` | PRE_WRITE (clean) | PRE_WRITE (clean) | ✅ clean |
| PKG-CONTRACT-3 | Mobile | `CoursePackageManifest` | `apps/mobile/lib/domain/models/course_package_manifest.dart` | PRE_WRITE (clean) | PRE_WRITE (clean) | ✅ clean |
| PKG-CONTRACT-4 | Contracts | `CoursePackageManifest` | `packages/contracts/openapi.yaml` | PRE_WRITE (clean) | PRE_WRITE (clean) | ✅ clean |

## Duplicate Detection Outcome

**Gate chain:** Cy → Emb(no) → Pre → Post → Reindex
**Embeddings enabled:** false (no semantic search)

All 4 slices passed pre-write and post-write duplicate detection gates with `decision: PRE_WRITE` and `_block: false`. No name collisions detected for any new symbol introduced.

- **PKG-CONTRACT-1**: `CoursePackageManifestDto` and `CoursePackageManifest` schema — no collisions
- **PKG-CONTRACT-2**: `CoursePackageManifest` JPA entity — no collisions with existing `CoursePackage` (booking package) entity
- **PKG-CONTRACT-3**: `CoursePackageManifest` Dart model — no collisions in mobile codebase
- **PKG-CONTRACT-4**: `CoursePackageManifest` OpenAPI paths — no collisions in API contracts

**Reindex result:** `ok: true` (ran once after final write)

## Files Created/Modified

### Slice 1 — PKG-CONTRACT-1 (Schema)
- `packages/course-package/manifest.schema.json` — Enhanced with `files[]`, `minimumClientVersion`, `licenses[]`, `generatedAt`, `generatedBy`, asset URLs
- `packages/contracts/schemas/course.yaml` — Added `CoursePackageManifest`, `PackageFileEntry`, `PackageLicense`, `PackageManifestListResponse` DTOs

### Slice 2 — PKG-CONTRACT-2 (Backend)
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/CoursePackageManifest.java` — JPA entity
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageFileEntry.java` — JPA entity
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageLicense.java` — JPA entity
- `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageManifestRepository.java` — Repository
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageService.java` — Interface with validation/query methods
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageServiceImpl.java` — Implementation

### Slice 3 — PKG-CONTRACT-3 (Mobile)
- `apps/mobile/lib/domain/models/package_content_type.dart` — Enum
- `apps/mobile/lib/domain/models/package_license.dart` — Model
- `apps/mobile/lib/domain/models/package_file_entry.dart` — Model
- `apps/mobile/lib/domain/models/course_package_manifest.dart` — Main manifest model
- `apps/mobile/lib/data/repositories/package_manifest_repository.dart` — SQLite repository with non-destructive pending/active semantics
- `apps/mobile/lib/data/services/package_validation_service.dart` — Checksum and version validation

### Slice 4 — PKG-CONTRACT-4 (Contracts)
- `packages/contracts/openapi.yaml` — Added manifest discovery paths and schema references
- `packages/contracts/schemas/common.yaml` — Added package error codes

## Acceptance Criteria Coverage

| AC | Description | Coverage |
|----|-------------|----------|
| AC-1 | Manifest defines course/version identifiers, checksums, size, effective time, files, minimum client version, and licenses | ✅ `files[]`, `minimumClientVersion`, `licenses[]` added to manifest schema and JPA/Dart models |
| AC-2 | Package contains metadata, local geometry, vector/PMTiles assets, scorecard, rules, and condition snapshots | ✅ `files[]` enumerates all content types; asset URLs added to schema |
| AC-3 | Corrupt or incompatible packages are rejected without replacing the last valid package | ✅ `PackageValidationService` returns `incompatibleVersion`/`checksumMismatch`; `PackageManifestRepository` uses non-destructive pending/active promotion |
