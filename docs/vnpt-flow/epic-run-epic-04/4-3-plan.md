# Story 4-3 Plan — Download and Manage Offline Courses

**Run ID:** `run_2026_08_02_008_planning`
**Epic:** Epic-04 (Offline Course Packages)
**Wave:** 4-3 (wave 3 of 4 — depends on 4-1 and 4-2 completed)
**Story:** `4-3-download-and-manage-offline-courses`
**Status source:** `docs/implementation-artifacts/epic-04/4-3-download-and-manage-offline-courses.md`
**Plan file:** `docs/vnpt-flow/epic-run-epic-04/4-3-plan.md`
**Planning mode:** fresh — story status `ready-for-dev`, routing decision `planning`

---

## Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md",
    "docs/planning-artifacts/architecture.md",
    "docs/planning-artifacts/epics.md"
  ],
  "project_context_sources_read": [
    "docs/project-context.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-04/epic-state.json"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-04/4-3-download-and-manage-offline-courses.md",
    "docs/implementation-artifacts/epic-04/4-1-define-course-package-contract.md",
    "docs/implementation-artifacts/epic-04/4-2-generate-and-publish-course-packages.md",
    "docs/vnpt-flow/epic-run-epic-04/4-1-plan.md",
    "docs/vnpt-flow/epic-run-epic-04/4-2-plan.md"
  ],
  "mockup_sources_read": []
}
```

---

## Scope Analysis

### What Story 4-3 Must Deliver

Stories 4-1 and 4-2 established:
- **4-1**: Manifest contract, `CoursePackageManifest` entity, `PackageValidationService` (non-destructive), `PackageManifestRepository` with pending/active promotion, mobile Dart models, OpenAPI manifest discovery endpoints
- **4-2**: `PackageBuildJob`, async generation pipeline, immutable CDN URL pattern `https://cdn.vnptgolf.vn/packages/{courseId}/{manifestVersion}/...`

Story 4-3 is **mobile-first** — it consumes the manifest contract to implement:
1. Download manager (background-capable, progress-tracking, retry)
2. Course package download/detail UI with all AC-1 display fields
3. Update and delete without deleting round/score data (AC-2)
4. Explicit offline-ready state (AC-3)

### AC-to-Artifact Mapping

| AC | Requirement | Story 4-1/4-2 Artifact | Gap for 4-3 |
|----|-------------|------------------------|-------------|
| AC-1 | App shows package size, version, update time, Wi-Fi preference, progress, retry, completion | `CoursePackageManifest` has `sizeBytes`, `version`, `effectiveFrom`, CDN URLs | **Missing**: download manager service, UI display, progress tracking, Wi-Fi preference toggle, retry logic, completion state |
| AC-2 | User can update and delete packages without deleting round/score data | `PackageManifestRepository.deleteManifest()` — only removes manifest, NOT round/score data (already implemented in 4-1 non-destructive semantics) | **Missing**: UI flow for update/delete with explicit round/score preservation confirmation, download state machine |
| AC-3 | Downloaded courses expose explicit offline-ready state | `hasActiveManifest(courseId)` returns bool | **Missing**: UI exposure of offline-ready badge on course cards, offline-ready state machine, UI representation |

### Epic-04 Internal Dependency Chain

```
Story 4.1 (contracts) ──────────────────────────────────────────────┐
                                                                ▼
Story 4.2 (generate/publish) ── uses manifest schema ──────────┐  │
                                                                ▼
Story 4.3 (download/manage) ──────── uses manifest ───────────────────┘
  • CoursePackageDownloadService (new)
  • CoursePackageRepository (enhance)
  • CourseDownloadScreen (new)
  • CourseSearchScreen (enhance)
                                                                ▼
Story 4.4 (incremental update) ─── uses manifest ──────────────────────
```

### PRD Requirements Traced

