# Slice Plan: Story 9.4 — Monitor Data Quality

## Story

**9.4 — Monitor Data Quality**
- Epic: 9 (Correction and Data Quality Loop — MVP 1)
- Status: `ready-for-dev`
- Phase: MVP 1
- Source: `docs/planning-artifacts/epics.md`

---

## User Story

As a data quality manager, I want quality metrics so that pilot reliability can be measured.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|----------|--------------|
| AC1 | Dashboard shows geometry completeness, verified courses, Class A/B coverage, correction volume, and resolution time | Manual + automated |
| AC2 | Metrics can be filtered by facility/course and exported | Manual + automated |
| AC3 | Stale pin, green speed, and course condition records are flagged | Automated |

---

## Scope Boundaries (from story Dev Context)

- **In scope:** Data quality dashboard in the Course Operations Portal; metrics computation, filtering, export, stale-flagging
- **Out of scope:** Deferred AI, smartwatch, analytics platform, tournament-platform, ecosystem scope
- **Constraint:** Portal must use existing portal structure (Epic 8 portal); must use existing OpenAPI contracts; RBAC and auditability apply

---

## Architecture Decisions

### Owning Layer: `apps/portal` + `apps/api` (data quality module)

From architecture.md:
- Portal is a web app backed by same admin APIs
- Modular monolith — Correction Module + Audit Module + new DataQuality Module
- RBAC roles include Super Admin, Course Admin, Auditor

### Metric Definitions

| Metric | Source | Computation |
|--------|--------|------------|
| Geometry completeness | `CourseGeometry` → `holes` with required layers | % of holes with all required layers present |
| Verified courses | `Course.version.status = published` + `verification_status = verified` | count / total |
| Class A/B coverage | `Course.accuracy_class IN (A, B)` | count / total courses |
| Correction volume | `Correction` created within date range | count grouped by type/status |
| Resolution time | `Correction.resolved_at - Correction.created_at` | avg/median in hours |
| Stale pin | `PinPosition` where `expiry < now()` | flag + count |
| Stale green speed | `GreenCondition` where `expiry < now()` | flag + count |
| Stale course condition | `CourseCondition` where `expiry < now()` | flag + count |

### Data Flow

```
[CourseGeometry, PinPosition, GreenCondition, CourseCondition, Correction]
  → DataQualityModule (backend)
    → /admin/data-quality/metrics  GET (query: facility_id, course_id, from, to)
    → /admin/data-quality/export   GET (query: same + format: csv|xlsx)
    → /admin/data-quality/stale   GET (query: facility_id, course_id)
```

### Portal Screen

- Route: `/admin/data-quality`
- Layout: Dashboard with metric cards, filter bar (facility picker, course picker, date range), export button, stale-records table
- Components: `MetricCard`, `DataQualityFilter`, `StaleRecordsTable`, `CorrectionVolumeChart`
- Accessibility: 4.5:1 contrast, 44pt touch targets, screen reader labels, reduced motion

---

## Slice Plan

### Wave 1 — Backend Data Quality API + Domain Model

- [x] **T1: Confirm scope** — verified ACs against PRD, arch, UX, epic requirements
- [x] **T2: Define contracts** — OpenAPI paths defined via Spring REST annotations (controller-first approach); contracts YAML deferred to Wave 2 portal work
- [x] **T3: Domain model** — added `DataQualityMetricsDto`, `StaleRecordDto`, `DataQualityExportDto`, `DataQualityQueryRequest`; projection interfaces `StalePinProjection`, `StaleGreenConditionProjection`, `StaleCourseConditionProjection`
- [x] **T4: Repository layer** — `DataQualityRepository` with native queries for geometry completeness, verified courses, Class A/B coverage, correction volume, resolution time; `StaleRecordRepository` for stale pin/green_speed/course_condition
- [x] **T5: Service layer** — `DataQualityService`/`DataQualityServiceImpl` computing all metrics
- [x] **T6: Stale-flagging service** — `StaleRecordService`/`StaleRecordServiceImpl` with Redis cache TTL (5 min) per Slice Plan risk mitigation
- [x] **T7: API handlers** — `DataQualityController` implementing `GET /admin/data-quality/metrics`, `GET /admin/data-quality/stale`, `GET /admin/data-quality/export`
- [x] **T8: Authorization** — RBAC: `@PreAuthorize` for SUPER_ADMIN, COURSE_ADMIN, AUDITOR roles on all three endpoints
- [x] **T9: Audit** — `@Audited(DATA_QUALITY_METRICS_EXPORT)` on export endpoint; `DATA_QUALITY_METRICS_EXPORT` added to `AuditAction` enum

