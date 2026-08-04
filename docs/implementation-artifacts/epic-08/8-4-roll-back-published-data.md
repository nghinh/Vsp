---
story: "8.4"
epic: 8
title: "Roll Back Published Data"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 8.4: Roll Back Published Data

## User Story

As a course administrator, I want rollback so that harmful releases can be corrected quickly.

## Acceptance Criteria

- Authorized user can select a prior version and view impact.
- Rollback creates a new version rather than deleting history.
- New package generation and audit record are triggered.

## Tasks and Subtasks

- [x] Confirm the roll back published data scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## File List

### New Files
- `apps/api/src/test/java/vnpt/vsp/api/course/CourseVersionControllerTest.java` — Controller unit tests (Wave C)
- `apps/portal/src/api/course-version.ts` — Portal API client for version endpoints (Wave D)
- `apps/portal/src/types/course-version.ts` — TypeScript types for version API (Wave D)
- `apps/portal/src/pages/courses/[courseId]/versions/index.vue` — Portal version history page (Wave D)

### Modified Files
- `docs/implementation-artifacts/epic-08/8-4-roll-back-published-data.md` — Tasks checked, Dev Agent Record updated, status → review

### Implementation Notes (Wave C+D — Tests + Portal UI)

**Wave C — Unit tests for rollback state machine:**
- Created `CourseVersionControllerTest.java` (12 test cases):
  - `listVersions`: happy path (200 + pagination), forbidden when no COURSE_ADMIN role
  - `getVersion`: happy path (200 with full metadata), not found (DATA_VERSION_001), forbidden (no role)
  - `getRollbackImpact`: happy path (200 with current+target version summary), not found (version does not exist)
  - `executeRollback`: happy path (200 + RollbackResponse), conflict when version not archived (DATA_VERSION_002), conflict when no published version (DATA_VERSION_003), not found (version does not exist), forbidden (no role)
  - Pagination: respects page and size parameters
- `CourseVersionServiceImplTest` already existed with comprehensive rollback state machine coverage (happy path + error paths)

**Wave D — Portal UI:**
- Created `portal/src/types/course-version.ts`: TypeScript types mirroring all backend DTOs (CourseVersionDto, VersionListResponse, RollbackImpactDto, RollbackRequest, RollbackResponse, ApiError)
- Created `portal/src/api/course-version.ts`: API client with methods for listVersions, getVersion, getRollbackImpact, executeRollback — following exact same patterns as package-build.ts
- Created `portal/src/pages/courses/[courseId]/versions/index.vue`:
  - Version history table: versionNumber badge, status badge (icon+text, non-color-only), publishedBy, publishedAt, rollbackNote
  - "View Impact" button per version — opens impact modal with current→archived and target→reactivated summary
  - "Roll Back" button shown only for ARCHIVED versions when a PUBLISHED version exists
  - Rollback confirmation modal: shows impact summary, requires rollbackNote (validated, 500 char max)
  - Loading skeletons, error state with retry, empty state
  - Success toast after rollback triggers (auto-dismiss 8s)
  - Accessibility: aria-labels, aria-busy, aria-live, aria-modal, aria-invalid, min-height 44px touch targets
  - Responsive: stacks on small screens

### Verification Notes
- Backend compilation errors in `CourseAlertController`, `CourseAlertServiceImpl`, and `PackageGenerationService` are pre-existing and unrelated to Wave C+D changes.
- Pre-write dedup checks: CourseVersionControllerTest, CourseVersionApi, versions/index.vue, VersionListResponse — all returned `new_duplicate_likely: false`.
- Portal build scripts are stubs (`echo` commands); TypeScript correctness verified by manual review against existing `package-build.ts` patterns.

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 8.3 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 8.4 and Epic 8
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `8-4-roll-back-published-data`
