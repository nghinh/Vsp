---
stepsCompleted:
  - step-01-init
  - autonomous-architecture-generation
inputDocuments:
  - docs/requirements.md
  - docs/planning-artifacts/prd.md
  - docs/project-context.md
workflowType: architecture
project_name: vsp
user_name: nghinh
date: 2026-08-01
documentStatus: draft
---

# Architecture Decision Document - Vietnam Smart Golf Platform

## 1. Architecture Intent

Build a reliable, offline-first golf GPS platform before scaling into smartwatch, performance analytics, tournaments, and AI Smart Caddie. Architecture prioritizes boring technology, geospatial correctness, local-first mobile behavior, and a clean data-quality loop between golfer app and course operations portal.

## 2. Key Architectural Decisions

| Area | Decision | Rationale | Trade-off |
| --- | --- | --- | --- |
| Mobile | Flutter | Single iOS/Android codebase, strong UI velocity, native bridge support | Native modules still required for GPS/sensors/watch |
| Map SDK | MapLibre Flutter | Open, cost-controllable, supports vector layers and offline patterns | More ownership than fully managed Mapbox |
| Geospatial DB | PostgreSQL + PostGIS | Mature source of truth for geometry, distance, spatial queries | Requires GIS discipline and indexing |
| Offline maps | PMTiles or MapLibre offline regions | Predictable course packages and weak-network support | Package pipeline must be built early |
| Backend style | Modular monolith first, service boundaries explicit | Faster MVP delivery, fewer distributed-system costs | Must preserve boundaries for later extraction |
| Sync | Local event queue + idempotent APIs | No score loss offline, safe retry | More client state complexity |
| Portal | Web app backed by same APIs | Course-data loop is core MVP capability | Requires admin RBAC/audit from day one |
| AI | Deferred architecture hooks only | AI needs accurate course and shot data first | Smart Caddie not delivered in MVP |

## 3. System Context

Primary systems:

- Golfer Mobile App: Flutter app for course search, offline package download, GPS, map, target, scorecard, and correction submission.
- Course Operations Portal: web portal for course metadata, geometry editing, pin/green/course condition updates, alerts, correction review, publish/rollback.
- Backend API Platform: identity, courses, packages, rounds, scores, weather, corrections, audit, sync.
- Geospatial Data Platform: PostgreSQL/PostGIS source of truth for course geometry and spatial calculations.
- Object Storage/CDN: course packages, vector tiles, PMTiles, media, import artifacts.
- External Providers: auth providers, weather provider, optional satellite imagery, licensed course data.

## 4. Logical Architecture

```text
Flutter Mobile App
  ├─ Local SQLite / encrypted storage / event queue
  ├─ MapLibre runtime + offline course packages
  └─ HTTPS API sync

Course Operations Portal
  └─ HTTPS Admin APIs

Backend API Platform
  ├─ Identity & Access
  ├─ Course Catalog
  ├─ Geospatial Service
  ├─ Course Package Service
  ├─ Round & Score Service
  ├─ Weather Service
  ├─ Correction Workflow
  ├─ Audit & Versioning
  └─ Notification hooks

Data & Infrastructure
  ├─ PostgreSQL + PostGIS
  ├─ Redis
  ├─ Object Storage
  ├─ CDN
  └─ Message Queue / Event Stream
```

## 5. Deployment Architecture

MVP deployment should stay simple:

- Mobile apps distributed through App Store and Google Play.
- Portal deployed as static web frontend plus API backend.
- Backend deployed as containerized modular monolith.
- PostgreSQL with PostGIS as managed database where possible.
- Redis as managed cache.
- Object storage and CDN for course package distribution.
- Queue for async package builds, correction processing, telemetry, and notifications.

Recommended environments:

- `dev`: local developer stack with seeded pilot data.
- `staging`: production-like integration, pilot-course validation.
- `prod`: locked RBAC, backups, monitoring, CDN, audit retention.

## 6. Backend Architecture

### 6.1 Modular Monolith Boundaries

Start with one deployable backend organized by bounded modules:

- Identity Module
- User Profile Module
- Course Catalog Module
- Geospatial Module
- Course Package Module
- Round Module
- Score Module
- Weather Module
- Correction Module
- Course Operations Module
- Audit Module
- Notification Module

Each module owns its domain logic and database access through explicit internal interfaces. Cross-module access happens through service interfaces, not direct table coupling where avoidable.