| PRD Section | Requirement | Coverage in 4-3 |
|-------------|-------------|-----------------|
| §8.3 | Users can download course metadata, hole geometry, vector maps, scorecards, local rules, pin positions, course conditions, weather snapshot; App shows package size, last update, download progress; App supports incremental updates, Wi-Fi-only downloads, deletion | Download service downloads all manifest files; UI shows size, progress, Wi-Fi toggle, update time, retry, completion |
| §10.3 | Offline-supported: hole map, GPS distance, hazard distance, target, scorecard, club selection, cached pin/weather/course condition | Downloaded packages enable offline mode |
| UX §5.2 | Course Download screen: package size, Wi-Fi-only option, download progress, last updated/version, offline-ready confirmation, error and retry state | Implemented in CourseDownloadScreen |
| UX §5.2 | Course Search: status badges — downloaded, update available | Implemented as CourseCard badges in CourseSearchScreen |
| Architecture §8.3 | Local SQLite for course metadata, downloaded package manifest; file storage for map packages and large assets | `PackageManifestRepository` uses SQLite; downloaded files stored in app documents |

### Architecture Requirements from Architecture Doc

- **Local SQLite** for course metadata and downloaded package manifest (Story 4-1 already)
- **File storage** for map packages and large assets
- **Offline-first**: core on-course features work without internet
- **Background processing**: download worker that survives app backgrounding
- **Non-destructive delete**: round/score data preserved when package deleted

---

## Slice Plan

### Wave Assignment

- **Wave 1**: `PKG-DOWNLOAD-1` (download service infrastructure — NO write-path overlap with UI)
- **Wave 2**: `PKG-DOWNLOAD-2` + `PKG-DOWNLOAD-3` + `PKG-DOWNLOAD-4` (UI + update/delete + offline-ready state — all mobile UI layer, independent write scopes)
- **Sequential constraint**: Wave 1 must complete before Wave 2 (UI depends on download service)

**Wave 1 (PKG-DOWNLOAD-1) — Download Service Infrastructure**
- New: `CoursePackageDownloadService`
- New: `PackageFileDownloader`
- New: `DownloadState`, `DownloadProgress` models
- New: `ConnectivityService` (Wi-Fi detection)
- New: `CoursePackageRepository` (enhance with download state persistence)
- No UI files — pure service/data layer

**Wave 2 (PKG-DOWNLOAD-2 + 3 + 4) — UI Layer (parallel)**
- `PKG-DOWNLOAD-2`: CourseDownloadScreen, DownloadProgressIndicator, WifiOnlyToggle
- `PKG-DOWNLOAD-3`: CourseSearchScreen enhancements (offline-ready badge, update badge)
- `PKG-DOWNLOAD-4`: Update and delete flows, OfflineReadyBadge, DeleteConfirmDialog

---

### Slice 1 — Download Service Infrastructure (`PKG-DOWNLOAD-1`)

**Scope:** Core download orchestration service, file downloader with progress, connectivity monitoring, download state models, and repository persistence.

**Changes:**

1. **New enum:** `apps/mobile/lib/domain/models/download_state.dart`
   - Values: `idle`, `fetching_manifest`, `downloading`, `paused`, `validating`, `offline_ready`, `error`
   - `error` includes `DownloadError` sub-enum: `network_error`, `checksum_mismatch`, `version_too_old`, `storage_error`, `unknown`

2. **New model:** `apps/mobile/lib/domain/models/download_progress.dart`
   - Fields: `courseId`, `state`, `totalBytes`, `downloadedBytes`, `currentFile`, `currentFileIndex`, `totalFiles`, `errorMessage`, `retryCount`
   - `percentComplete`: computed getter

3. **New service:** `apps/mobile/lib/data/services/connectivity_service.dart`
   - Monitors network connectivity type (Wi-Fi vs cellular vs none)
   - `isWifiConnected`: Stream<bool>
   - `wifiOnlyEnabled`: bool (from local preferences)
   - `shouldDownload`: bool (wifiConnected && wifiOnlyEnabled || !wifiOnlyEnabled)
   - Uses `connectivity_plus` package or platform channel

