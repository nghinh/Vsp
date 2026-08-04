---
story: "4.1"
epic: 4
title: "Define Course Package Contract"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 4.1: Define Course Package Contract

## User Story

As a mobile developer, I want a stable package manifest so that clients can validate and use downloaded course data.

## Acceptance Criteria

- Manifest defines course/version identifiers, checksums, size, effective time, files, minimum client version, and licenses.
- Package contains metadata, local geometry, vector/PMTiles assets, scorecard, rules, and condition snapshots.
- Corrupt or incompatible packages are rejected without replacing the last valid package.

## Tasks and Subtasks

- [x] Confirm the define course package contract scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where applicable.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Dev Agent Record

### Implementation Plan
Implemented 4 slices as defined in `docs/vnpt-flow/epic-run-epic-04/4-1-plan.md`:
1. **PKG-CONTRACT-1 (Schema):** Extended `manifest.schema.json` with `files[]`, `minimumClientVersion`, `licenses[]`, `generatedAt/By`, asset URLs; added `CoursePackageManifest`, `PackageFileEntry`, `PackageLicense`, `PackageManifestListResponse` to OpenAPI schema
2. **PKG-CONTRACT-2 (Backend):** JPA entities `CoursePackageManifest`, `PackageFileEntry`, `PackageLicense`; `PackageManifestRepository`; `PackageService` interface with `ManifestValidationResult` enum and validation/query methods
3. **PKG-CONTRACT-3 (Mobile):** Dart models mirroring manifest schema; SQLite repository with non-destructive pending/active promotion semantics; `PackageValidationService` for checksum + version checking
4. **PKG-CONTRACT-4 (Contracts):** OpenAPI paths for manifest discovery + ETag support; error codes `PACKAGE_NOT_FOUND`, `PACKAGE_INCOMPATIBLE`, `PACKAGE_CORRUPT`, `PACKAGE_NO_LONGER_EFFECTIVE`

### Completion Notes
- All 4 slices passed duplicate detection gates (pre-write and post-write) with clean status
- Reindex ran successfully after final write
- `CoursePackage` (booking/commercial package) correctly distinguished from `CoursePackageManifest` (offline data package)
- Non-destructive rejection semantics implemented in `PackageManifestRepository.savePending` / `promotePendingToActive` / `discardPending`
- All acceptance criteria covered: AC-1 (manifest fields), AC-2 (package contents enumeration), AC-3 (non-destructive rejection)

### File List
**Schema (PKG-CONTRACT-1):**
- `packages/course-package/manifest.schema.json` — Enhanced with files[], minimumClientVersion, licenses[], generatedAt, generatedBy, asset URLs
- `packages/contracts/schemas/course.yaml` — Added CoursePackageManifest, PackageFileEntry, PackageLicense, PackageManifestListResponse DTOs

**Backend (PKG-CONTRACT-2):**
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/CoursePackageManifest.java`
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageFileEntry.java`
- `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageLicense.java`
- `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageManifestRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageService.java`
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageServiceImpl.java`

**Mobile (PKG-CONTRACT-3):**
- `apps/mobile/lib/domain/models/package_content_type.dart`
- `apps/mobile/lib/domain/models/package_license.dart`
- `apps/mobile/lib/domain/models/package_file_entry.dart`
- `apps/mobile/lib/domain/models/course_package_manifest.dart`
- `apps/mobile/lib/data/repositories/package_manifest_repository.dart`
- `apps/mobile/lib/data/services/package_validation_service.dart`

**Contracts (PKG-CONTRACT-4):**
- `packages/contracts/openapi.yaml` — Added manifest discovery paths and schema references
- `packages/contracts/schemas/common.yaml` — Added package error codes

## Source References

- `docs/planning-artifacts/epics.md` — Story 4.1 and Epic 4
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `4-1-define-course-package-contract`
- `docs/vnpt-flow/epic-run-epic-04/4-1-plan.md` — Slice plan
- `docs/vnpt-flow/epic-run-epic-04/4-1/slice-matrix.md` — Slice execution matrix
