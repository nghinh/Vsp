# Slice Plan: Story 9.2 — Review Correction Queue

## Story Metadata

| Field | Value |
|-------|-------|
| **Story** | 9.2 |
| **Epic** | 9 (Correction and Data Quality Loop) |
| **Title** | Review Correction Queue |
| **Status** | ready-for-dev → in-progress |
| **Phase** | MVP 1 |
| **Source** | `docs/planning-artifacts/epics.md` |
| **Run Folder** | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |

## Context Summary

**What is this story about?**
Building the Course Operations Portal's correction queue review feature. Course administrators use this to review, triage, and act on golfer-submitted course data corrections.

**Where does it live in the architecture?**
- **Backend**: `apps/api/src/main/java/vnpt/vsp/module/correction/` — currently a stub scaffold
- **Portal**: `apps/portal/src/pages/corrections/` — does not exist yet
- **Module**: `CorrectionModule` (bounded context: Course Data Quality)

**What already exists?**
- `CorrectionService` interface (empty stub)
- `CorrectionServiceImpl` (only audit logging methods for approve/reject)
- `CorrectionModule` annotation (marker only)
- Error codes: `CORRECTION_001-004` (defined in `VspErrorCode.java`)
- `ScoreCorrection` entity (in `module/score/` — different domain: score entry corrections vs course data corrections)
- Existing portal structure: Vue 3 pages under `apps/portal/src/pages/`

**What needs to be built?**
Full-stack portal feature: backend API for correction queue + Vue portal queue UI with review actions.

---

## User Story

> As a course administrator, I want a prioritized correction queue so that I can resolve credible issues efficiently.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|---------------|
| AC-1 | Queue supports course, hole, type, status, confidence, and date filters | Manual: filter controls visible and functional; Automated: filter parameter parsing tests |
| AC-2 | Review displays reporter evidence, location, map context, and existing official data | Manual: all 4 data categories visible in review panel |
| AC-3 | Reviewer can approve, reject, request information, or convert to draft edit | Manual: each action button triggers correct state transition + audit entry |

---

## Dependency Analysis

| Dependency | Status | Impact on 9.2 |
|------------|--------|---------------|
| Story 9.1 (Submit Correction Offline) | backlog | **Low** — Story 9.2 builds the backend API and portal UI in anticipation of 9.1's output. The data model and API contract must be compatible with 9.1's submission flow. |
| Epic 8 (Course Operations Portal) | in-progress | **Medium** — Portal layout, navigation, RBAC, and shared components are being built in parallel. 9.2 should follow established portal patterns. |
| Epic 3 (Course Catalog) | in-progress | **Medium** — Course and Hole entities/relationships are being stabilized. 9.2 references these. |
| Epic 1.3 (API Contracts) | done | **High** — OpenAPI contracts, error standards, pagination, and idempotency patterns are established. 9.2 must conform. |

**Dependency conclusion**: Story 9.2 can proceed with backend API and portal UI development. The data model is independent of 9.1's implementation; only the API contract must be aligned (which will be done via shared DTOs).

---

## Slice Architecture

### Slice A: Backend — Core Domain Model + Repository + Service + Controller

**Scope**: Complete the `correction` module backend foundation.

**Files to create/modify**:

```
apps/api/src/main/java/vnpt/vsp/module/correction/
├── entity/
│   ├── CourseCorrection.java          [NEW] JPA entity
│   ├── CorrectionStatus.java          [NEW] enum: PENDING, IN_REVIEW, APPROVED, REJECTED, INFO_REQUESTED, CONVERTED_TO_DRAFT
│   ├── CorrectionType.java           [NEW] enum: GEOMETRY, PIN_POSITION, BUNKER, WATER, OB, CART_PATH, LANDMARK, COURSE_CONDITION, GREEN_SPEED, OTHER
│   └── CorrectionReviewAction.java   [NEW] enum: APPROVE, REJECT, REQUEST_INFO, CONVERT_TO_DRAFT
├── dto/
│   ├── CorrectionQueueRequest.java   [NEW] paginated list request with filters
│   ├── CorrectionQueueResponse.java  [NEW] paginated list response
│   ├── CorrectionDetailResponse.java [NEW] full correction detail
│   └── CorrectionReviewRequest.java  [NEW] action payload (reason, notes)
├── repository/
│   └── CourseCorrectionRepository.java [NEW] JPA repository with filter queries
└── CorrectionService.java             [MODIFY] add queue(), getDetail(), review()
```

**Implementation notes**:
- Follow existing `module/course/` pattern: entity extends `BaseEntity` with audit fields
- Follow existing `module/package/` pattern: `PackageBuildController` for pagination+filter style
- Use existing `AuditService` and `AuditAction.CORRECTION_*` already defined
- CorrectionStatus state machine: PENDING → IN_REVIEW → {APPROVED | REJECTED | INFO_REQUESTED | CONVERTED_TO_DRAFT}
- RBAC: `COURSE_ADMIN` or `GREENKEEPER` or `SUPER_ADMIN` role required

