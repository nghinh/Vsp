# Story Source Read — 11.1

## Source File
`docs/implementation-artifacts/epic-11/11-1-calculate-club-performance-and-dispersion.md`

## Story Metadata
- **Story ID:** 11.1
- **Epic:** Epic 11 — Performance Analytics and Smart Caddie
- **Phase:** MVP 2–3
- **Status:** `ready-for-dev`
- **Title:** Calculate Club Performance and Dispersion

## User Story
As a golfer, I want actual club distributions so that I understand carry, variability, and misses.

## Acceptance Criteria
1. System calculates average/median carry, total, variability, left/right, short/long, and confidence.
2. Low sample sizes are labeled and do not unlock recommendations.
3. Dispersion overlays can be compared against course hazards.

## Tasks
- [ ] Confirm scope against PRD, architecture, UX, and epic requirements.
- [ ] Define/update required contracts, domain models, persistence, and validation at the owning layer.
- [ ] Implement the smallest end-to-end behavior that satisfies every acceptance criterion.
- [ ] Add loading, empty, error, retry, offline, accessibility, authorization, and audit behavior where applicable.
- [ ] Add automated tests for happy paths, boundaries, failures, permissions, retries, and data integrity.
- [ ] Run repository format, lint, typecheck, test, and build gates applicable to changed surfaces.

## Developer Context and Constraints
- Preserve Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, and versioned-contract decisions where relevant.
- Keep writes locally durable before synchronization when the story affects on-course mobile behavior.
- Use stable OpenAPI contracts, structured errors, idempotency, RBAC, auditability, and data-quality metadata where applicable.
- Meet UX requirements for glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, and accessibility.
- Do not implement deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope unless this story explicitly belongs to that phase.

## Dependencies
- Relevant contracts and foundations from earlier delivery waves
- Epic 2 Story 2.4 (Manage Golf Bag and Clubs) — Club entity and club data
- Epic 10 Story 10.3 (Track Shots Manually) — Shot data with start/end, club, lie, distance
- Epic 10 Story 10.4 (Detect Shots with Confidence) — Shot detection with confidence
- Epic 6 Story 6.3/6.4 — Course geometry for hazard overlay comparison

## Source References
- `docs/planning-artifacts/epics.md` — Story 11.1 and Epic 11
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `11-1-calculate-club-performance-and-dispersion`
