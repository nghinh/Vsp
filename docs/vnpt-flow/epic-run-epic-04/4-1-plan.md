# Story 4.1 Plan — Define Course Package Contract

**Run ID:** `run_2026_08_02_005`
**Epic:** Epic-04 (Offline Course Packages)
**Wave:** 4-1 (wave 1 of 4 — no dependencies)
**Story:** `4-1-define-course-package-contract`
**Status source:** `docs/implementation-artifacts/epic-04/4-1-define-course-package-contract.md`
**Plan file:** `docs/vnpt-flow/epic-run-epic-04/4-1-plan.md`
**Planning mode:** resume from checkpoint — story status already `in-progress`

---

## Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md",
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/ux-spec.md",
    "docs/planning-artifacts/epics.md"
  ],
  "project_context_sources_read": [
    "docs/project-context.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-state.json"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-04/4-1-define-course-package-contract.md"
  ],
  "mockup_sources_read": []
}
```

---

## Scope Analysis

### What Story 4.1 Must Establish

Story 4.1 defines the **offline course package contract** — the manifest schema, package file inventory, and validation/rejection semantics. It is a pure **contracts and models** story; it does not implement package generation, download, or storage management. Those are later Epic-04 stories (4.2, 4.3, 4.4).

### AC-to-Artifact Mapping

| AC | Requirement | Existing Artifact | Gap |
|----|-------------|-------------------|-----|
| AC-1 | Manifest fields: identifiers, checksums, size, effective time, **files**, **minimum client version**, **licenses** | `packages/course-package/manifest.schema.json` has identifiers, checksum, sizeBytes, effectiveDate | **Missing**: `files[]` (per-file entries with checksums), `minimumClientVersion`, `licenses[]` |
| AC-2 | Package contents: metadata, local geometry, vector/PMTiles assets, scorecard, rules, condition snapshots | README defines package contents; no machine-readable enumeration | **Missing**: `files[]` array mapping content types to asset paths/checksums |
| AC-3 | Corrupt/incompatible packages rejected without replacing last valid | No validation or rejection logic exists | **Missing**: manifest validation on client, non-destructive rejection semantics |

### PRD Requirements Traced

| PRD Section | Requirement | Coverage |
|-------------|-------------|----------|
| §8.3 | Package includes: metadata, hole geometry, vector maps, scorecards, local rules, pin positions, course conditions, weather snapshot | Manifest schema must enumerate these as `files[]` entries |
| §9 Core Entities | `CoursePackage`, `DataVersion` | `CoursePackage` in course.yaml is booking package, not offline data package. New `CoursePackageManifest` entity needed |
| §9.3 | Data quality fields: source, license, accuracy, confidence, effective/expiry, version, publisher | Manifest must carry these; existing `accuracyClass` and `confidence` in schema |
| §10.6 Security | No default sharing; TLS everywhere; secrets not in clients | Manifest license field covers data license; package distribution is CDN-backed immutable URLs |
| Architecture §9.2 | Manifest with version, checksum, size, effective date | Already in schema; files[], minimumClientVersion, licenses[] missing |

### Epic-03 Foundations Used

- **PostGIS geometry schema** (Story 3.1): All hole layers (tee, fairway, green, bunker, water, OB, cart path, landmark) are modeled. Package `local geometry` asset references this schema.
- **Course version model** (Stories 3.1–3.4): `DataVersion` entity exists with version number, effective date, publisher. Manifest `dataVersion` field links to this.
- **Course detail** (Story 3.3): `ConditionDto` and `DataQualityDto` define condition snapshot structure. Package `condition snapshots` use these.
- **Search result** (Story 3.2): `hasPackage`, `updateAvailable`, `dataFreshness` flags on course search results are the consumer-side contract that Story 4.3 (download) and 4.4 (incremental update) will satisfy.

### Epic-04 Internal Dependencies

```
Story 4.1 (contracts) ──────────────────────────────────┐
                                                          ▼
Story 4.2 (generate/publish) ── uses manifest schema ──┐  │
                                                          ▼
Story 4.3 (download/manage) ─────── uses manifest ───────┘  │
                                                          ▼