**API endpoints**:
```
GET    /admin/corrections?courseId=&hole=&type=&status=&confidence=&from=&to=&page=&size=
GET    /admin/corrections/{id}
POST   /admin/corrections/{id}/review  { action: "APPROVE"|"REJECT"|"REQUEST_INFO"|"CONVERT_TO_DRAFT", reason? }
GET    /admin/corrections/{id}/map-context  → returns official course/hole geometry for map overlay
```

**Database migration**: New migration `V23__course_corrections.sql`

---

### Slice B: Portal — Correction Queue List Page

**Scope**: Vue page with paginated queue table + filter controls.

**Files to create**:

```
apps/portal/src/pages/corrections/index.vue          [NEW] main queue page
apps/portal/src/components/corrections/
├── CorrectionQueueFilters.vue           [NEW] filter form
├── CorrectionQueueTable.vue             [NEW] paginated table
└── CorrectionStatusBadge.vue            [NEW] semantic status badge

apps/portal/src/types/correction.ts          [NEW] TypeScript types
apps/portal/src/api/correction.ts           [NEW] API client
```

**Implementation notes**:
- Follow existing portal patterns: `apps/portal/src/pages/courses/[courseId]/versions/index.vue` as reference
- Filter sidebar or top-bar: course dropdown, hole dropdown, type multi-select, status multi-select, confidence slider, date range picker
- Table columns: ID, Course, Hole, Type, Status, Confidence, Submitted, Reporter
- Use existing `useApi()` composable and error handling pattern
- RBAC gate: redirect if user lacks `COURSE_ADMIN` role

---

### Slice C: Portal — Correction Detail + Map Context

**Scope**: Side-panel or full-page detail view showing reporter evidence, location, and official data comparison.

**Files to create**:

```
apps/portal/src/components/corrections/
├── CorrectionDetailPanel.vue           [NEW] detail side-panel
├── CorrectionEvidenceViewer.vue         [NEW] photo + note evidence
├── CorrectionLocationMap.vue            [NEW] map showing reporter location + nearby official geometry
└── CorrectionOfficialDataPanel.vue     [NEW] shows current official data for comparison
```

**Implementation notes**:
- Map context: use existing `GeometryEditor` map component with read-only overlay
- Show reporter's GPS location as a marker, official geometry as vector layers
- Use existing `CourseMap.vue` component in read-only mode
- Photo evidence: use existing image display pattern from portal

---

### Slice D: Portal — Review Actions

**Scope**: Action buttons and confirmation flows for the four review actions.

**Files to create/modify**:

```
apps/portal/src/components/corrections/
├── CorrectionReviewActions.vue          [NEW] approve/reject/request info/convert buttons
├── CorrectionApproveDialog.vue          [NEW] confirm + optional note
├── CorrectionRejectDialog.vue           [NEW] reason required
├── CorrectionRequestInfoDialog.vue      [NEW] message to reporter
└── CorrectionConvertToDraftDialog.vue  [NEW] confirms conversion

apps/portal/src/pages/corrections/index.vue  [MODIFY] integrate review actions into detail panel
```

**Implementation notes**:
- Each action calls `POST /admin/corrections/{id}/review`
- Approve: no reason required, creates audit entry, status → APPROVED
- Reject: reason required, status → REJECTED
- Request Info: message required, status → INFO_REQUESTED, optionally sends notification (deferred)
- Convert to Draft: creates draft edit in the geometry editor, status → CONVERTED_TO_DRAFT
- After action, refresh queue list and close detail panel

---

### Slice E: Integration + Validation

**Scope**: Connect all pieces, run tests, ensure no regressions.

**Verification**:
- Backend: unit tests for `CorrectionServiceImpl`, integration tests for controller
- Portal: component tests for `CorrectionQueueTable`, `CorrectionDetailPanel`
- E2E: manual smoke test of full approve flow (queue → detail → approve → audit)
- Lint/typecheck/build gates on both `apps/api` and `apps/portal`

---

## Wave Summary

| Wave | Scope | Deliverable |
|------|-------|-------------|
| Wave 1 | Slice A | Backend correction entity, repository, service, controller, migration |
| Wave 2 | Slice B | Portal queue list page with filters |
| Wave 3 | Slice C | Portal correction detail + map context |
| Wave 4 | Slice D | Portal review actions |
| Wave 5 | Slice E | Integration, tests, validation gates |

---

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **New `CourseCorrection` entity** (not reusing `ScoreCorrection`) | Different bounded context: score corrections (Epic 5) vs course data corrections (Epic 9). Separate tables, separate workflows. |
| **Status state machine** | PENDING → IN_REVIEW (on open) → final states. Prevents race conditions when multiple admins review simultaneously. |
| **Map context endpoint** | Returns official geometry for the reported hole so portal can render comparison overlay without duplicating geospatial logic. |
| **Convert to draft** | Links correction to geometry editor draft — not full implementation of 9.3, just the trigger. |
| **No notification** | Reporter notification (email/push) is deferred to Story 9.3 or later. AC-3 only requires state change. |

