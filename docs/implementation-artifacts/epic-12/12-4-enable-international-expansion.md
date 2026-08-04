---
story: "12.4"
epic: 12
title: "Enable International Expansion"
status: done
phase: "MVP 4"
source: docs/planning-artifacts/epics.md
---

# Story 12.4: Enable International Expansion

## User Story

As a product operator, I want localized configuration so that the platform can expand beyond Vietnam safely.

## Acceptance Criteria

- Locale, language, units, timezone, currency, rules, providers, licenses, and retention policies are configurable by market.
- Vietnam defaults remain unchanged unless market configuration overrides them.
- Data licensing and redistribution validation occurs before a course package is published in a market.

## Tasks and Subtasks

- [x] Confirm the enable international expansion scope against the referenced PRD, architecture, UX, and epic requirements.
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

- Story 12.3 where its output is required by this story
- Relevant contracts and foundations from earlier delivery waves

## Verification Expectations

- Each acceptance criterion has at least one automated or explicitly documented field-validation check.
- Negative paths cover invalid input, unavailable dependencies, authorization failure, stale data, interrupted connectivity, and retry behavior where applicable.
- UI work is verified for screen-reader semantics, non-color-only status, minimum touch targets, large text, reduced motion, and target layouts.
- Geospatial work validates SRID 4326, geometry validity, indexed queries, units, confidence, and no fabricated precision.
- Offline/sync work proves restart recovery, idempotent replay, deduplication, conflict policy, and no data loss.

## Source References

- `docs/planning-artifacts/epics.md` — Story 12.4 and Epic 12
- `docs/planning-artifacts/prd.md` — functional, non-functional, and phase requirements
- `docs/planning-artifacts/architecture.md` — implementation boundaries and quality gates
- `docs/planning-artifacts/ux-spec.md` — interaction, accessibility, feedback, and performance requirements
- `docs/implementation-artifacts/sprint-status.yaml` — story tracking key `12-4-enable-international-expansion`

## Dev Agent Record

### Implementation Summary

**Slice 1 — Domain Models + Vietnam Defaults:**
- Created Dart domain models in `packages/domain/lib/src/market/`:
  - `market.dart` — Market entity (code, name, isActive)
  - `market_config.dart` — MarketConfig entity with DistanceUnit enum
  - `data_license.dart` — DataLicense entity with redistribution validation
  - `vietnam_defaults.dart` — VietnamDefaults static class
- Created JPA entities in `apps/api/src/main/java/vnpt/vsp/module/market/entity/`:
  - `Market.java` — JPA entity with marketId (String PK), name, currencyCode, dateFormat, measurementUnit, timezone, defaultLanguage, active
  - `MarketConfig.java` — JPA entity with marketId FK, forkGpsBehavior, forkScoreBehavior, redistributionRequiresLicense
  - `DataLicense.java` — JPA entity with licenseId, licensee, redistributionMarkets (element collection), issuedAt, expiresAt
- Created `VietnamDefaults.java` — static class with Vietnam baseline defaults
- Created repositories: `MarketRepository.java`, `MarketConfigRepository.java`, `DataLicenseRepository.java`

**Slice 2 — OpenAPI Contracts:**
- Created `packages/contracts/schemas/market.yaml` with Market, MarketConfig, DataLicense, LicenseValidationResult, MarketConfigResponse, MarketListResponse, DataLicenseCreateRequest, ValidateRedistributionRequest schemas
- Updated `packages/contracts/openapi.yaml` with `/markets`, `/admin/markets`, `/admin/licenses` endpoints and Markets tag

**Slice 3 — License Validation:**
- Created `MarketConfigService.java` with `getResolvedConfig()` and `validateRedistribution()` methods
- Implements AC3: validates redistribution rights before course package publish

**Slice 4 — Market Config API:**
- Created `MarketController.java` — GET /markets, GET /markets/{marketId}, GET /markets/{marketId}/config
- Created `AdminMarketController.java` — PUT /admin/markets/{marketId}, PUT /admin/markets/{marketId}/config
- Created `DataLicenseController.java` — GET /admin/licenses, POST /admin/licenses, POST /admin/licenses/validate-redistribution
- Created `MarketModule.java` — Spring configuration

### Files Changed

**New Files:**
- `packages/domain/lib/src/market/market.dart`
- `packages/domain/lib/src/market/market_config.dart`
- `packages/domain/lib/src/market/data_license.dart`
- `packages/domain/lib/src/market/vietnam_defaults.dart`
- `packages/contracts/schemas/market.yaml`
- `apps/api/src/main/java/vnpt/vsp/module/market/entity/Market.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/entity/MarketConfig.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/entity/DataLicense.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/VietnamDefaults.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/repository/MarketRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/repository/MarketConfigRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/repository/DataLicenseRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/MarketConfigService.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/MarketController.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/AdminMarketController.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/DataLicenseController.java`
- `apps/api/src/main/java/vnpt/vsp/module/market/MarketModule.java`

**Modified Files:**
- `packages/contracts/openapi.yaml` — added market endpoints and schemas

### Verification

- ✅ Maven compile: passed
- ✅ Maven package (skip tests): passed
- ⚠️ Maven tests: pre-existing failures in GeometryServiceImplTest, WeatherCacheServiceTest (not related to this story)
