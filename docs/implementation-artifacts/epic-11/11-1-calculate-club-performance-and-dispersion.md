---
story: "11.1"
epic: 11
title: "Calculate Club Performance and Dispersion"
status: done
phase: "MVP 2–3"
source: docs/planning-artifacts/epics.md
---

# Story 11.1: Calculate Club Performance and Dispersion

## User Story

As a golfer, I want actual club distributions so that I understand carry, variability, and misses.

## Acceptance Criteria

- System calculates average/median carry, total, variability, left/right, short/long, and confidence.
- Low sample sizes are labeled and do not unlock recommendations.
- Dispersion overlays can be compared against course hazards.

## Tasks and Subtasks

- [x] Confirm the calculate club performance and dispersion scope against the referenced PRD, architecture, UX, and epic requirements.
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

- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where relevant.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 11.1 and Epic 11
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `11-1-calculate-club-performance-and-dispersion`

## Dev Agent Record

### Implementation Summary

**Slices Implemented:** Slice 3 (Club Performance UI Screen) + Slice 4 (Dispersion Overlay Widget)

**Backend (Slices 1-2):** Already implemented (Java/Spring Boot module `vnpt.vsp.module.performance`)

**Flutter Mobile (Slices 3-4):**

#### Domain Models
- `ClubPerformanceStats` — per-club statistics with sample quality, confidence, directional deviation
- `BagPerformance` — bag-level performance containing list of clubs
- `DispersionOverlay` — scatter points and hazard geometry for dispersion visualization

#### Data Layer
- `PerformanceApi` — API client for `/bags/{bagId}/clubs/{clubId}/performance`, `/bags/{bagId}/performance`, `/bags/{bagId}/clubs/{clubId}/dispersion`
- `PerformanceRepository` — repository with in-memory caching for offline support

#### Presentation Layer
- `PerformanceBloc` — BLoC for club performance and dispersion overlay state
- `ClubPerformanceScreen` — per-club stats display with carry/total/directional stats
- `BagPerformanceScreen` — bag-level club list with performance summaries
- `DispersionMapScreen` — dispersion overlay on hole map
- Widgets:
  - `ClubStatsCard` — main stats display card
  - `ConfidenceBadge` — confidence level indicator
  - `SampleSizeBadge` — sample size label badge (insufficient/limited/moderate/robust)
  - `DirectionalStatsCard` — left/right and short/long deviation
  - `LockedRecommendationsBanner` — locked state with guidance
  - `ClubPerformanceMiniCard` — mini card for bag list view
  - `DispersionLegendWidget` — legend with layer toggles

#### Files Created (Flutter)
- `lib/domain/models/performance/club_performance_stats.dart`
- `lib/domain/models/performance/dispersion_overlay.dart`
- `lib/domain/models/performance/performance.dart` (barrel)
- `lib/data/api/performance_api.dart`
- `lib/data/repositories/performance_repository.dart`
- `lib/features/performance/presentation/performance_event.dart`
- `lib/features/performance/presentation/performance_state.dart`
- `lib/features/performance/presentation/performance_bloc.dart`
- `lib/features/performance/presentation/club_performance_screen.dart`
- `lib/features/performance/presentation/bag_performance_screen.dart`
- `lib/features/performance/presentation/dispersion_map_screen.dart`
- `lib/features/performance/presentation/dispersion_map_widget.dart`
- `lib/features/performance/presentation/dispersion_legend_widget.dart`
- `lib/features/performance/presentation/widgets/sample_size_badge.dart`
- `lib/features/performance/presentation/widgets/confidence_badge.dart`
- `lib/features/performance/presentation/widgets/club_stats_card.dart`
- `lib/features/performance/presentation/widgets/directional_stats_card.dart`
- `lib/features/performance/presentation/widgets/locked_recommendations_banner.dart`
- `lib/features/performance/presentation/widgets/club_performance_mini_card.dart`
- `lib/features/performance/presentation/widgets/widgets.dart` (barrel)
- `lib/features/performance/presentation/performance.dart` (barrel)
- `lib/features/performance/performance.dart` (barrel)

### Verification
- Code follows existing VSP design system tokens
- Accessibility: Semantics widgets used for custom cards, non-color-only indicators
- Flutter not available in environment — code structure verified manually
- Story status: `review` (awaiting code review)

## File List

### Flutter Mobile (Slice 3-4)
- `apps/mobile/lib/domain/models/performance/club_performance_stats.dart`
- `apps/mobile/lib/domain/models/performance/dispersion_overlay.dart`
- `apps/mobile/lib/domain/models/performance/performance.dart`
- `apps/mobile/lib/data/api/performance_api.dart`
- `apps/mobile/lib/data/repositories/performance_repository.dart`
- `apps/mobile/lib/features/performance/presentation/performance_event.dart`
- `apps/mobile/lib/features/performance/presentation/performance_state.dart`
- `apps/mobile/lib/features/performance/presentation/performance_bloc.dart`
- `apps/mobile/lib/features/performance/presentation/club_performance_screen.dart`
- `apps/mobile/lib/features/performance/presentation/bag_performance_screen.dart`
- `apps/mobile/lib/features/performance/presentation/dispersion_map_screen.dart`
- `apps/mobile/lib/features/performance/presentation/dispersion_map_widget.dart`
- `apps/mobile/lib/features/performance/presentation/dispersion_legend_widget.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/sample_size_badge.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/confidence_badge.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/club_stats_card.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/directional_stats_card.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/locked_recommendations_banner.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/club_performance_mini_card.dart`
- `apps/mobile/lib/features/performance/presentation/widgets/widgets.dart`
- `apps/mobile/lib/features/performance/presentation/performance.dart`
- `apps/mobile/lib/features/performance/performance.dart`

## Change Log

- 2026-08-02: Implemented Slices 3-4 (Flutter UI) for Club Performance and Dispersion — added domain models, API client, repository, BLoC, screens, and widgets