---

## Open Questions / Blockers

| Question | Impact | Resolution |
|----------|--------|------------|
| Does story 9.1 define the exact `CorrectionType` enum values? | Medium — must match between mobile submission and portal review | Propose enum superset covering all plausible types; align with 9.1 during 9.1 planning |
| Is there an existing RBAC role for "correction reviewer"? | Medium — portal RBAC gate needs correct role | Use existing `COURSE_ADMIN` role for MVP; defer to Story 9.4 if granular roles needed |
| Does the map context need offline-capable vector tiles? | Low — portal is web-based, always online | Fetch official geometry via API; no offline requirement |

---

## Verification Checklist

- [ ] Each AC has at least one automated test or explicit field validation
- [ ] Negative paths: unauthorized access returns 403, not-found returns 404, invalid status transition returns 400 with `CORRECTION_003`
- [ ] UI: filter controls functional, loading states present, empty state handled
- [ ] UI: detail panel shows all 4 data categories (evidence, location, map, official data)
- [ ] UI: all 4 review actions functional with confirmation dialogs
- [ ] Audit: every review action creates audit entry via existing `AuditService`
- [ ] RBAC: non-admin users cannot access `/admin/corrections` endpoints or portal page
- [ ] Pagination: list endpoint returns correct `Paged` response format
- [ ] Map: correction location marker visible on official geometry overlay

---

## File Inventory

### Backend (Java/Spring)

| File | Action | Location |
|------|--------|----------|
| `CourseCorrection.java` | CREATE | `module/correction/entity/` |
| `CorrectionStatus.java` | CREATE | `module/correction/entity/` |
| `CorrectionType.java` | CREATE | `module/correction/entity/` |
| `CorrectionReviewAction.java` | CREATE | `module/correction/entity/` |
| `CourseCorrectionRepository.java` | CREATE | `module/correction/repository/` |
| `CorrectionQueueRequest.java` | CREATE | `module/correction/dto/` |
| `CorrectionQueueResponse.java` | CREATE | `module/correction/dto/` |
| `CorrectionDetailResponse.java` | CREATE | `module/correction/dto/` |
| `CorrectionReviewRequest.java` | CREATE | `module/correction/dto/` |
| `CorrectionService.java` | MODIFY | `module/correction/` (add method signatures) |
| `CorrectionServiceImpl.java` | MODIFY | `module/correction/` (implement methods) |
| `CorrectionController.java` | CREATE | `api/admin/` |
| `V23__course_corrections.sql` | CREATE | `resources/db/migration/` |
| `VspErrorCode.java` | MODIFY | `api/error/` (if new codes needed) |

### Portal (Vue 3)

| File | Action | Location |
|------|--------|----------|
| `correction.ts` (types) | CREATE | `src/types/` |
| `correction.ts` (api) | CREATE | `src/api/` |
| `corrections/index.vue` | CREATE | `src/pages/` |
| `CorrectionQueueFilters.vue` | CREATE | `src/components/corrections/` |
| `CorrectionQueueTable.vue` | CREATE | `src/components/corrections/` |
| `CorrectionStatusBadge.vue` | CREATE | `src/components/corrections/` |
| `CorrectionDetailPanel.vue` | CREATE | `src/components/corrections/` |
| `CorrectionEvidenceViewer.vue` | CREATE | `src/components/corrections/` |
| `CorrectionLocationMap.vue` | CREATE | `src/components/corrections/` |
| `CorrectionOfficialDataPanel.vue` | CREATE | `src/components/corrections/` |
| `CorrectionReviewActions.vue` | CREATE | `src/components/corrections/` |
| `CorrectionApproveDialog.vue` | CREATE | `src/components/corrections/` |
| `CorrectionRejectDialog.vue` | CREATE | `src/components/corrections/` |
| `CorrectionRequestInfoDialog.vue` | CREATE | `src/components/corrections/` |
| `CorrectionConvertToDraftDialog.vue` | CREATE | `src/components/corrections/` |

### Tests

| File | Action | Location |
|------|--------|----------|
| `CourseCorrectionRepositoryTest.java` | CREATE | `module/correction/` |
| `CorrectionServiceImplTest.java` | CREATE | `module/correction/` |
| `CorrectionControllerTest.java` | CREATE | `api/admin/` |
| `correction_queue_test.ts` | CREATE | `portal/test/` |
| `correction_detail_test.ts` | CREATE | `portal/test/` |
| `correction_review_actions_test.ts` | CREATE | `portal/test/` |

---

*Slice plan created: 2026-08-02*
*Planner: `vnpt-epic-story-runner`*
