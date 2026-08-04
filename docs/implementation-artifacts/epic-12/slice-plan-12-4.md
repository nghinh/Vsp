# Slice Plan — Story 12.4: Enable International Expansion

## Story Summary
- **Story**: 12.4 — Enable International Expansion
- **Epic**: epic-12 (Tournament Platform)
- **Status**: `ready-for-dev` → `in-progress`
- **Phase**: MVP 4 (deferred ecosystem scope)

---

## Context Synthesis

### AC Breakdown

| AC | Requirement | Implication |
|---|---|---|
| AC1 | Locale, language, units, timezone, currency, rules, providers, licenses, retention policies configurable by market | Need `Market`, `MarketConfig`, `DataLicense` domain entities; market-specific config storage |
| AC2 | Vietnam defaults unchanged unless market overrides | Vietnam baseline defaults; market configs are partial overrides only |
| AC3 | Data licensing/redistribution validation before course package publish in a market | License validation gate in publish flow |

### Key Design Decisions

1. **Market entity**: ISO 3166-1 alpha-2 country code (e.g., `VN`, `TH`, `MY`) + display name + active flag
2. **MarketConfig**: Per-market partial override of Vietnam defaults. All fields optional — only non-null fields override.
3. **DataLicense**: License record with `redistributionMarkets: string[]` — list of market codes where redistribution is allowed
4. **Vietnam defaults**: Hardcoded static defaults (locale `vi-VN`, units `METRIC`, currency `VND`, timezone `Asia/Ho_Chi_Minh`, etc.)
5. **License validation**: Synchronous check in `CoursePackageService.publish()` — if any package license doesn't list the target market in `redistributionMarkets`, raise structured error
6. **No actual new market activation** — this is infrastructure only; Vietnam remains the only supported market

### Existing Patterns Used
- Domain: Dart + Equatable + `toMap`/`fromMap` + `toJson`/`fromJson` (see `packages/domain/lib/src/round/`)
- Contracts: OpenAPI YAML in `packages/contracts/openapi.yaml` + schema YAMLs in `packages/contracts/schemas/`
- License field already exists in `course.yaml` (`PackageLicense` with `name`, `url`, `spdxId`)

### Out of Scope
- Actual new market data entry or activation
- Currency conversion or exchange rates
- Localized content strings (i18n framework)
- Regulatory compliance checks beyond license redistribution
- Market-specific provider integration (payment, weather, etc.)

---

## Slice Plan

### Slice 1 — Domain Models + Vietnam Defaults

**Goal**: Core domain entities + Vietnam baseline defaults.

**Files to create/modify**:
```
packages/domain/lib/src/market/
├── market.dart           # Market entity (country code, name, active)
├── market_config.dart    # MarketConfig entity (partial override of Vietnam defaults)
├── data_license.dart     # DataLicense entity (license with redistribution market list)
└── vietnam_defaults.dart  # Vietnam baseline MarketConfig

packages/domain/lib/src/market/market.dart
packages/domain/lib/src/market/market_config.dart
packages/domain/lib/src/market/data_license.dart
packages/domain/lib/src/market/vietnam_defaults.dart
```

**Domain model fields**:

```dart
// Market
- code: String          // ISO alpha-2, e.g. "VN"
- name: String           // Display name, e.g. "Vietnam"
- isActive: bool

// MarketConfig (partial override — null means use Vietnam default)
- marketCode: String
- locale: String?        // e.g. "vi-VN", null = Vietnam default "vi-VN"
- language: String?      // e.g. "vi", null = "vi"
- units: DistanceUnit?    // METRIC | IMPERIAL, null = METRIC
- timezone: String?      // e.g. "Asia/Ho_Chi_Minh", null = "Asia/Ho_Chi_Minh"
- currency: String?      // e.g. "VND", null = "VND"
- rulesUrl: String?      // null = no market-specific rules
- enabledProviderIds: List<String>? // null = all Vietnam providers
- requiredLicenseIds: List<String>? // null = Vietnam default licenses
- retentionPolicyDays: int? // null = Vietnam default (365)

enum DistanceUnit { metric, imperial }

// DataLicense
- id: String
- name: String
- spdxId: String
- redistributionMarkets: List<String> // e.g. ["VN", "TH"] — markets where redistribution is allowed
```

**VietnamDefaults class**:
```dart
class VietnamDefaults {
  static const locale = 'vi-VN';
  static const language = 'vi';
  static const units = DistanceUnit.metric;
  static const timezone = 'Asia/Ho_Chi_Minh';
  static const currency = 'VND';
  static const retentionPolicyDays = 365;
  static List<String> get enabledProviderIds => []; // empty = all
  static List<String> get requiredLicenseIds => [];
}
```

**Tests**:
- `packages/domain/test/market/vietnam_defaults_test.dart` — verify all defaults
- `packages/domain/test/market/market_config_merge_test.dart` — verify override merge behavior

---

### Slice 2 — OpenAPI Contracts for Market Config

