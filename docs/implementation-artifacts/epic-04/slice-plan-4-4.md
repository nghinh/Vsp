# Slice Plan — Story 4.4: Incrementally Update Course Data

## Story Metadata

| Field | Value |
|-------|-------|
| Story | 4.4 |
| Epic | epic-04 — Course Package Distribution |
| Title | Incrementally Update Course Data |
| Status | `in-progress` |
| Phase | MVP 1 |
| User Story | As a golfer, I want efficient package updates so that fresh course data does not require wasteful full downloads. |

## Context Evidence

| Source | Evidence |
|--------|----------|
| PRD §8.3 | "App supports incremental updates, Wi-Fi-only downloads, deletion, and local persistence" |
| Architecture §9.2 | "Mobile detects available version and downloads incrementally" |
| Architecture §7.3 | Append-versioned model: draft→published, rollback creates new published version |
| UX §5.2 | "Course status badges: downloaded, update available" |
| Story 4.1 | Manifest contract with `files[]`, per-file checksums, version, ETag support in OpenAPI |
| Story 4.2 | Package publishing generates versioned, immutable package URLs |
| Story 4.3 (in-progress) | Full download management — foundation for update flow |
| OpenAPI | `/courses/{courseId}/packages/current` with `If-None-Match` ETag, 304 Not Modified |

## Dependencies

- **Hard**: Story 4.3 (in-progress) — mobile download infrastructure (download/resume/delete) required before mobile incremental update slices
- **Soft**: Story 4.1 (done) — manifest contract, `CoursePackageManifest`, `PackageFileEntry` models
- **Soft**: Story 4.2 (done) — package publishing, versioned URLs

## Acceptance Criteria

| AC | Description | Verification |
|----|-------------|--------------|
| AC-1 | Client checks version/ETag and downloads only required changed artifacts where supported | Mobile: ETag round-trip + file-diff delta computed; Backend: conditional fetch returns 304 |
| AC-2 | Update is atomic and rolls back to last valid version on failure | Mobile: `savePendingManifest` + `promotePendingToActive`/`discardPending` pattern applied to update flow |
| AC-3 | Active rounds are not silently switched to a new package version | Mobile: active-round guard blocks promotion during active round |

## Slice Plan

### Slice 1 — INC-BACKEND: ETag and Conditional Fetch Enforcement
**Owner**: Backend
**Phase**: Backend-first (independent of 4.3)

Ensures the backend properly implements conditional fetch semantics required for incremental updates:

1. **CONTRACT**: OpenAPI already has `If-None-Match` / `ETag` on `/courses/{courseId}/packages/current`. Verify `PackageService` returns `ETag` header computed as SHA-256 of manifest version string (`courseId + version + generatedAt`).
2. **CONTROLLER**: `PackageController.getCurrentPackageManifest()` — read `If-None-Match` header, compare to current ETag, return `304 Not Modified` when equal (skip body).
3. **CONTROLLER**: `/courses/{courseId}/packages/{version}/files` — returns per-file metadata (path, checksum, sizeBytes, contentType) enabling mobile to diff.
4. **NO REGRESSION**: Existing 200 responses unchanged; 304 only when If-None-Match matches.

**Acceptance**: `curl -H "If-None-Match: <current-etag>"` → 304 with empty body.

---

### Slice 2 — INC-MOBILE-VC: Version Check Service
**Owner**: Mobile
**Depends**: Slice 1 (backend ETag support)

Mobile client checks for available package updates:

1. **PackageUpdateCheckService**: New service that:
   - Reads active manifest from `PackageManifestRepository.getActiveManifest(courseId)`
   - Calls `GET /courses/{courseId}/packages/current` with `If-None-Match: <manifest-etag>` header
   - Returns `UpdateAvailable(manifest)` on 200, `UpdateNotAvailable` on 304
   - Parses new `CoursePackageManifest` from response
2. **ETag persistence**: Store ETag alongside manifest in SQLite (add `active_etag` column to `package_manifest` table)
3. **CourseUpdateState model**: `noUpdate`, `updateAvailable(manifest)`, `checkFailed(error)`
4. **Error handling**: network failure → `checkFailed` with retry, 404 → treat as no active package