Story 4.4 (incremental update) ─── uses manifest ──────────┘
```

Story 4.1 output is consumed by all subsequent Epic-04 stories.

### Gap: `CoursePackage` in contracts Is Not the Offline Package

The `CoursePackage` schema in `packages/contracts/schemas/course.yaml` (lines 128–192) is a **booking/commercial package** (name, price, validity dates, includes). It is unrelated to the **offline data package** defined by Story 4.1. The offline package is a `CoursePackageManifest` associated with a `dataVersion` and is referenced by course search results via `hasPackage: true`.

### Backend Module Note

Backend module is `vnpt.vsp.module.pkg` (Java package) in directory `apps/api/src/main/java/vnpt/vsp/module/package/`. The existing `PackageService.java` and `PackageServiceImpl.java` are stubs in the `pkg` namespace.

---

## Slice Plan

### Slice 1 — Manifest Schema Enhancement (`PKG-CONTRACT-1`)

**Scope:** Extend `packages/course-package/manifest.schema.json` and add OpenAPI `CoursePackageManifest` schema.

**Changes:**

1. **`packages/course-package/manifest.schema.json`** — Add missing AC-1 fields:
   - `files`: array of `PackageFileEntry` objects (path, checksum, sizeBytes, contentType)
   - `minimumClientVersion`: string (semver, e.g. `"1.0.0"`)
   - `licenses`: array of `{ name, url, spdxId }` objects
   - `scorecardUrl`, `rulesUrl`, `conditionsUrl`, `metadataUrl`: URI strings pointing to package assets (already partially present as `geoJsonUrl`, `tilesUrl`; add the rest)
   - `generatedAt`: date-time (when package was built)
   - `generatedBy`: string (operator/system that built the package)

   Keep backward compatibility with existing fields. `additionalProperties: true` already present.

2. **`packages/contracts/schemas/course.yaml`** — Add `CoursePackageManifestDto` OpenAPI schema mirroring the JSON Schema, for API request/response use. Add `PackageFileEntryDto`. Add `PackageManifestListResponse` with pagination.

**AC served:** AC-1 (manifest fields), AC-2 (package contents enumerated in `files[]`)

**Verification:**
- JSON Schema validates a fully-populated manifest document
- OpenAPI schema produces valid SDK types for the manifest DTO
- Schema includes all fields from AC-1 and AC-2

---

### Slice 2 — Backend Domain Model (`PKG-CONTRACT-2`)

**Scope:** Define `CoursePackageManifest` as a JPA entity in the `pkg` module, wire repository, and add service-level validation methods.

**Changes:**

1. **New entity:** `apps/api/src/main/java/vnpt/vsp/module/package/entity/CoursePackageManifest.java`
   - Fields: `id (UUID)`, `courseId (Long)`, `dataVersionId (Long)`, `version (semver String)`, `packageSizeBytes (Long)`, `checksum (SHA-256 hex)`, `effectiveFrom (Instant)`, `expiresAt (Instant?)`, `minimumClientVersion (String)`, `tilesFormat (enum: PMTILES, MBTILES, VECTOR_TILES)`, `tilesUrl (String)`, `geoJsonUrl (String)`, `scorecardUrl (String?)`, `rulesUrl (String?)`, `conditionsUrl (String?)`, `metadataUrl (String?)`, `generatedAt (Instant)`, `generatedBy (String)`, `accuracyClass (enum)`, `confidence (Double)`, `pinSnapshotDate (Instant?)`, `weatherSnapshotDate (Instant?)`
   - JPA validation: `@NotNull` on required fields, `@Min(0)` on sizeBytes, regex on version semver
   - Indexes: `(courseId, version)` unique, `(courseId, effectiveFrom)` for active-package queries

2. **New entity:** `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageFileEntry.java`
   - Fields: `id`, `manifestId (FK)`, `path (String)`, `checksum (SHA-256 hex)`, `sizeBytes (Long)`, `contentType (enum: METADATA, GEOMETRY, TILES, SCORECARD, RULES, CONDITIONS, WEATHER, SATELLITE)`
   - Unique constraint on `(manifestId, path)`

3. **New entity:** `apps/api/src/main/java/vnpt/vsp/module/package/entity/PackageLicense.java`
   - Fields: `id`, `manifestId (FK)`, `name (String)`, `url (String?)`, `spdxId (String?)`

4. **New repository:** `apps/api/src/main/java/vnpt/vsp/module/package/repository/PackageManifestRepository.java` extending `JpaRepository`
   - `Optional<CoursePackageManifest> findByCourseIdAndVersion(Long courseId, String version)`
   - `Optional<CoursePackageManifest> findFirstByCourseIdAndEffectiveFromBeforeOrderByEffectiveFromDesc(courseId, now)` — current active package
   - `List<CoursePackageManifest> findByCourseIdOrderByVersionDesc(courseId)` — version history

5. **`PackageService` interface additions** (in `vnpt.vsp.module.pkg`):
   - `validateManifest(checksum, fileEntries, minimumClientVersion, clientVersion)`: returns `ManifestValidationResult` (valid / checksum_mismatch / version_too_old / missing_file)
   - `getActiveManifest(courseId)`: returns current effective manifest or empty
   - `getManifestHistory(courseId)`: returns version list for update UI

6. **`PackageServiceImpl` additions:**
   - Implement the interface methods above
   - Add `ManifestValidationResult` enum or inner class

**AC served:** AC-1 (backend validates manifest fields including minimum client version), AC-3 (validation result prevents use of corrupt/incompatible package)

**Verification:**
- Unit tests: `ManifestValidationResult` covers checksum mismatch, version too old, missing file
- Repository tests: active manifest query returns null-safe result for course with no packages
- Service tests: validation rejects checksum mismatch, accepts valid manifest

---

### Slice 3 — Mobile Manifest Model and Persistence (`PKG-CONTRACT-3`)

**Scope:** Dart model, local SQLite persistence, and non-destructive validation on the mobile client.

**Changes:**

1. **New model:** `apps/mobile/lib/domain/models/course_package_manifest.dart`
   - Fields mirror enhanced manifest schema (packageId, courseId, version, checksum, sizeBytes, effectiveDate, expiresAt, files[], minimumClientVersion, licenses[], tilesFormat, tilesUrl, geoJsonUrl, scorecardUrl, rulesUrl, conditionsUrl, metadataUrl, generatedAt, generatedBy, accuracyClass, confidence, pinSnapshotDate, weatherSnapshotDate)
   - `fromJson(Map<String, dynamic> json)` factory
   - `toJson()` method
   - `files` is `List<PackageFileEntry>`
   - `licenses` is `List<PackageLicense>`

2. **New model:** `apps/mobile/lib/domain/models/package_file_entry.dart`
   - Fields: path, checksum, sizeBytes, contentType enum

3. **New model:** `apps/mobile/lib/domain/models/package_license.dart`
   - Fields: name, url, spdxId

4. **New enum:** `apps/mobile/lib/domain/models/package_content_type.dart`
   - Values: METADATA, GEOMETRY, TILES, SCORECARD, RULES, CONDITIONS, WEATHER, SATELLITE

5. **New persistence:** `apps/mobile/lib/data/repositories/package_manifest_repository.dart`
   - Uses existing SQLite infrastructure (cf. `profile_sync_store.dart`, `bag_sync_store.dart`)
   - `saveManifest(manifest)` — persists current manifest for a course
   - `getManifest(courseId)` — retrieves last downloaded manifest
   - `getManifestFiles(courseId)` — retrieves file entries
   - `deleteManifest(courseId)` — removes manifest (called by Story 4.3 delete)
   - **Non-destructive semantics**: `saveManifest` writes to a `pending_manifest` column first; only promotes to `active_manifest` after `validateManifest` returns valid. On validation failure, pending is discarded and active is untouched.
   - `hasActiveManifest(courseId)`: bool

6. **New service:** `apps/mobile/lib/data/services/package_validation_service.dart`
   - `validateManifest(manifest, clientVersion)`: computes SHA-256 of downloaded archive, compares to manifest.checksum; compares client version to minimumClientVersion; returns `PackageValidationResult` (VALID / CHECKSUM_MISMATCH / INCOMPATIBLE_VERSION / MISSING_FILE)
   - `getActiveManifest(courseId)`: returns manifest if one exists and is validated

7. **Existing infrastructure reused:**
   - `apps/mobile/lib/core/storage/` — encrypted storage for checksum cache
   - `apps/mobile/lib/core/network/api_client.dart` — for manifest download

**AC served:** AC-3 (reject corrupt/incompatible without replacing last valid)

**Verification:**
- Unit test: `PackageValidationService` computes checksum and returns INCOMPATIBLE_VERSION when clientVersion < minimumClientVersion
- Unit test: repository does not overwrite active_manifest when validation fails (non-destructive semantics)
- Unit test: manifest model parses full JSON including files[] and licenses[]

---

### Slice 4 — API Contracts for Package Distribution (`PKG-CONTRACT-4`)

**Scope:** OpenAPI paths for package manifest discovery and download, plus error codes.

**Changes:**

1. **`packages/contracts/openapi.yaml`** — Add paths:
   - `GET /courses/{courseId}/packages` — list manifests (paginated), returns `PackageManifestListResponse`
   - `GET /courses/{courseId}/packages/current` — get active manifest for a course
   - `GET /courses/{courseId}/packages/{version}` — get specific manifest by version
   - `GET /courses/{courseId}/packages/{version}/files` — list file entries for a manifest
   - `GET /courses/{courseId}/packages/{version}/files/{path}` — download single file asset

2. **Error codes** (extend `packages/contracts/schemas/common.yaml`):
   - `PACKAGE_NOT_FOUND` — no manifest for course/version
   - `PACKAGE_INCOMPATIBLE` — minimumClientVersion exceeded
   - `PACKAGE_CORRUPT` — checksum mismatch (for downloaded artifact validation)
   - `PACKAGE_NO_LONGER_EFFECTIVE` — package has expired

3. **ETag support**: Manifest endpoints return `ETag` header with manifest version hash. Clients send `If-None-Match` for conditional fetch (used by Story 4.4 incremental update).

**AC served:** AC-1 (API surfaces manifest fields), AC-3 (error codes for rejection scenarios)

**Verification:**
- OpenAPI validation passes
- Generated SDK includes manifest DTO and error types

---

## Quality Gate

**Gate type:** detect-duplicate flow (Serena exact-name match → CC → SigCheck + Emb → Q → AIJudge + PreWrite → Report → Reindex)

**Note:** The dedup tool at `docs/vnpt-flow/epic-run-epic-04/tools/dedup.py` does not exist yet. The quality gate will use available tools (Serena, GitNexus, OpenAPI validation) and defer dedup tool creation to the orchestrator infrastructure if needed.

**Chain steps:**
1. **Serena (Cy):** Query for `CoursePackageManifest`, `PackageFileEntry`, `PackageLicense`, `CoursePackageManifestDto`, `PackageManifestRepository`, `PackageManifestListResponse`, `PackageValidationResult`, `PackageContentType` across all source files. Any exact-name collision with differing signature → reject.
2. **Serena (CC):** Verify the `PackageService` interface changes don't break callers. Check `PackageModule` for proper Spring wiring.
3. **SigCheck:** Verify manifest.schema.json JSON Schema is syntactically valid and semantically correct against AC-1/AC-2 requirements.
4. **Emb (embeddings):** Query with "course package manifest schema validation offline golf". Check top-3 semantic matches for intent-equivalent existing symbols that should be reused instead of created.
5. **PreWrite (precheck):** Run pre-write duplicate detection via Serena pattern search for new top-level symbols before code is written.
6. **Report:** Verify `docs/vnpt-flow/epic-run-epic-04/4-1/dedup_report.json` exists (or would exist after implementer run), status is `clean` or `resolved`, `_block: false`, attempts between 1–3, includes pre-phase and post-phase attempts.
7. **Reindex:** If dedup tool exists, verify `reindex` returned `ok: true` and was run exactly once after the final write.

**Gate verdict:** Return `QA_PASS` or `QA_FAIL: <step>` per runner rules.

---

## Anti-Shortcut Evidence

- Did NOT treat existing `CoursePackage` in `course.yaml` as the offline package — explicitly documented the distinction.
- Did NOT skip `minimumClientVersion` or `files[]` fields — AC-1 explicitly requires them.
- Did NOT plan package generation/storage/management in Story 4.1 — those are Stories 4.2/4.3.
- Did NOT plan Flutter download UI in Story 4.1 — Story 4.3 covers download and management.
- Did NOT plan incremental update logic in Story 4.1 — Story 4.4 covers ETag/version-based delta.
- Did NOT plan active-round package switching in Story 4.1 — Story 4.4 covers round-package affinity.
- Non-destructive rejection (AC-3) is explicitly modeled in the repository slice with pending/active promotion semantics.
- Did NOT confuse the `package` module directory with the `pkg` Java package namespace.

---

## File Changes Summary

| Slice | Layer | Files Changed |
|-------|-------|--------------|
| PKG-CONTRACT-1 | Schema | `packages/course-package/manifest.schema.json` (enhanced), `packages/contracts/schemas/course.yaml` (new DTOs) |
| PKG-CONTRACT-2 | Backend | `apps/api/src/main/java/vnpt/vsp/module/package/entity/CoursePackageManifest.java`, `PackageFileEntry.java`, `PackageLicense.java`, `repository/PackageManifestRepository.java`, `PackageService.java` (interface additions), `PackageServiceImpl.java` (implementations) |
| PKG-CONTRACT-3 | Mobile | `apps/mobile/lib/domain/models/course_package_manifest.dart`, `package_file_entry.dart`, `package_license.dart`, `package_content_type.dart`, `apps/mobile/lib/data/repositories/package_manifest_repository.dart`, `apps/mobile/lib/data/services/package_validation_service.dart` |
| PKG-CONTRACT-4 | Contracts | `packages/contracts/openapi.yaml` (new paths + error codes), `packages/contracts/schemas/common.yaml` (new error codes) |

**No changes** to: `apps/portal/`, `packages/mobile-theme/`, `packages/design-tokens/`, `packages/map-style/`.

---

## Story Status After Planning

- Story source status: **`in-progress`** (already set — resume from checkpoint)
- Epic-04 wave: 4-1 → `in-progress`; waves 4-2/4-3/4-4 remain `ready-for-dev`
- Plan output: `docs/vnpt-flow/epic-run-epic-04/4-1-plan.md`
- Runner output: `READY_FOR_IMPLEMENTER_DISPATCH` for wave 4-1