**Goal**: CRUD contract for market config + license validation result schema.

**Files to create**:
```
packages/contracts/schemas/market.yaml          # Market + MarketConfig + DataLicense schemas
packages/contracts/schemas/market_provider.yaml  # ProviderEnablement schema (future use)
```

**Schema additions** (in `market.yaml`):
```yaml
Market:
  type: object
  properties:
    code: { type: string, description: "ISO 3166-1 alpha-2", example: "VN" }
    name: { type: string, example: "Vietnam" }
    isActive: { type: boolean }

MarketConfig:
  type: object
  properties:
    marketCode: { type: string }
    locale: { type: string, nullable: true }
    language: { type: string, nullable: true }
    units: { type: string, enum: [METRIC, IMPERIAL], nullable: true }
    timezone: { type: string, nullable: true }
    currency: { type: string, nullable: true }
    rulesUrl: { type: string, format: uri, nullable: true }
    enabledProviderIds: { type: array, items: { type: string }, nullable: true }
    requiredLicenseIds: { type: array, items: { type: string }, nullable: true }
    retentionPolicyDays: { type: integer, nullable: true }

DataLicense:
  type: object
  properties:
    id: { type: string }
    name: { type: string }
    spdxId: { type: string }
    redistributionMarkets: { type: array, items: { type: string } }

LicenseValidationResult:
  type: object
  properties:
    isValid: { type: boolean }
    errors: { type: array, items: { $ref: '#/ValidationError' } }
```

**API endpoints to add to `openapi.yaml`**:
- `GET /admin/markets` — list markets
- `GET /admin/markets/{code}` — get market
- `PUT /admin/markets/{code}/config` — create/update market config
- `GET /admin/markets/{code}/config` — get market config (merged with Vietnam defaults)
- `POST /admin/licenses/validate-redistribution` — validate licenses for a market

**Tests**:
- `packages/contracts/test/market/contracts_test.dart` — validate YAML syntax + refs

---

### Slice 3 — License Validation in Course Package Publish

**Goal**: Validate redistribution rights before publishing a course package to a market.

**Files to create/modify**:
```
packages/domain/lib/src/market/market_config_service.dart  # Resolves merged config + validates licenses
apps/api/src/modules/course-package/course_package_service.dart  # Add validation call before publish
```

**Logic**:
```
CoursePackageService.publish(courseId, marketCode, packageVersion):
  1. Load MarketConfig for marketCode (or empty if none)
  2. Merge with VietnamDefaults → effective config
  3. Load package.licenses[] (each has spdxId + redistributionMarkets)
  4. For each license, check: marketCode in license.redistributionMarkets?
  5. If any license rejects market → return LicenseValidationResult(isValid: false, errors: [...])
  6. Else → proceed with publish
```

**Structured error codes**:
- `LICENSE_REDISTRIBUTION_NOT_ALLOWED` — license doesn't permit this market
- `LICENSE_NOT_FOUND` — referenced license ID doesn't exist

**Tests**:
- `packages/domain/test/market/market_config_service_test.dart` — merge logic + license validation
- `packages/domain/test/market/license_redistribution_test.dart` — happy + denial cases

---

### Slice 4 — Market Config Resolution for Mobile/Portal Clients

**Goal**: Clients can fetch resolved market config (Vietnam defaults merged) for their market.

**Files to create/modify**:
```
apps/api/src/modules/market/market_controller.dart     # New
apps/api/src/modules/market/market_service.dart        # New
apps/api/src/modules/market/market_module.dart        # New
```

**Behavior**:
- `GET /markets/{code}/config` → returns fully resolved config (Vietnam defaults filled in)
- `GET /markets/{code}` → returns Market entity
- Mobile app reads `units`, `locale`, `currency`, `timezone` from resolved config

**Tests**:
- `apps/api/test/market/market_service_test.dart` — resolved config contains Vietnam defaults when no override

---

## Wave 1 (Slices 1–2): Domain + Contracts
- Slice 1: Domain entities + Vietnam defaults
- Slice 2: OpenAPI contracts

## Wave 2 (Slices 3–4): Validation + API
- Slice 3: License validation in publish flow
- Slice 4: Market config API endpoints

---

## Dependency Notes

- **Story 12.3** output not required for this story's domain models — payments/payments doesn't affect market config
- **Earlier epics** (1–11) foundations (course package contract from Epic 4, license field from Epic 3) are the relevant dependencies
- **No circular dependency**: this story adds new domain + contracts without modifying existing round/course/score models

## Verification Gates

| AC | Verification Method |
|---|---|
| AC1 (configurable by market) | Unit test: `MarketConfigService.getResolvedConfig('TH')` returns Thai locale + Vietnam defaults for unset fields |
| AC2 (Vietnam defaults) | Unit test: verify VietnamDefaults values; integration test: `GET /markets/VN/config` matches VietnamDefaults |
| AC3 (license validation) | Unit test: publish to market NOT in `redistributionMarkets` → structured error; happy path: all licenses allow → publish succeeds |