**Acceptance**: When server has new version, `UpdateAvailable` returned with new manifest; when server has same version, `UpdateNotAvailable`.

---

### Slice 3 — INC-MOBILE-DIFF: Delta File Computation
**Owner**: Mobile
**Depends**: Slice 2

Determines which files need downloading (delta):

1. **PackageDeltaService**: Given `oldManifest` and `newManifest`:
   - Compare `version` field — if identical, no update possible
   - Compare each `PackageFileEntry.path + checksum` pair
   - Files where checksum differs → added or changed → need download
   - Files in `oldManifest.files` but not in `newManifest.files` → deleted locally (clean up)
   - Files in both with same checksum → no-op (reuse cached)
2. **PackageDelta model**: `{ toDownload: PackageFileEntry[], toDelete: String[], unchanged: Int }`
3. **UX**: Show delta summary before downloading (e.g., "3 of 12 files updated, 18 MB")

**Acceptance**: Given two manifests, delta correctly identifies changed, added, deleted, and unchanged files.

---

### Slice 4 — INC-MOBILE-DOWNLOAD: Delta Download and Verification
**Owner**: Mobile
**Depends**: Slice 3 + Story 4.3 (download infrastructure)

Downloads only delta files from new manifest URLs:

1. **Reuse Story 4.3 download infrastructure**: `CourseDownloadRepository` / download worker from 4.3 for HTTP download + resume + progress
2. **File-level download**: For each `toDownload` entry, download from `tilesUrl`/`geoJsonUrl`/etc. (manifest-level URLs) or construct per-file URL from CDN base path + file path
3. **Per-file checksum verification**: After each file download, compute SHA-256 and compare to `PackageFileEntry.checksum`; reject file on mismatch → fail update atomically
4. **Progress reporting**: Per-file progress, cumulative delta progress
5. **Wi-Fi enforcement**: Check connectivity before downloading if user has Wi-Fi-only preference

**Note**: If per-file URLs are not directly constructible from manifest URLs, the CDN must serve files individually. Backend (Slice 1) must ensure `/courses/{courseId}/packages/{version}/files/{filePath}` endpoint exists or use signed CDN URLs with per-file paths.

**Acceptance**: Only delta files downloaded; each file verified against its checksum; partial failure does not corrupt active package.

---

### Slice 5 — INC-MOBILE-ATOMIC: Atomic Update with Rollback
**Owner**: Mobile
**Depends**: Slice 4

Applies the delta update atomically using existing pending/active promotion pattern:

1. **Non-destructive update flow** (mirrors Story 4.1 AC-3 pattern):
   - Save new manifest as `pendingManifest` via `savePendingManifest(newManifest)`
   - Save all downloaded files to pending storage (temp directory or pending_ files prefix)
   - Run `PackageValidationService.validateFileInventory()` on pending files
   - If validation passes → `promotePendingToActive(courseId)` → swap pending→active, clear pending
   - If validation fails → `discardPending(courseId)` → delete pending files, active unchanged
2. **Failure recovery**: On any exception during download or promotion, `discardPending()` called
3. **Active round guard**: Before promotion, check if active round exists for this courseId (see Slice 6)
4. **User notification**: Show success/failure state; on failure show "Update failed — using current version"

**Acceptance**: After failed update, active manifest and files are unchanged; after successful update, new manifest + files are active.

---

### Slice 6 — INC-MOBILE-GUARD: Active Round Package Version Guard
**Owner**: Mobile
**Depends**: Slice 5 (part of atomic flow)

Prevents silently switching package version during an active round (AC-3):

1. **RoundPackageVersion model**: Persisted when round starts — stores `courseId + packageVersion` at round start
2. **Guard logic**: Before `promotePendingToActive()`, query active rounds for this `courseId`:
   - If no active round → allow promotion
   - If active round exists and its `startedWithVersion != currentActiveVersion` → block promotion, show UI: "Update available but cannot apply during active round. Update will apply after this round."
3. **Deferred update queue**: When promotion blocked, add to `deferredUpdates` table; process after round completes (in `RoundSummaryScreen` or next app launch)
4. **Round start binding**: On round start, store `activeManifestVersion` in round record