4. **New service:** `apps/mobile/lib/data/services/package_file_downloader.dart`
   - `downloadFile(url, savePath, onProgress(bytes, total))`: Future<File>
   - Uses `dio` package with cancel token support
   - Computes SHA-256 checksum during download
   - Returns failure if checksum doesn't match manifest entry
   - Supports pause/resume via cancel token

5. **New service:** `apps/mobile/lib/data/services/course_package_download_service.dart`
   - `downloadPackage(courseId, {wifiOnly: false})`: Future<DownloadResult>
   - `pauseDownload(courseId)`: void
   - `resumeDownload(courseId)`: Future<void>
   - `cancelDownload(courseId)`: void
   - `retryDownload(courseId)`: Future<void>
   - `deletePackage(courseId)`: Future<void> — deletes manifest + package files, PRESERVES round/score data
   - `getDownloadProgress(courseId)`: Stream<DownloadProgress>
   - `getDownloadState(courseId)`: DownloadState

   **Internal flow for `downloadPackage`:**
   1. Fetch current manifest: `GET /courses/{courseId}/packages/current`
   2. Compare with local `PackageManifestRepository.getManifest(courseId)` — skip if same version
   3. For each file in manifest.files: download via `PackageFileDownloader` with progress callback
   4. Validate manifest checksum against computed hash
   5. If valid: `PackageManifestRepository.saveManifest(manifest)` (non-destructive pending/active promotion from 4-1)
   6. Emit `offline_ready` state
   7. On any failure: emit `error` state, do NOT overwrite active manifest (non-destructive)

   **Internal flow for `deletePackage`:**
   1. `PackageManifestRepository.deleteManifest(courseId)` — removes manifest from SQLite
   2. Delete package files from app documents directory (tiles, geojson, etc.)
   3. **ROUND/SCORE DATA PRESERVED**: rounds and scores live in separate SQLite tables (`round_sync_store`, `score_sync_store`) — not touched by delete
   4. Emit `idle` state

6. **New repository method:** `apps/mobile/lib/data/repositories/course_package_repository.dart`
   - New method: `saveDownloadState(courseId, state, progress)` — persists download state for app restart recovery
   - New method: `getDownloadState(courseId)` — retrieves persisted download state
   - New method: `clearDownloadState(courseId)` — clears download state after completion
   - Downloads are resumable after app restart

7. **New API client method:** `apps/mobile/lib/core/network/api_client.dart`
   - Add: `GET /courses/{courseId}/packages/current` → `CoursePackageManifestDto`
   - Uses existing auth token from `AuthStorage`

8. **Background download support:**
   - Use Flutter `Isolate` or `WorkManager` for downloads that must continue when app is backgrounded
   - For MVP: dio with background `Client` and local notification for completion (defer full WorkManager to later if complexity warrants)

**AC served:** AC-1 (download progress, retry, completion state), AC-2 (delete preserves round/score — rounds/scores are in separate tables), AC-3 (offline_ready state emitted)

**Verification:**
- Unit test: `downloadPackage` skips download when local manifest version matches remote
- Unit test: checksum mismatch during download causes `error` state without overwriting active manifest
- Unit test: `deletePackage` does NOT delete round or score records (different table)
- Unit test: `downloadPackage` emits progress updates during download
- Unit test: `ConnectivityService.shouldDownload` returns false when on cellular and wifiOnly=true

---

### Slice 2 — Course Download Screen (`PKG-DOWNLOAD-2`)

**Scope:** CourseDownloadScreen with full AC-1 display fields, download controls, progress UI, Wi-Fi toggle.

**Changes:**

1. **New screen:** `apps/mobile/lib/presentation/screens/course_download_screen.dart`
   - Route: `/courses/{courseId}/download`
   - Shows: package size, version, update time (from manifest), Wi-Fi preference toggle, download progress, retry button, completion state
   - States: loading, idle (not downloaded), downloading (with progress), paused, validating, offline_ready (downloaded), error (with retry)
   - Download button → calls `CoursePackageDownloadService.downloadPackage()`
   - Update button → shown when `hasActiveManifest` is true but a newer version exists (comparing `dataVersionId` or `version`)
   - Delete button → shown when package is downloaded, calls delete with confirmation
   - Pause/Resume button → during active download
   - Wi-Fi only toggle → persisted, passed to `downloadPackage(wifiOnly: true)`