### 6.2 Extraction Candidates

Only extract into separate services after scale or team ownership demands it:

1. Course Package Service: CPU/storage-heavy tile/package generation.
2. Weather Service: provider polling and caching.
3. Notification Service: async fan-out.
4. Analytics/AI Services: phase 2+ data processing.

## 7. Data Architecture

### 7.1 Source of Truth

PostgreSQL + PostGIS is the canonical source for:

- Facilities, courses, holes, tee sets.
- Geometry layers: tee, fairway, rough, green, bunker, water, penalty area, OB, cart path, landmarks.
- Pin positions, green conditions, course conditions.
- Rounds, scores, corrections, data versions, licenses.

### 7.2 Spatial Practices

- Store WGS84 geometry with SRID 4326.
- Use GeoJSON for API interchange and imports/exports.
- Use GIST indexes for spatial columns.
- Use `ST_DWithin` for nearby course and range queries.
- Use geography or appropriate projection for meter-based distance calculations.
- Keep geometry validity checks in import and publish workflow.

### 7.3 Versioning Model

Course data is append-versioned:

- Draft version for portal edits.
- Published version for mobile packages.
- Effective and expiration dates for pins, green speed, weather snapshots, and conditions.
- Rollback creates a new published version referencing prior data.
- Mobile stores course package version and sync cursor.

### 7.4 Data Quality Model

Every data object carries:

- Source
- License
- Accuracy class
- Confidence
- Verification status
- Created/updated/verified timestamps
- Effective/expiration timestamps
- Publisher
- Version

Priority order: Class A → B → C → D.

## 8. Mobile Architecture

### 8.1 Flutter App Layers

- Presentation: screens/widgets optimized for glanceable on-course use.
- Application: use cases for course download, round setup, GPS updates, score entry, sync.
- Domain: course, hole, geometry, round, score, target, weather, confidence models.
- Infrastructure: API client, SQLite repositories, encrypted storage, MapLibre adapter, GPS/sensor adapter.

### 8.2 Local Storage

- SQLite for course metadata, downloaded package manifest, rounds, scores, local events, and sync cursors.
- Encrypted storage for auth tokens and sensitive account/session data.
- File storage for map packages and large assets.

### 8.3 Offline Sync

- All on-course writes are first persisted locally.
- Client writes append events to local event queue.
- Sync worker retries idempotent API calls when online.
- Server deduplicates by idempotency key.
- Conflict policy:
  - Score edits: latest client edit with audit history.
  - Course official data: server wins.
  - Corrections: append-only workflow.

### 8.4 GPS and Battery

- Adaptive location update frequency.
- Reduce GPS polling when stationary.
- Avoid auto-hole switch when GPS accuracy exceeds threshold.
- Capture GPS accuracy, stale position flag, and confidence.
- Background processing limited to sync and essential location behavior.

## 9. Map Architecture

### 9.1 Runtime Map Rendering

Use MapLibre Flutter with:

- Vector sources for course geometry.
- Fill layers for fairway, rough, green, bunker, water, OB.
- Line layers for cart paths, shot paths, distance rings.
- Symbol/circle layers for golfer position, pin, targets, landmarks.
- High-contrast style for sunlight readability.

### 9.2 Offline Course Package

Course package contains:

- Manifest with version, checksum, size, effective date.
- Course metadata and hole metadata.
- Vector tiles or PMTiles.
- GeoJSON geometry subset for local calculations.
- Pin/green/course condition snapshots.
- Scorecard definitions and local rules.
- Optional satellite assets if licensed.

### 9.3 Package Generation Pipeline

1. Course admin publishes data version.
2. Backend validates geometry and licenses.
3. Async worker generates vector tiles/PMTiles and manifest.
4. Package uploaded to object storage.
5. CDN invalidation/version publication.
6. Mobile detects available version and downloads incrementally.

## 10. Portal Architecture

Course Operations Portal capabilities:

- Facility and course management.
- Geometry editor with draw/edit/snap/undo/publish/rollback.
- GeoJSON/KML/KMZ/Shapefile/CSV import pipeline.
- Pin position scheduling.
- Green speed and course condition updates.
- Course alerts.
- Correction review workflow.
- Audit log viewer.

Portal must use admin RBAC from day one:

- Super Admin
- Course Admin
- Greenkeeper
- Tournament Director
- Caddie Master
- Read-only Auditor

## 11. API Architecture

### 11.1 API Style

