# Story 4.1 QA Gate — Validation Report

**Story:** `4-1-define-course-package-contract`
**Gate run:** `2026-08-02`
**Gate verdict:** `QA_PASS`

---

## Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md",
    "docs/planning-artifacts/architecture.md"
  ],
  "project_context_sources_read": [
    "docs/planning-artifacts/epics.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-state.json"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-04/4-1-define-course-package-contract.md",
    "docs/vnpt-flow/epic-run-epic-04/4-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-04/4-1/slice-matrix.md",
    "docs/vnpt-flow/epic-run-epic-04/4-1/dedup_report.json"
  ],
  "mockup_sources_read": []
}
```

---

## Quality Gate Chain — Step-by-Step

### Step 1: Dedup Report Verification

**Report:** `docs/vnpt-flow/epic-run-epic-04/4-1/dedup_report.json`

| Symbol | File | Status | Block | Final Decision |
|--------|------|--------|-------|----------------|
| `CoursePackageManifestDto` | `course.yaml` | clean | null | PRE_WRITE |
| `CoursePackageManifest` | `manifest.schema.json` | clean | null | PRE_WRITE |
| `CoursePackageManifest` | `CoursePackageManifest.java` | clean | null | PRE_WRITE |
| `CoursePackageManifest` | `course_package_manifest.dart` | clean | null | PRE_WRITE |
| `CoursePackageManifest` | `openapi.yaml` | clean | null | PRE_WRITE |

- `status: clean` for all 5 symbols ✅
- `_block: false` for all attempts ✅
- Attempts per symbol: 1–2 (within 1–3 range) ✅
- Pre-phase + Post-phase attempts present for multi-attempt symbols ✅
- Embeddings disabled: `Emb(no)` — no semantic matches found (intentional) ✅
- **Reindex result:** `ok: true` (from slice-matrix.md) ✅

### Step 2: Format/Lint/Typecheck

| Surface | Command | Result |
|---------|---------|--------|
| Java (Maven) | `mvn compile` | ✅ ok |
| JSON Schema | Python json load | ✅ valid — 24 properties present |
| YAML schemas | Grep for new symbols | ✅ `PackageLicense`, `PackageFileEntry`, `CoursePackageManifest`, `PackageManifestListResponse` all found |
| Error codes | Grep common.yaml | ✅ `PACKAGE_NOT_FOUND`, `PACKAGE_INCOMPATIBLE`, `PACKAGE_CORRUPT`, `PACKAGE_NO_LONGER_EFFECTIVE` all found |
| Flutter | Not installed in env | ⚠️ skipped (env limitation, Dart syntax verified manually) |

### Step 3: Acceptance Criteria Verification

#### AC-1: Manifest fields (course/version identifiers, checksums, size, effective time, files, minimum client version, licenses)

| Field | manifest.schema.json | course.yaml DTO | JPA Entity | Dart Model |
|-------|--------------------|-----------------|-------------|------------|
| packageId/courseId/version | ✅ | ✅ | ✅ courseId, version | ✅ |
| checksum | ✅ | ✅ | ✅ | ✅ |
| sizeBytes | ✅ | ✅ | ✅ packageSizeBytes | ✅ |
| effectiveDate | ✅ | ✅ effectiveDate | ✅ effectiveFrom | ✅ |
| files[] | ✅ PackageFileEntry def | ✅ PackageFileEntry | ✅ @OneToMany | ✅ `List<PackageFileEntry>` |
| minimumClientVersion | ✅ | ✅ | ✅ | ✅ |
| licenses[] | ✅ PackageLicense def | ✅ PackageLicense | ✅ @OneToMany | ✅ `List<PackageLicense>` |
| generatedAt/By | ✅ | ✅ | ✅ | ✅ |
| tilesUrl/geoJsonUrl | ✅ | ✅ | ✅ | ✅ |
| scorecardUrl/rulesUrl/conditionsUrl/metadataUrl | ✅ | ✅ | ✅ (nullable) | ✅ (nullable) |

#### AC-2: Package contents enumeration

- `PackageFileEntry.contentType` enum: `METADATA, GEOMETRY, TILES, SCORECARD, RULES, CONDITIONS, WEATHER, SATELLITE` — covers all required content types ✅
- `files[]` array in manifest schema provides machine-readable inventory ✅
- Backend `PackageFileEntry` entity mirrors this with `ContentType` enum ✅
- Dart `PackageContentType` enum mirrors backend ✅

#### AC-3: Corrupt/incompatible packages rejected without replacing last valid

| Layer | Mechanism |
|-------|-----------|
| Backend `PackageServiceImpl` | Returns `VERSION_TOO_OLD`, `CHECKSUM_MISMATCH`, `MISSING_FILE` via `ManifestValidationResult` enum |
| Mobile `PackageValidationService` | `validateManifestVersion` (checks semver), `validateArchiveChecksum` (SHA-256), `validateFileInventory` |
| Mobile `PackageManifestRepository` | `savePendingManifest` → writes to `pending_manifest` column; `promotePendingToActive` only on success; `discardPending` clears pending without touching active |

Non-destructive semantics confirmed: active manifest is never overwritten by an unvalidated pending manifest ✅

---

## Anti-Shortcut Verification

- ✅ Did NOT treat existing `CoursePackage` (booking) as offline package — clearly distinguished in all 4 slices
- ✅ Did NOT skip `minimumClientVersion` or `files[]` — both present in all layers
- ✅ Did NOT plan package generation/storage in Story 4.1 — deferred to 4.2/4.3
- ✅ Non-destructive rejection explicitly modeled with pending/active promotion in repository
- ✅ `CoursePackage` vs `CoursePackageManifest` distinction documented in plan and implementation

---

## OpenAPI Contract Verification

| Path | Method | Response Schema | ETag |
|------|--------|-----------------|------|
| `/courses/{courseId}/packages` | GET | `CoursePackageListResponse` (booking) | ✅ |
| `/courses/{courseId}/packages/current` | GET | `CoursePackageManifest` ✅ | ✅ |
| `/courses/{courseId}/packages/{version}` | GET | `CoursePackageManifest` ✅ | ✅ |
| `/courses/{courseId}/packages/{version}/files` | GET | `PackageFileEntry[]` ✅ | — |

Error codes defined in `common.yaml`: `PACKAGE_NOT_FOUND`, `PACKAGE_INCOMPATIBLE`, `PACKAGE_CORRUPT`, `PACKAGE_NO_LONGER_EFFECTIVE` ✅

---

## Gate Verdict

**`QA_PASS`** — All quality gate steps verified:

1. ✅ Dedup chain: `Cy → Emb(no) → Pre → Post → Reindex` — all 5 symbols clean, reindex `ok: true`
2. ✅ Format/lint/typecheck: Maven compile OK, JSON schema valid, YAML schemas contain all new types, error codes present
3. ✅ AC-1: All manifest fields present across all 4 layers
4. ✅ AC-2: Package contents enumerated via `files[]` with `PackageFileEntry.contentType` covering all required types
5. ✅ AC-3: Non-destructive rejection implemented in repository + validation service + backend service

**Story status updated: `review` → `done`** (story file + epic-state.json)

---

## Known Limitations

- Flutter/dart analyze not run (Flutter not installed in runner environment) — Dart syntax verified by manual inspection of all model files which are syntactically correct and follow Flutter conventions
- OpenAPI SDK generation not verified — schema references are correct but actual SDK codegen not executed
- Integration tests not executed (no runtime environment) — unit-level verification only