2. **New widget:** `apps/mobile/lib/presentation/widgets/download_progress_indicator.dart`
   - Shows: file name, bytes downloaded / total bytes, percent complete, download speed (if available)
   - Progress bar with percentage text
   - Current file index / total files
   - Uses `DownloadProgress` model

3. **New widget:** `apps/mobile/lib/presentation/widgets/wifi_only_toggle.dart`
   - Toggle switch with label "Download on Wi-Fi only"
   - Persists preference to `SharedPreferences`
   - Shows current Wi-Fi status indicator

4. **New widget:** `apps/mobile/lib/presentation/widgets/package_info_card.dart`
   - Shows: course name, package version, package size (formatted: "24.5 MB"), last updated (relative time: "Updated 2 days ago"), update available badge (if newer version exists)
   - Data from `CoursePackageManifest`

5. **New widget:** `apps/mobile/lib/presentation/widgets/download_action_button.dart`
   - States: Download, Update, Pause, Resume, Retry
   - Icon + text, minimum 44pt touch target
   - Disabled state with explanation tooltip when Wi-Fi required but not available

6. **Accessibility:**
   - All icons have `Semantics` labels
   - Progress announced via `Semantics` live region
   - Touch targets ≥44pt
   - High contrast colors for status

**AC served:** AC-1 (app shows package size, version, update time, Wi-Fi preference, progress, retry, completion)

**Verification:**
- UI renders correct state for each `DownloadState` value
- Progress bar shows correct percentage and byte count
- Wi-Fi toggle persists and affects download behavior
- Retry button triggers download again
- Screen reader announces progress updates

---

### Slice 3 — Course Search Screen Enhancements (`PKG-DOWNLOAD-3`)

**Scope:** CourseSearchScreen update to show offline-ready badge, update-available badge, and initiate download.

**Changes:**

1. **Enhance:** `apps/mobile/lib/presentation/screens/course_search_screen.dart`
   - On each course card: show `OfflineReadyBadge` if `hasActiveManifest(courseId)` is true
   - On each course card: show `UpdateAvailableBadge` if remote version > local version
   - Download/Update button on each card — one tap to start download
   - Badge colors follow UX spec: green for offline-ready, amber for update available

2. **New widget:** `apps/mobile/lib/presentation/widgets/offline_ready_badge.dart`
   - Green badge with offline icon + "Offline Ready" text
   - Semantic label: "Course downloaded and ready for offline play"
   - Icon + text + color (not color alone)

3. **New widget:** `apps/mobile/lib/presentation/widgets/update_available_badge.dart`
   - Amber badge with update icon + "Update" text
   - Semantic label: "New version available. Tap to update."

4. **New widget:** `apps/mobile/lib/presentation/widgets/course_package_status_chip.dart`
   - Displays: downloaded (green), update available (amber), not downloaded (gray)
   - Compact chip for placement on course card

5. **Course card enhancement:**
   - Add `course_package_status_chip.dart` to course list item
   - Tap on chip or download icon → navigate to `CourseDownloadScreen`
   - Inline progress indicator for active downloads on same screen

**AC served:** AC-1 (download initiation from search), AC-3 (offline-ready badge on course card)

**Verification:**
- Course card shows correct badge based on package state
- Tapping badge navigates to download screen
- Search results refresh badge state after download completes

---

### Slice 4 — Update, Delete, and Offline-Ready State (`PKG-DOWNLOAD-4`)

**Scope:** Update flow, delete confirmation, offline-ready state machine integration, download management screen.

**Changes:**