**Acceptance**: During active round, package update does not promote; UI clearly shows update is pending; after round, update is applied.

---

### Slice 7 — INC-MOBILE-UI: Update UX
**Owner**: Mobile (UI)
**Depends**: Slices 2, 3, 5, 6

Course download/update UI for incremental updates:

1. **Course detail screen**: Show "Update available" badge when `PackageUpdateCheckService` returns `UpdateAvailable`
2. **Update bottom sheet**: Shows delta summary (files/size), "Update Now" (Wi-Fi), "Later" actions
3. **Progress UI**: During delta download — show "Updating course… X of Y files" with progress bar
4. **Completion UI**: "Course updated to v{version}" toast/banner; if blocked by round → "Update saved, will apply after round"
5. **Offline indicator**: If offline when update available, prompt when back online

**Acceptance**: User can see, trigger, and understand incremental update flow; glanceable offline/update states per UX spec.

---

### Slice 8 — INC-TEST: Automated Tests
**Owner**: All
**Depends**: Slices 1–7

Comprehensive test coverage:

1. **Backend**: ETag generation, 304 response, file inventory endpoint
2. **Mobile unit**: `PackageDeltaService` delta computation, `PackageUpdateCheckService` state machine, rollback semantics
3. **Mobile integration**: Full update flow: check → diff → download → verify → promote (mock HTTP + filesystem)
4. **Round guard**: Verify promotion blocked during active round
5. **Rollback**: Verify active unchanged after failed update

## Slice Execution Order

| Order | Slice | Dependencies | Can Run |
|-------|-------|-------------|---------|
| 1 | INC-BACKEND | None | ✅ Parallel |
| 2 | INC-MOBILE-VC | Backend contract | ✅ Parallel |
| 3 | INC-MOBILE-DIFF | 2 | After 2 |
| 4 | INC-MOBILE-DOWNLOAD | 3 + 4.3 infra | After 3 + 4.3 done |
| 5 | INC-MOBILE-ATOMIC | 4 | After 4 |
| 6 | INC-MOBILE-GUARD | 5 (integrated) | After 4 |
| 7 | INC-MOBILE-UI | 2,3,5,6 | After 2 |
| 8 | INC-TEST | 1–7 | After all impl |

## Wave Planning

**Wave A (Backend + Mobile Version Check — parallel)**:
- Slice 1: INC-BACKEND
- Slice 2: INC-MOBILE-VC

**Wave B (Mobile Delta + Download — sequential)**:
- Slice 3: INC-MOBILE-DIFF (after Slice 2)
- Slice 4: INC-MOBILE-DOWNLOAD (after Slice 3 + Story 4.3)

**Wave C (Mobile Atomic + Guard — integrated)**:
- Slice 5: INC-MOBILE-ATOMIC
- Slice 6: INC-MOBILE-GUARD (integrated into Slice 5)

**Wave D (UI + Tests — final)**:
- Slice 7: INC-MOBILE-UI
- Slice 8: INC-TEST

## Technical Notes

- **ETag computation** (backend): SHA-256 of `courseId + ";" + version + ";" + generatedAt.toIso8601String()` — stable across requests
- **Per-file URL pattern**: Assume CDN serves files at `https://cdn.vsp.vn/packages/{courseId}/{version}/{relativePath}` — verify with 4.2 CDN path pattern
- **Rollback is already implemented** in `PackageManifestRepository.savePendingManifest/promotePendingToActive/discardPending` — reuses same pattern for file-level pending storage
- **No new contracts needed**: Uses existing OpenAPI paths + manifest schema from Story 4.1
- **Active round check**: Query `round_state` or `active_round` table for `courseId` with `status != completed`

## Verification Checklist

- [ ] ETag round-trip: 304 returned when client has latest
- [ ] Delta correctly computed: only changed files identified
- [ ] Failed update leaves active package intact
- [ ] Active round blocks version promotion
- [ ] Update deferred during round applies after round ends
- [ ] UI shows correct update/pending/offline states
- [ ] All tests pass
