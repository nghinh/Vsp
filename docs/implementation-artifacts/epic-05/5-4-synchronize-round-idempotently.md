---
story: "5.4"
epic: 5
title: "Synchronize Round Idempotently"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 5.4: Synchronize Round Idempotently

## User Story

As a golfer, I want automatic synchronization when connectivity returns so that cloud history matches local data.

## Acceptance Criteria

- Local events carry unique idempotency keys and retry with backoff.
- Server deduplicates repeated submissions.
- Pending, syncing, synced, and failed states are visible with retry action.

## Tasks and Subtasks

- [x] Confirm the synchronize round idempotently scope against the referenced PRD, architecture, UX, and epic requirements.
- [x] Define or update required contracts, domain models, persistence, and validation at the owning layer. (Slices 1-2)
- [x] Implement the smallest end-to-end behavior that satisfies every acceptance criterion. (Slices 1-2: @Idempotent endpoints + SyncEvent/SyncStatus domain models)
- [ ] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable. (Slices 3-4)
- [ ] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity. (Slices 3-4)
- [ ] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces. (Slices 3-4)

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 5.3 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 5.4 and Epic 5
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `5-4-synchronize-round-idempotently`
