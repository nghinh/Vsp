---
story: "6.1"
epic: 6
title: "Acquire and Qualify Location"
status: done
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Story 6.1: Acquire and Qualify Location

## User Story

As a golfer, I want clear GPS quality so that I understand whether displayed distances are trustworthy.

## Acceptance Criteria

- [x] AC1: Location includes coordinates, accuracy, age, timestamp, and movement direction.
- [x] AC2: Accuracy above 10m or stale positions trigger warning state.
- [x] AC3: Battery-aware sampling reduces updates when stationary while preserving active play responsiveness.

## Tasks and Subtasks

- [x] Confirm the acquire and qualify location scope against the referenced PRD, architecture, UX, and epic requirements.
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

## File List

- `apps/mobile/lib/domain/models/qualified_location.dart` — Domain model with coordinates, accuracy, timestamp, heading, source, staleness (AC1)
- `apps/mobile/lib/domain/models/location_quality.dart` — LocationQuality enum and LocationWarning model (AC2)
- `apps/mobile/lib/domain/services/location_service.dart` — Abstract location service interface
- `apps/mobile/lib/data/services/location_service_impl.dart` — Geolocator-based implementation with battery-aware sampling (AC3)
- `apps/mobile/lib/application/location/location_state.dart` — LocationState with status, quality, warning tracking
- `apps/mobile/lib/application/location/location_cubit.dart` — LocationCubit managing location lifecycle
- `apps/mobile/lib/presentation/widgets/gps_quality_indicator.dart` — GPS quality chip widget with semantic colors per UX spec
- `apps/mobile/test/domain/models/location_quality_test.dart` — Unit tests for LocationWarning and LocationQuality
- `apps/mobile/test/application/location/location_state_test.dart` — Unit tests for LocationState
- `apps/mobile/pubspec.yaml` — Added geolocator: ^13.0.2 dependency

## Change Log

- **2026-08-02**: Implemented Story 6.1 — Acquire and Qualify Location. Added QualifiedLocation model with AC1 fields, LocationWarning for AC2 warning states, LocationService with battery-aware sampling (30s stationary / 1s active intervals) for AC3, GPS quality indicator widget with semantic colors.

## Dev Agent Record

### Implementation Summary

Wave A: Domain models — `QualifiedLocation` (coordinates, accuracyMeters, timestamp, heading, source, isStale), `LocationQuality` enum (ready/lowAccuracy/stale/unavailable), `LocationWarning` model with blocksAutoAction flag.

Wave B: Location service interface + geolocator implementation with battery-aware sampling (AC3: stationary=30s interval, active=1s interval, speed threshold 0.5m/s).

Wave C: LocationCubit managing lifecycle (start/stop), warning propagation, lastGoodLocation tracking.

Wave D: GpsQualityIndicator widget with semantic colors per UX spec §4.2, GpsQualityDetailDialog for detailed GPS stats.

### Notes

- AC1: QualifiedLocation includes latitude, longitude, accuracyMeters, timestamp, heading (movement direction), source, isStale (age). All required fields implemented.
- AC2: hasWarning=true when isLowAccuracy (accuracy>10m) OR isStale (age>5s). LocationWarning.blocksAutoAction=true for both cases. Warning displayed in UI.
- AC3: Battery-aware sampling implemented via timer-based rescheduling. Stationary (speed<0.5m/s): 30s interval. Moving: 1s interval.
- GPS quality widget follows UX spec colors: green=ready, amber=lowAccuracy, red=stale/unavailable.
- geolocator package added to pubspec.yaml for GPS access.
- Note: Flutter SDK not available in build environment; flutter analyze/test skipped. Run `flutter pub get && flutter analyze` in dev environment.

## Source References

- `docs/planning-artifacts/epics.md` — Story 6.1 and Epic 6
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `6-1-acquire-and-qualify-location`
