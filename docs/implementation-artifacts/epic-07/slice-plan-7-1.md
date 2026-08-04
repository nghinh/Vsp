---
story: "7.1"
epic: 7
title: "Integrate and Cache Weather"
status: in-progress
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
slicePlanVersion: "1.0"
created: 2026-08-02
---

# Slice Plan — Story 7.1: Integrate and Cache Weather

## Context

**Story spec:** `docs/implementation-artifacts/epic-07/7-1-integrate-and-cache-weather.md`
**Epic:** 7 — Weather, Conditions, and Tournament Safety (MVP 1)
**Epic run folder:** `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

### Source contracts
- `packages/contracts/schemas/weather.yaml` — `WeatherSnapshot`, `WindData`, `WeatherForecast`, `WeatherAlert` (already exist)

### Source references
- PRD §8.9: wind direction/speed/gust, temperature, precipitation, safety fields
- PRD §10.16: weather and wind show timestamp and source
- Architecture §6.1: Weather Module is bounded module; §6.2 extraction candidate
- Architecture §11.2: `/weather/*` API group
- UX-Spec §6.2/Active Round: wind direction/speed on map; §191–196 Conditions screen: source, timestamp, stale warning

---

## Slice Definition

This is the **foundation slice** for Epic 7. All other epic-7 stories (7.2, 7.3, 7.4) depend on the contracts, models, repository, and caching infrastructure established here.

### Acceptance Criteria mapped to slices

| AC | Description | Slice |
|----|-------------|-------|
| AC-1 | Backend integrates a configured provider and caches responses | Slice 1 (backend) |
| AC-2 | Mobile shows wind d/s/g, temperature, precipitation, safety fields | Slice 2 (mobile) |
| AC-3 | Source, timestamp, forecast/measurement type, stale warning, offline snapshot visible | Slice 2 + Slice 3 |

---

## Wave 1 — Backend: Weather Provider + Redis Cache

**Layer ownership:** `apps/api/` (Go modular monolith)

### 1.1 Contracts / OpenAPI

**File:** `apps/api/modules/weather/contracts.yaml` (or extend existing API contracts)

Add to `apps/api/modules/weather/`:
```yaml
# GET /weather?lat={lat}&lng={lng}
# Response: WeatherSnapshot (from packages/contracts/schemas/weather.yaml)
# Headers: X-Weather-Source, X-Weather-Cached-At, X-Weather-Fresh-Until
# Cache-Control: max-age=1800 (30min)
```

### 1.2 Domain Model

**File:** `apps/api/modules/weather/domain/model.go`
```go
type WeatherSnapshot struct {
    ID              string    // provider + location + timestamp hash
    Provider        string    // e.g. "openweathermap", "tomorrow_io"
    Location        Location  // lat/lng
    CapturedAt      time.Time // when we captured from provider
    ExpiresAt       time.Time // when this snapshot becomes stale
    IsForecast      bool      // true = forecast snapshot, false = current/measured
    Temperature     *float64
    Humidity        *int
    Condition       string    // enum from contracts
    Wind            WindData
    Visibility      *float64  // km
    Pressure        *float64 // hPa
    FeelsLike       *float64
    PrecipitationProbability *int
    UVIndex         *int
    // source metadata
    SourceName      string    // display name of provider
    SourceTimestamp string    // raw timestamp from provider response
    // data quality
    AccuracyClass   string    // A/B/C/D from data quality model
    Confidence      float64   // 0.0–1.0
    VerificationStatus string // "official" | "community" | "estimated"
}
```

### 1.3 Provider Interface

**File:** `apps/api/modules/weather/provider.go`
```go
type WeatherProvider interface {
    Name() string
    Fetch(ctx context.Context, lat, lng float64) (*WeatherSnapshot, error)
}

// Configured implementations:
// - openweathermap_provider.go
// - tomorrowio_provider.go
// - mock_provider.go (for dev/testing)
```

### 1.4 Redis Cache

**File:** `apps/api/modules/weather/cache.go`

- Key pattern: `weather:{lat_rounded}:{lng_rounded}` (round to 3 decimal places ≈ 100m grid)
- TTL: 30 minutes default; configurable per provider
- On cache hit: return cached snapshot with `X-Weather-Cached-At` header
- On cache miss: call provider, store in Redis, return fresh
- Circuit breaker: if provider fails 3x in 5min, return stale cached (if available) with stale warning header

### 1.5 HTTP Handler

**File:** `apps/api/modules/weather/handler.go`

```
GET /weather?lat={lat}&lng={lng}
```

- Validate lat/lng (required, range check)
- Check Redis cache
- Return `WeatherSnapshot` JSON
- Headers: `X-Weather-Source`, `X-Weather-Cached-At`, `X-Weather-Fresh-Until`, `X-Weather-Stale` (bool)
- Errors: 400 (invalid coords), 502 (provider down + no cache), 500 (internal)

### 1.6 Service + Repository

**File:** `apps/api/modules/weather/service.go`
- Orchestrates cache + provider
- Records telemetry: provider call latency, cache hit/miss, staleness

### 1.7 Data Quality + Audit

- Snapshot stored with source, confidence, verification status
- Audit log entry on provider configuration change
- Telemetry: `weather.provider.failures`, `weather.cache.hits`, `weather.cache.misses`

### 1.8 Tests (Wave 1)

- Unit: provider interface (mock), cache key generation, TTL logic
- Integration: handler with mock provider, Redis integration test
- Negative: invalid lat/lng, provider timeout, Redis unavailable

---

## Wave 2 — Mobile: Weather Domain + Repository

**Layer ownership:** `apps/mobile/` (Flutter)

### 2.1 Domain Model

**File:** `apps/mobile/lib/domain/models/weather_snapshot.dart`
```dart
class WeatherSnapshot {
  final DateTime timestamp;
  final QualifiedLocation location;
  final Temperature? temperature;
  final int? humidity;
  final WeatherCondition condition;
  final WindData wind;
  final Visibility? visibility;
  final Pressure? pressure;
  final int? uvIndex;
  final double? feelsLike;
  final int? precipitationProbability;
  final WeatherSource source; // source name + type (forecast/measured)
  final DataFreshness freshness; // fresh / stale / expired
}
```

**File:** `apps/mobile/lib/domain/models/wind_data.dart`
```dart
class WindData {
  final double speed;
  final WindSpeedUnit unit;
  final WindDirection direction; // compass enum N/NE/E/SE/S/SW/W/NW
  final int degrees; // 0-360
  final double? gusts;
}
```

### 2.2 Repository Interface

**File:** `apps/mobile/lib/domain/repositories/weather_repository.dart`
```dart
abstract class WeatherRepository {
  Future<Either<WeatherError, WeatherSnapshot>> getWeather(QualifiedLocation location);
  Future<Either<WeatherError, WeatherSnapshot?>> getCachedWeather(String courseId);
  Future<void> cacheWeather(String courseId, WeatherSnapshot snapshot);
  Stream<WeatherSnapshot?> watchCachedWeather(String courseId);
}
```

### 2.3 Data Layer Implementation

**File:** `apps/mobile/lib/data/repositories/weather_repository_impl.dart`
- API client calls `GET /weather?lat={}&lng={}`
- Parse response headers: `X-Weather-Source`, `X-Weather-Cached-At`, `X-Weather-Stale`
- Store latest snapshot in SQLite (per course)
- Stale detection: compare `X-Weather-Fresh-Until` with current time

### 2.4 Local Storage (SQLite)

**File:** `apps/mobile/lib/data/local/daos/weather_dao.dart`
```sql
CREATE TABLE weather_snapshots (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL,
  captured_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  is_forecast INTEGER NOT NULL,
  provider TEXT NOT NULL,
  source_name TEXT NOT NULL,
  source_timestamp TEXT NOT NULL,
  json_data TEXT NOT NULL, -- full WeatherSnapshot JSON
  UNIQUE(course_id)
);
```

### 2.5 BLoC

**File:** `apps/mobile/lib/features/weather/presentation/weather_bloc.dart`
- Events: `LoadWeather`, `RefreshWeather`, `StartWatchingCache`
- States: `WeatherInitial`, `WeatherLoading`, `WeatherLoaded`, `WeatherStale`, `WeatherError`
- Handles: offline → return cached with stale flag; online → fetch fresh

---

## Wave 3 — Mobile: Conditions Screen Widget

**Layer ownership:** `apps/mobile/lib/features/weather/presentation/`

### 3.1 Weather Conditions Widget

**File:** `apps/mobile/lib/features/weather/presentation/widgets/weather_conditions_panel.dart`

Displays:
- Wind: direction arrow (accessible + text), speed, gusts
- Temperature + feels like
- Humidity %
- Precipitation probability
- Safety fields: UV index, pressure, visibility
- Source badge (provider name)
- Timestamp (relative: "Updated 5 min ago")
- Stale warning banner (red/gray with explicit text + icon, not color-only)
- Forecast/measured type badge

Accessibility:
- All icons have semantic labels
- Color not sole indicator (text labels always present)
- Minimum 44pt touch targets

### 3.2 Active Round Map Wind Overlay

**File:** `apps/mobile/lib/presentation/widgets/conditions/wind_indicator.dart`

- Wind direction arrow on map (from active-round map widget)
- Compact display: direction + speed only
- Accessible label: "Wind from SE at 15 km/h"

### 3.3 Stale Warning Behavior

- If `X-Weather-Stale: true` or cached snapshot expired:
  - Show amber banner: "Weather may be outdated. Last updated [time]."
  - Display stale badge on weather fields
  - Do NOT show forecast as current measurement

### 3.4 Loading / Error / Empty States

- Loading: shimmer skeleton on conditions panel
- Error: retry button with reason text
- No data: "Weather unavailable" with retry

---

## Implementation Order

```
Wave 1 (Backend) ─────────────────────────────────────┐
  Slice 1.1: OpenAPI contract                       │
  Slice 1.2: Domain model + provider interface       │  →  Epic orchestrator
  Slice 1.3: Redis cache layer                      │     dispatches implementer
  Slice 1.4: HTTP handler + service                 │     AFTER slice plan
  Slice 1.5: Unit + integration tests               │     approval
----------------------------------------------------─┘
Wave 2 (Mobile domain + data) ───────────────────────┐
  Slice 2.1: WeatherSnapshot + WindData models      │
  Slice 2.2: WeatherRepository interface            │  →  Second dispatch
  Slice 2.3: Repository impl + API client          │     after Wave 1 complete
  Slice 2.4: SQLite DAO + migration                │
  Slice 2.5: WeatherBloc                           │
  Slice 2.6: Unit tests                            │
----------------------------------------------------─┘
Wave 3 (Mobile UI) ──────────────────────────────────┐
  Slice 3.1: Conditions panel widget               │  →  Third dispatch
  Slice 3.2: Wind indicator on map                  │     after Wave 2 complete
  Slice 3.3: Stale warning + offline behavior     │
  Slice 3.4: Loading/error/empty states           │
  Slice 3.5: Accessibility audit                   │
----------------------------------------------------─┘
```

---

## Verification Checklist

### Backend
- [ ] `GET /weather?lat=10.823&lng=106.629` returns valid `WeatherSnapshot` JSON
- [ ] `X-Weather-Source`, `X-Weather-Cached-At`, `X-Weather-Fresh-Until` headers present
- [ ] Second call within TTL returns same data (cache hit)
- [ ] Invalid lat/lng returns 400 with structured error
- [ ] Provider failure with no cache returns 502
- [ ] Provider failure WITH stale cache returns 200 + `X-Weather-Stale: true`
- [ ] Redis TTL expires → fresh fetch on next request
- [ ] Audit log records provider configuration
- [ ] Telemetry: `weather.provider.failures`, `weather.cache.hits`, `weather.cache.misses`

### Mobile
- [ ] `WeatherSnapshot` deserializes from API response correctly
- [ ] Cached snapshot loads when offline
- [ ] Stale cached snapshot shows stale warning banner
- [ ] Conditions panel shows all required fields
- [ ] Source badge shows provider name
- [ ] Timestamp shows relative time
- [ ] Forecast/measured type badge visible
- [ ] Loading skeleton shows while fetching
- [ ] Error state shows retry with reason
- [ ] All icons have semantic labels for screen readers
- [ ] Color not sole indicator for any status
- [ ] Touch targets ≥ 44pt

### Cross-cutting
- [ ] OpenAPI contract updated for `/weather` endpoint
- [ ] No hardcoded secrets (provider API key from config/env)
- [ ] Rate limiting applied per architecture §11.3
- [ ] Structured errors with correlation ID

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Weather provider down → broken UX | Return stale cache + warning; circuit breaker; monitor provider uptime |
| Cache stampede on cold start | Use singleflight / distributed lock on cache miss |
| Mobile offline for extended time → stale weather | Explicit stale warning; show timestamp prominently; don't present as current |
| Cost of provider calls | Redis cache 30min TTL; only poll when golfer is active on course |
| Provider API key in repo | External env/config; rotate without deploy |
| Coordinate precision for cache key | Round to 3 decimals (~100m grid); avoids cache fragmentation |

---

## Dependencies on Earlier Waves

- Story 7.1 is the **first story of Epic 7** — no epic-7 dependencies
- Backend foundation (Story 1.2: modular monolith) must be complete
- API contracts (Story 1.3) must be complete for `/weather/*` endpoint definition
- Mobile: domain model foundations from Epic 1-3 are available
- Location service (Story 6.1) provides `QualifiedLocation` used here

---

## Non-Scope (Deferred to 7.2, 7.3, 7.4)

- Wind relative to shot line vector calculation (7.2)
- Official pin/course condition display (7.3)
- Tournament mode restriction enforcement (7.4)
- Historical weather / forecast aggregation (future)
- Push notifications for weather alerts (future)