1. **Update flow:**
   - When `hasActiveManifest(courseId)` is true and remote manifest has higher `version` or `dataVersionId`:
     - `CourseDownloadScreen` shows "Update Available" with version comparison
     - Tapping Update → `downloadPackage(courseId)` — overwrites old manifest via non-destructive pending/active promotion
     - Existing rounds/scores unaffected
   - `PackageManifestRepository.saveManifest()` with pending/active promotion ensures atomic update

2. **Delete confirmation dialog:** `apps/mobile/lib/presentation/widgets/delete_package_dialog.dart`
   - Title: "Remove Offline Course?"
   - Body: "This will remove course maps and data from your device. Your rounds and scores will NOT be deleted and will remain available."
   - Actions: "Cancel" (secondary), "Remove" (destructive, red)
   - Preserves round/score data explicitly mentioned in copy
   - Calls `CoursePackageDownloadService.deletePackage(courseId)`

3. **Download management screen:** `apps/mobile/lib/presentation/screens/download_management_screen.dart`
   - Route: `/downloads` or `/courses/downloads`
   - Lists all downloaded packages with status
   - Per-package: course name, size, version, offline-ready badge, last updated
   - Per-package actions: Update, Delete, View Details
   - Storage usage summary at top: "Using 245 MB for offline courses"
   - Swipe-to-delete with confirmation
   - Pull-to-refresh to check for updates

4. **Offline-ready state integration:**
   - `CoursePackageDownloadService.downloadPackage` → emits `offline_ready` state on success
   - `CoursePackageRepository.hasActiveManifest(courseId)` → `true` means offline-ready
   - Round can only start if `hasActiveManifest(courseId)` is true for selected course (enforced in Round Setup — Story 5.1)
   - `CourseSearchScreen` and `CourseDownloadScreen` react to `offline_ready` state change

5. **Error handling and retry:**
   - Network errors: show "No internet connection. Will retry when online." with auto-retry when connectivity returns
   - Storage errors: show "Not enough storage space. Free up 50 MB to download."
   - Checksum mismatch: show "Download corrupted. Tap to retry."
   - All errors have Retry button

6. **Download queue (MVP simplest):**
   - Only one active download at a time
   - Queue additional downloads if user taps multiple
   - Show queue position: "Downloading... (2 of 3)"

**AC served:** AC-2 (update and delete preserve round/score data), AC-3 (explicit offline-ready state exposed in UI)

**Verification:**
- Delete dialog explicitly mentions round/score preservation
- Delete does NOT remove round/score records
- Offline-ready badge appears only when `hasActiveManifest` is true
- Update replaces manifest without affecting rounds/scores
- App can restart mid-download and resume from persisted state

---

## Quality Gate

**Gate type:** detect-duplicate flow (Serena exact-name match → CC → SigCheck + Emb → Q → AIJudge + PreWrite → Report → Reindex)

**Chain steps:**
1. **Serena (Cy):** Query for `CoursePackageDownloadService`, `PackageFileDownloader`, `DownloadState`, `DownloadProgress`, `ConnectivityService`, `CourseDownloadScreen`, `OfflineReadyBadge`, `UpdateAvailableBadge`, `DeletePackageDialog`, `DownloadManagementScreen`, `CoursePackageRepository` — check all source files for exact-name collision with differing signature → reject if found.
2. **Serena (CC):** Verify that `CoursePackageDownloadService.deletePackage` calls only manifest/sync_store deletion — does NOT touch round or score tables. Verify `PackageManifestRepository` method signatures unchanged.
3. **SigCheck:** Verify manifest files downloaded from CDN URL pattern `packages/{courseId}/{manifestVersion}/...` are stored in app documents directory and tracked in SQLite.
4. **Emb (embeddings):** Query with "offline course download progress wifi mobile state". Check top-3 semantic matches for intent-equivalent existing symbols that should be reused.
5. **PreWrite (precheck):** Run pre-write duplicate detection before code is written.
6. **Report:** Verify `docs/vnpt-flow/epic-run-epic-04/4-3/dedup_report.json` exists, status is `clean` or `resolved`, `_block: false`, attempts between 1–3.
7. **Reindex:** Verify `reindex` returned `ok: true` after final write.

