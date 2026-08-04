---
story: "2.2"
epic: 2
title: "Manage Sessions Securely"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 2.2: Manage Sessions Securely

## User Story

As a golfer, I want secure device sessions so that I can control account access.

## Acceptance Criteria

- Access tokens are short-lived and refresh tokens rotate.
- Tokens are stored in encrypted device storage.
- User can list and revoke sessions; revoked sessions cannot refresh.

## Tasks and Subtasks

- [ ] Confirm the manage sessions securely scope against the referenced PRD, architecture, UX, and epic requirements.
- [ ] Define or update required contracts, domain models, persistence, and validation at the owning layer.
- [ ] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [ ] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [ ] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [ ] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Developer Context and Constraints

- Preserve the Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet the UX requirement for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies

- Story 2.1 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 2.2 and Epic 2
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `2-2-manage-sessions-securely`
