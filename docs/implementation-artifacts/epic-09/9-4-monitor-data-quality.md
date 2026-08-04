---
story: "9.4"
epic: 9
title: "Monitor Data Quality"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 9.4: Monitor Data Quality

## User Story

As a data quality manager, I want quality metrics so that pilot reliability can be measured.

## Acceptance Criteria

- Dashboard shows geometry completeness, verified courses, Class A/B coverage, correction volume, and resolution time.
- Metrics can be filtered by facility/course and exported.
- Stale pin, green speed, and course condition records are flagged.

## Tasks and Subtasks

- [x] Confirm the monitor data quality scope against the referenced PRD, architecture, UX, and epic requirements. (Wave 1 — completed prior)
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer. (Wave 1 — completed prior)
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion. (Wave 1 — backend done; Wave 2 — portal done)
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable. (Wave 2 — portal page with loading/error/empty states, accessibility)
- [x] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity. (Wave 3 — 40 tests: DataQualityControllerTest(15), DataQualityServiceImplTest(16), StaleRecordServiceImplTest(9))
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces. (All 40 new tests pass; pre-existing JPA context failures unrelated)

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 9.3 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Dev Agent Record

### Implementation Summary

**Wave 1 (Backend — pre-existing):**
- `DataQualityController` — GET /admin/data-quality/metrics, GET /admin/data-quality/stale, GET /admin/data-quality/export
- `DataQualityService` / `DataQualityServiceImpl` — metric computation (geometry completeness, verified courses, Class A/B coverage, correction volume, resolution time)
- `StaleRecordService` / `StaleRecordServiceImpl` — stale PIN/GREEN_SPEED/COURSE_CONDITION detection with Redis cache TTL 5min
- RBAC: SUPER_ADMIN, COURSE_ADMIN, AUDITOR roles enforced
- Audit: `@Audited(AuditAction.DATA_QUALITY_METRICS_EXPORT)` on export endpoint

**Wave 2 (Portal UI — new):**
- `apps/portal/src/pages/admin/data-quality/index.vue` — dashboard page with metric cards, filter bar, stale records table, export
- `apps/portal/src/api/admin/data-quality.ts` — API client (getMetrics, getStaleRecords, exportDataQuality)
- `apps/portal/src/types/admin/data-quality.ts` — TypeScript types (DataQualityMetrics, StaleRecord, DataQualityQuery)

**Wave 3 (Tests — new):**
- `DataQualityControllerTest` — 15 tests: RBAC (SUPER_ADMIN/COURSE_ADMIN/AUDITOR/deny), date validation (null, to<from, >90d), format validation, export CSV, max date range
- `DataQualityServiceImplTest` — 16 tests: computeMetrics (all fields, facility filter, null/zero handling), individual metric methods (geometry completeness, verified courses, Class A/B, correction volume, avg/median resolution time)
- `StaleRecordServiceImplTest` — 9 tests: combines all three record types, facility/course filters, empty list, sort order, individual finders, cache TTL constant
- `apps/portal/src/pages/admin/data-quality/DataQuality.test.ts` — unit tests for card status logic, format helpers, date validation, export filename

### Technical Notes

- Portal uses Vue 3 Composition API with TypeScript (confirmed from existing pages pattern)
- Portal tsconfig has `"jsx": "react-jsx"` misconfiguration but existing `.vue` files confirm Vue usage
- `VspErrorCode.toString()` returns the full code string (e.g., `"VSP-ERR-VALIDATION-001"`) — tests use enum comparison `assertEquals(VspErrorCode.VALIDATION_001, ex.getErrorCode())`
- `VspApiException(VspErrorCode, String)` constructor treats String param as `field` name, not message — custom messages are not stored
- Repository uses `Instant` for date ranges (converted from LocalDate via `atStartOfDay(UTC).toInstant()`)
- StaleRecordRepository queries take `Instant now` as first param (computed internally by service)

## File List

### Portal (Wave 2)
- `apps/portal/src/types/admin/data-quality.ts` — new
- `apps/portal/src/api/admin/data-quality.ts` — new
- `apps/portal/src/pages/admin/data-quality/index.vue` — new
- `apps/portal/src/pages/admin/data-quality/DataQuality.test.ts` — new

### API Tests (Wave 3)
- `apps/api/src/test/java/vnpt/vsp/api/admin/DataQualityControllerTest.java` — new
- `apps/api/src/test/java/vnpt/vsp/module/dataquality/DataQualityServiceImplTest.java` — new
- `apps/api/src/test/java/vnpt/vsp/module/dataquality/StaleRecordServiceImplTest.java` — new

## Source References

- `docs/planning-artifacts/epics.md` — Story 9.4 and Epic 9
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `9-4-monitor-data-quality`