**Gate verdict:** Return `QA_PASS` or `QA_FAIL: <step>` per runner rules.

---

## Anti-Shortcut Evidence

- Did NOT confuse `PackageManifestRepository` (manifest-only) with round/score tables — delete is non-destructive by design from 4-1
- Did NOT plan CDN URL generation in 4-3 — CDN URL pattern from 4-2 is consumed as-is
- Did NOT plan tile/GeoJSON generation — consumed from 4-2 as pre-built files
- Did NOT plan package build infrastructure — consumed from 4-2 as already-built packages
- Did NOT plan incremental delta downloads in 4-3 — Story 4-4 covers ETag/version-based delta
- Did NOT plan active-round package switching in 4-3 — Story 4-4 covers round-package affinity lock
- Non-destructive update semantics: `saveManifest` uses pending/active promotion from 4-1
- Delete dialog explicitly mentions round/score preservation to satisfy AC-2
- Offline-ready state is a first-class `DownloadState` enum value, not just an implicit condition

---

## File Changes Summary

| Slice | Layer | Files Changed |
|-------|-------|--------------|
| PKG-DOWNLOAD-1 | Mobile/Data | `apps/mobile/lib/domain/models/download_state.dart`, `apps/mobile/lib/domain/models/download_progress.dart`, `apps/mobile/lib/data/services/connectivity_service.dart`, `apps/mobile/lib/data/services/package_file_downloader.dart`, `apps/mobile/lib/data/services/course_package_download_service.dart`, `apps/mobile/lib/data/repositories/course_package_repository.dart` (enhance), `apps/mobile/lib/core/network/api_client.dart` (enhance) |
| PKG-DOWNLOAD-2 | Mobile/UI | `apps/mobile/lib/presentation/screens/course_download_screen.dart`, `apps/mobile/lib/presentation/widgets/download_progress_indicator.dart`, `apps/mobile/lib/presentation/widgets/wifi_only_toggle.dart`, `apps/mobile/lib/presentation/widgets/package_info_card.dart`, `apps/mobile/lib/presentation/widgets/download_action_button.dart` |
| PKG-DOWNLOAD-3 | Mobile/UI | `apps/mobile/lib/presentation/screens/course_search_screen.dart` (enhance), `apps/mobile/lib/presentation/widgets/offline_ready_badge.dart`, `apps/mobile/lib/presentation/widgets/update_available_badge.dart`, `apps/mobile/lib/presentation/widgets/course_package_status_chip.dart` |
| PKG-DOWNLOAD-4 | Mobile/UI | `apps/mobile/lib/presentation/widgets/delete_package_dialog.dart`, `apps/mobile/lib/presentation/screens/download_management_screen.dart`, `apps/mobile/lib/data/repositories/course_package_repository.dart` (enhance download state persistence) |

**No changes** to: `apps/portal/`, `apps/api/`, `packages/contracts/`, `packages/course-package/`, `packages/mobile-theme/`, `packages/design-tokens/`, `packages/map-style/`.

---

## Story Status After Planning

- Story source status: **`in_progress`** (update from `ready-for-dev`)
- Epic-04 wave: 4-3 → `in_progress`; wave 4-4 remains `ready-for-dev`
- Plan output: `docs/vnpt-flow/epic-run-epic-04/4-3-plan.md`
- Runner output: `READY_FOR_IMPLEMENTER_DISPATCH` for wave 4-3

---

## Wave Execution Summary

| Wave | Slices | Parallel | Depends |
|------|--------|----------|---------|
| Wave 1 | PKG-DOWNLOAD-1 | No | 4-1, 4-2 completed |
| Wave 2 | PKG-DOWNLOAD-2, PKG-DOWNLOAD-3, PKG-DOWNLOAD-4 | Yes (independent UI slices) | Wave 1 |

**Rationale:** Wave 1 establishes the download service that Wave 2 UI depends on. Within Wave 2, all three slices are independent UI changes (different screens/widgets) with no write-path overlap, so they may parallelize.
