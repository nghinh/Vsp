---
story: "4.4"
epic: 4
title: "Incrementally Update Course Data"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 4.4: Incrementally Update Course Data

## User Story

As a golfer, I want efficient package updates so that fresh course data does not require wasteful full downloads.

## Acceptance Criteria

- Client checks version/ETag and downloads only required changed artifacts where supported.
- Update is atomic and rolls back to last valid version on failure.
- Active rounds are not silently switched to a new package version.

## Tasks and Subtasks

- [x] Confirm the incrementally update course data scope against the referenced PRD, architecture, UX, and epic requirements.
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

- Story 4.3 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 4.4 and Epic 4
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `4-4-incrementally-update-course-data`

## Dev Agent Record

### Implementation Plan

Implemented 8 slices across 4 waves as defined in `slice-plan-4-4.md`:

**Wave A (parallel)**:
- **INC-BACKEND**: Created `PackageController.java` with ETag computation (SHA-256 of courseId+version+generatedAt), conditional fetch (304 Not Modified), and per-file metadata endpoint
- **INC-MOBILE-VC**: Created `PackageUpdateCheckService` with ETag round-trip, `CourseUpdateState` model, extended `PackageManifestRepository` with `active_etag`/`pending_etag` columns, extended `ApiClient` with header support and `getRaw` for raw response access

**Wave B (sequential)**:
- **INC-MOBILE-DIFF**: Created `PackageDeltaService` with path+checksum comparison, `PackageDelta` model with toDownload/toDelete/unchangedCount
- **INC-MOBILE-DOWNLOAD**: Created `CoursePackageUpdateService` for delta downloads with per-file checksum verification, Wi-Fi enforcement, progress reporting

**Wave C (integrated)**:
- **INC-MOBILE-ATOMIC**: Non-destructive update flow via existing `savePendingManifest`/`promotePendingToActive`/`discardPending` pattern
- **INC-MOBILE-GUARD**: Created `ActiveRoundGuard` service with `round_package_version` and `deferred_updates` SQLite tables, `GuardResult` sealed class

**Wave D (final)**:
- **INC-MOBILE-UI**: Created `UpdateBottomSheet` with delta summary, Update Now/Later actions; existing `UpdateAvailableBadge` and `PackageInfoCard` reused

### Completion Notes

- All 8 slices passed duplicate detection gates (pre-write and post-write) with clean status
- ETag computation: SHA-256(courseId + ";" + version + ";" + generatedAt.toIso8601String())
- Non-destructive update flow mirrors Story 4.1 pattern: pending→active promotion with rollback on failure
- Active round guard blocks promotion when round started with different package version
- Deferred updates queued in SQLite for processing after round completes
- UI follows UX spec for glanceability, one-hand/two-tap flows
- Reindex skipped due to gitnexus FTS index inconsistency (pre-existing issue)

### File List

**Backend (INC-BACKEND)**:
- `apps/api/src/main/java/vnpt/vsp/module/package/PackageController.java` — ETag/conditional fetch controller

**Mobile Models (INC-MOBILE-VC, INC-MOBILE-DIFF, INC-MOBILE-GUARD)**:
- `apps/mobile/lib/domain/models/course_update_state.dart` — UpdateAvailable/UpdateNotAvailable/UpdateCheckFailed
- `apps/mobile/lib/domain/models/package_delta.dart` — Delta with toDownload/toDelete/unchangedCount
- `apps/mobile/lib/domain/models/round_package_version.dart` — Round start package version binding
- `apps/mobile/lib/domain/models/deferred_update.dart` — Deferred update model

**Mobile Services (INC-MOBILE-VC, INC-MOBILE-DIFF, INC-MOBILE-DOWNLOAD, INC-MOBILE-GUARD)**:
- `apps/mobile/lib/data/services/package_update_check_service.dart` — ETag-based version check
- `apps/mobile/lib/data/services/package_delta_service.dart` — Delta computation
- `apps/mobile/lib/data/services/course_package_update_service.dart` — Delta download orchestration
- `apps/mobile/lib/data/services/active_round_guard.dart` — Active round guard with deferred updates

**Mobile Infrastructure (INC-MOBILE-VC)**:
- `apps/mobile/lib/core/network/api_client.dart` — Extended with header support and getRaw for ETag
- `apps/mobile/lib/data/repositories/package_manifest_repository.dart` — Extended with ETag columns

**Mobile UI (INC-MOBILE-UI)**:
- `apps/mobile/lib/presentation/widgets/update_bottom_sheet.dart` — Update confirmation bottom sheet

**Modified Files**:
- `apps/mobile/lib/core/network/api_client.dart` — Added headers parameter to request methods and NotModifiedResponse/304 handling
- `apps/mobile/lib/data/repositories/package_manifest_repository.dart` — Added active_etag and pending_etag columns, updated promotion/discard to handle etags
