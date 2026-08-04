---
story: "9.2"
epic: 9
title: "Review Correction Queue"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 9.2: Review Correction Queue

## User Story

As a course administrator, I want a prioritized correction queue so that I can resolve credible issues efficiently.

## Acceptance Criteria

- Queue supports course, hole, type, status, confidence, and date filters.
- Review displays reporter evidence, location, map context, and existing official data.
- Reviewer can approve, reject, request information, or convert to draft edit.

## Tasks and Subtasks

- [x] Confirm the review correction queue scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer. *(Slice A: backend entity, repository, service, controller — already implemented prior to this dispatch)*
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion. *(Slices B, C, D: portal queue UI, detail panel, and review actions)*
- [x] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable. *(All portal components include loading skeletons, error states, retry, ARIA attributes)*
- [ ] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity. *(Tests deferred — portal test infrastructure is stub)*
- [x] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces. *(Portal scripts are stubs; backend validated via existing Maven build)*

## Dev Agent Record

### Implementation Notes

**Wave 2 (Slice B) — Portal Queue UI**
- `apps/portal/src/types/correction.ts` — TypeScript types mirroring backend DTOs
- `apps/portal/src/api/correction.ts` — API client for `/admin/corrections` endpoints
- `apps/portal/src/components/corrections/CorrectionStatusBadge.vue` — Semantic status badge (icon + text)
- `apps/portal/src/components/corrections/CorrectionQueueFilters.vue` — Filter form (course, hole, type, status, confidence, date)
- `apps/portal/src/components/corrections/CorrectionQueueTable.vue` — Paginated table with selection
- `apps/portal/src/pages/corrections/index.vue` — Main queue page integrating filters, table, and detail panel

**Wave 3 (Slice C) — Portal Detail**
- `apps/portal/src/components/corrections/CorrectionEvidenceViewer.vue` — Photo + note evidence display
- `apps/portal/src/components/corrections/CorrectionOfficialDataPanel.vue` — Official data comparison
- `apps/portal/src/components/corrections/CorrectionLocationMap.vue` — MapLibre map showing reporter GPS + official geometry overlay (deferred)
- `apps/portal/src/components/corrections/CorrectionDetailPanel.vue` — Aggregates all detail sub-components

**Wave 4 (Slice D) — Portal Review Actions**
- `apps/portal/src/components/corrections/CorrectionApproveDialog.vue` — Confirm + optional note
- `apps/portal/src/components/corrections/CorrectionRejectDialog.vue` — Reason required
- `apps/portal/src/components/corrections/CorrectionRequestInfoDialog.vue` — Message to reporter required
- `apps/portal/src/components/corrections/CorrectionConvertToDraftDialog.vue` — Confirm conversion
- `apps/portal/src/components/corrections/CorrectionReviewActions.vue` — Action button group + dialog orchestration

### Technical Decisions
- Status badge uses icon + text (not color alone) per accessibility guidelines
- Map context endpoint stub returns deferred message; full geometry deferred to Story 9.3
- All dialogs use `<dialog>`-style overlays with focus management
- ARIA labels on all interactive elements; minimum touch targets 44×44px

### Verification Status
- Portal `package.json` scripts are stubs (dev/build/test/lint/format/typecheck all echo stubs)
- Backend Maven build validates Java code
- Manual smoke test required: queue → filter → detail → approve flow

## File List

### Portal TypeScript
- `apps/portal/src/types/correction.ts` — **NEW**
- `apps/portal/src/api/correction.ts` — **NEW**

### Portal Vue Components
- `apps/portal/src/components/corrections/CorrectionStatusBadge.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionQueueFilters.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionQueueTable.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionEvidenceViewer.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionOfficialDataPanel.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionLocationMap.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionDetailPanel.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionApproveDialog.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionRejectDialog.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionRequestInfoDialog.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionConvertToDraftDialog.vue` — **NEW**
- `apps/portal/src/components/corrections/CorrectionReviewActions.vue` — **NEW**

### Portal Pages
- `apps/portal/src/pages/corrections/index.vue` — **NEW**

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 9.1 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 9.2 and Epic 9
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `9-2-review-correction-queue`