REST APIs are sufficient for MVP. Use OpenAPI for contract generation and frontend/backend alignment.

### 11.2 Minimum API Groups

- `/auth/*`
- `/users/*`
- `/profiles/*`
- `/courses/*`
- `/courses/{id}/versions/*`
- `/courses/{id}/packages/*`
- `/holes/*`
- `/rounds/*`
- `/scores/*`
- `/weather/*`
- `/corrections/*`
- `/admin/courses/*`
- `/admin/audit/*`

### 11.3 API Cross-Cutting Requirements

- TLS only.
- Authenticated APIs by default.
- RBAC on admin APIs.
- Idempotency keys for write/sync endpoints.
- Pagination for list endpoints.
- ETags or version fields for course package checks.
- Rate limits on public/auth/weather endpoints.
- Structured errors with stable codes.

## 12. Security Architecture

- OAuth/OIDC-compatible identity strategy.
- Short-lived access tokens.
- Refresh-token rotation.
- Encrypted token storage on mobile.
- MFA for admin users.
- RBAC on portal and APIs.
- Audit every course publish, rollback, pin update, green update, condition update, and admin login.
- Encrypt database storage and object storage.
- No secrets in mobile app or repository.
- Privacy controls for location, score, round sharing, deletion, and export.

## 13. Observability Architecture

Collect:

- Mobile crashes.
- Map load time.
- GPS accuracy and stale-position events.
- Hole-detection confidence and override events.
- Course package download success/failure.
- Sync queue depth and retry count.
- API latency/error rate.
- Weather provider failures.
- Portal publish/rollback events.
- Battery telemetry per round.

Use correlation IDs across mobile sync requests and backend logs.

## 14. Quality Gates

MVP architecture is ready when:

1. One pilot course package can be generated, downloaded, and rendered offline.
2. Front/center/back and hazard distances can be computed from local data.
3. Score entry persists offline and syncs idempotently.
4. Portal can edit geometry and publish a new version.
5. Mobile can detect and download a new course package version.
6. Admin changes are audited.
7. GPS low-confidence behavior prevents unsafe auto-hole switching.
8. Basic Tournament Mode restrictions are represented in config and UI.

## 15. Deferred Architecture Hooks

Keep extension points, but do not build full systems yet:

- Watch adapter boundary for Apple Watch and Wear OS.
- Shot event schema for future shot tracking.
- Club performance model for future dispersion and recommendations.
- Feature store export path for Smart Caddie.
- Tournament policy model for future tournament platform.
- Analytics event schema for phase 2+.

## 16. Architecture Risks

| Risk | Mitigation |
| --- | --- |
| Over-service decomposition too early | Modular monolith first, clear boundaries |
| Offline sync complexity | Event queue, idempotency keys, server dedupe |
| Map package pipeline underestimated | Build package generator in first milestone |
| Bad geospatial calculations | PostGIS source of truth, validation fixtures, RTK checkpoints |
| Battery drain | Adaptive GPS, telemetry, low-power map behavior |
| Provider lock-in | GeoJSON/PostGIS/PMTiles standards, MapLibre-first |
| Portal treated as secondary | Make publish/version/audit part of MVP quality gate |
| AI pressure before data readiness | Explicitly defer AI; keep schemas only |

## 17. Recommended Repository Shape

```text
apps/
  mobile/          # Flutter app
  portal/          # Course Operations Portal
  api/             # Backend modular monolith
packages/
  contracts/       # OpenAPI, shared DTO schemas
  domain/          # Shared domain model specs where practical
  map-style/       # MapLibre styles and layer definitions
  course-package/  # Package manifest schema and tooling
docs/
  planning-artifacts/
  implementation-artifacts/
infra/
  docker/
  migrations/
  scripts/
```

If current repo remains documentation-only, treat this as target implementation structure, not an immediate refactor requirement.

## 18. Context7 References

- Flutter: `/flutter/website`
- MapLibre Flutter: `/maplibre/flutter-maplibre-gl`
- PostGIS: `/websites/postgis_net`

## 19. Final Recommendation

Ship the MVP as a Flutter + MapLibre mobile app, a web Course Operations Portal, and a modular monolith backend with PostgreSQL/PostGIS, Redis, object storage, CDN, and async workers. The first architectural milestone is not user accounts or AI. It is a verified pilot course package that renders offline, computes reliable distances, and can be updated through the portal with versioned audit history.