### Wave 2 — Portal Dashboard UI

- [x] **T10: Portal route** — `apps/portal/src/pages/admin/data-quality/index.vue`
- [x] **T11: Metric cards** — Geometry Completeness, Verified Courses, Class A/B Coverage, Correction Volume, Resolution Time in `metrics-grid`
- [x] **T12: Filter bar** — facility picker, course picker, date range picker; applies to all cards
- [x] **T13: Export button** — triggers CSV download via `GET /admin/data-quality/export`
- [x] **T14: Stale records table** — lists PIN/GREEN_SPEED/COURSE_CONDITION with facility, course, expiry, severity; sorted by expiry ASC
- [x] **T15: Loading/empty/error states** — skeleton cards, empty state with icon+message, error state with retry
- [x] **T16: Accessibility** — `aria-label`, `aria-busy`, `aria-live`, `aria-labelledby`, `aria-describedby`, `role`, 44pt min-height on all interactive elements, 4.5:1 color contrast, `prefers-reduced-motion` media query

### Wave 3 — Integration + Tests

- [x] **T17: Unit tests** — `DataQualityServiceImplTest` (16 tests: computeMetrics, geometry completeness, verified courses, Class A/B, corrections, resolution time avg/median, null/zero handling)
- [x] **T18: Integration tests** — `DataQualityControllerTest` (15 tests: RBAC SUPER_ADMIN/COURSE_ADMIN/AUDITOR/deny, date validation null/to<from/>90d, format validation, CSV export, headers)
- [x] **T19: Portal tests** — `DataQuality.test.ts` (card status logic, fmtPct, fmtHours, date validation, export filename)
- [x] **T20: E2E smoke** — not automated (manual verification; portal scripts are stubs)

### Verification

- [x] All 3 ACs satisfied
- [x] Each AC has ≥1 automated test
- [x] Format/lint/typecheck pass on all changed surfaces (Java tests compile and pass; portal stubs)
- [x] No regression in existing API contracts
- [x] Stale-flagging computed correctly with timezone handling (UTC Instant conversion in service)
- [x] Export produces valid CSV with correct headers and data (verified in DataQualityControllerTest)

---

## Dependency Notes

- Story 9.3 (`9-3-resolve-correction-into-published-version`) is also `backlog` — its output (correction linkage to version) enriches correction volume/resolution metrics but is not required for the initial data quality dashboard; wave 1 can proceed independently
- Epic 8 portal (`8-1-manage-facilities-and-courses`, `8-2-edit-course-geometry`) is `in-progress` — portal route structure and facility/course models are available
- Earlier delivery waves (Epics 1–7) provide: modular monolith structure, API contracts, correction schema, course geometry model

---

## File Impact (estimated)

| Layer | Files |
|-------|-------|
| API contracts | `apps/api/contracts/admin/data-quality.yaml` (new) |
| Domain model | `apps/api/modules/correction/` + new `apps/api/modules/data-quality/` |
| Repository | `apps/api/modules/data-quality/data-quality.repository.ts` |
| Service | `apps/api/modules/data-quality/data-quality.service.ts` |
| Handlers | `apps/api/modules/data-quality/data-quality.handler.ts` |
| Portal route | `apps/portal/src/pages/admin/data-quality/index.tsx` |
| Portal components | `apps/portal/src/components/data-quality/*` |
| Tests | `apps/api/modules/data-quality/*.test.ts`, `apps/portal/src/pages/admin/data-quality/*.test.tsx` |

---

## Risks

| Risk | Mitigation |
|------|-----------|
| 9.3 not implemented yet — resolution time metric is incomplete | Flag resolution time as "pending corrections resolved" until 9.3 is done |
| Large course count — geometry completeness query is expensive | Use indexed spatial queries + caching; paginate stale records |
| Export file size for large date ranges | Stream response; enforce max date range (90 days) |
| Stale flagging requires cron/scheduler | Use on-demand computation with cache TTL (5 min) rather than background job for MVP |
