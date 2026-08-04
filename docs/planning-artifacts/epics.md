---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - docs/planning-artifacts/prd.md
  - docs/planning-artifacts/architecture.md
  - docs/planning-artifacts/ux-spec.md
  - docs/project-context.md
workflowType: epics-and-stories
documentStatus: draft
project_name: vsp
user_name: nghinh
date: 2026-08-01
---

# Vietnam Smart Golf Platform - Epic Breakdown

## Overview

This document decomposes the PRD, architecture, and UX specification into implementation-ready epics and stories. Epics 1–9 form MVP 1: **Reliable Golf GPS + Course Operations Data Loop**. Epics 10–12 represent later product phases and must not block MVP 1.

## Requirements Inventory

### Functional Requirements

- **FR1:** Users can register and authenticate with phone, email, Google, or Apple and manage account lifecycle.
- **FR2:** Golfers can manage profile, preferences, distance units, handicap, and golf bag.
- **FR3:** Users can search nearby, favorite, and recently played courses and view course details.
- **FR4:** Users can download, update, inspect, and delete offline course packages.
- **FR5:** Users can configure and start Casual, Practice, or Tournament rounds for up to four golfers.
- **FR6:** The app detects facility, course, and likely hole while supporting manual override.
- **FR7:** The app renders strategic course geometry, golfer position, pin, targets, wind, and hazards.
- **FR8:** The app displays front/center/back green and hazard near/far/carry distances.
- **FR9:** Golfers can place a target and view ball-to-target and target-to-pin distances.
- **FR10:** The app displays weather and wind with source, timestamp, and stale-data status.
- **FR11:** Golfers can record scores for up to four players and complete a round offline.
- **FR12:** Golfers can submit geolocated course-data corrections with photo or note.
- **FR13:** Course operators can manage facility, course, hole, tee, and scorecard metadata.
- **FR14:** Course operators can draw, edit, import, validate, publish, and roll back geometry.
- **FR15:** Course operators can schedule pin positions and update green/course conditions.
- **FR16:** Course operators can create targeted course and safety alerts.
- **FR17:** Course operators can review, approve, reject, and resolve correction submissions.
- **FR18:** The system preserves course versions, effective dates, expiration, publisher, and audit history.
- **FR19:** Tournament Mode can restrict disallowed assistance features and lock after round start.
- **FR20:** The system packages published course data and distributes versioned offline assets.
- **FR21:** Later phases support smartwatch scoring, distances, target control, and shot detection.
- **FR22:** Later phases support club performance, dispersion, Driving Zone, and round analytics.
- **FR23:** Later phases support explainable Smart Target and club recommendations.
- **FR24:** Later phases support tournaments, booking, payment, membership, loyalty, and course ecosystem services.

### Non-Functional Requirements

- **NFR1:** Cached hole screen loads in under 2 seconds.
- **NFR2:** Distance values update within 1 second of a location update.
- **NFR3:** A full 18-hole round works offline without score loss.
- **NFR4:** Mobile devices complete 18 holes within the agreed battery target.
- **NFR5:** Backend production availability target is at least 99.9%.
- **NFR6:** Writes use local persistence, retry, idempotency, and server deduplication.
- **NFR7:** GPS accuracy is visible; stale or >10m-error positions trigger warning behavior.
- **NFR8:** At least 95% of critical course points are correctly mapped at pilot courses.
- **NFR9:** TLS, encryption at rest, token expiry, refresh rotation, RBAC, admin MFA, and rate limiting are enforced.
- **NFR10:** Account/round deletion, data export, consent, and retention controls are supported.
- **NFR11:** Admin and course-data mutations are auditable.
- **NFR12:** Text contrast, touch targets, screen-reader semantics, dynamic text, and reduced motion meet accessibility requirements.
- **NFR13:** Mobile and portal use semantic design tokens, predictable navigation, and visible loading/error states.
- **NFR14:** Spatial queries use valid WGS84 data, appropriate distance calculations, and GIST indexes.
- **NFR15:** Telemetry covers crashes, GPS quality, map load, package failures, sync, battery, API health, and audit events.

### Architecture Requirements

- Use Flutter for iOS/Android and MapLibre Flutter for maps.
- Use SQLite, encrypted storage, file storage, and a local event queue on mobile.
- Use a modular monolith backend with explicit domain module boundaries.
- Use PostgreSQL/PostGIS as geospatial source of truth and Redis for caching.
- Use object storage and CDN for immutable versioned course packages.
- Use asynchronous workers/queue for package builds, imports, notifications, and telemetry.
- Use REST with OpenAPI, stable errors, pagination, idempotency keys, and ETags/version fields.
- Represent course publication as draft → validate → publish → package → distribute.
- Keep smartwatch, shot events, analytics, and AI as deferred extension points.

### UX Design Requirements

- **UX-DR1:** Active-round critical information is readable in under two seconds.
- **UX-DR2:** Frequent actions require no more than two taps and support one-hand use.
- **UX-DR3:** Touch targets are at least 44pt iOS/48dp Android with visible press feedback.
- **UX-DR4:** Front/center/back distances remain continuously visible on the active-round map.
- **UX-DR5:** GPS, offline, sync, official, estimated, and stale states use text/icon plus color.
- **UX-DR6:** Mobile bottom navigation contains no more than five predictable destinations.
- **UX-DR7:** Loading, retry, empty, disabled, and error states exist for all asynchronous workflows.
- **UX-DR8:** Flutter custom controls use Semantics and work with VoiceOver/TalkBack.
- **UX-DR9:** Course editor exposes layer controls, undo/redo, validation, diff, publish notes, and unsaved-change guard.
- **UX-DR10:** Semantic colors, typography, spacing, icon, focus, and motion tokens are shared across surfaces.
- **UX-DR11:** Safe areas, large text, reduced motion, high contrast, phone/tablet, and landscape are supported.
- **UX-DR12:** Official, community, estimated, expired, and unverified data are visually distinguishable.

## Epic List

| Epic | Goal | Phase |
| --- | --- | --- |
| 1. Platform Foundation | Establish deployable mobile, portal, API, data, contracts, and observability foundations | MVP 1 |
| 2. Identity and Golfer Profile | Securely onboard golfers and administer roles | MVP 1 |
| 3. Course Catalog and Data Foundation | Create trusted, searchable geospatial course data | MVP 1 |
| 4. Offline Course Packages | Publish and consume versioned offline course packages | MVP 1 |
| 5. Round Setup and Local-First Scoring | Complete rounds without network or score loss | MVP 1 |
| 6. Live Golf GPS Experience | Deliver reliable map, distance, target, and hole detection | MVP 1 |
| 7. Weather, Conditions, and Tournament Safety | Show timely conditions and enforce allowed features | MVP 1 |
| 8. Course Operations Portal | Maintain official course data and audit publication | MVP 1 |
| 9. Correction and Data Quality Loop | Turn golfer feedback into verified course updates | MVP 1 |
| 10. Smartwatch and Shot Tracking | Add watch-first interactions and shot capture | MVP 2 |
| 11. Performance Analytics and Smart Caddie | Build explainable performance and strategy intelligence | MVP 2–3 |
| 12. Tournament and Smart Golf Ecosystem | Expand into tournament and commercial platform services | MVP 4 |

## Requirements Coverage Map

- FR1–FR2 → Epic 2
- FR3, FR13, FR18 → Epic 3
- FR4, FR20 → Epic 4
- FR5, FR11 → Epic 5
- FR6–FR9 → Epic 6
- FR10, FR15, FR16, FR19 → Epic 7
- FR13–FR16, FR18 → Epic 8
- FR12, FR17–FR18 → Epic 9
- FR21 → Epic 10
- FR22–FR23 → Epic 11
- FR24 → Epic 12
- NFR1–NFR15 and UX-DR1–UX-DR12 apply across relevant stories and quality gates.

# Epic 1: Platform Foundation

Establish a boring, productive foundation that supports mobile, portal, API, geospatial data, contracts, deployment, security, and observability.

### Story 1.1: Initialize Repository and Delivery Environments

As a development team, I want a consistent project structure and environments so that all work can build and deploy predictably.

**Acceptance Criteria:**

- **Given** the target architecture, **when** the repository is initialized, **then** it contains mobile, portal, API, contracts, map-style, course-package, docs, and infrastructure boundaries.
- **Given** developer setup, **when** bootstrap commands run, **then** dependencies, local database, and required services start from documented configuration.
- **Given** code changes, **when** CI runs, **then** format, lint, typecheck, test, build, migration, and secret checks execute.

### Story 1.2: Establish Backend Modular Monolith

As a backend developer, I want explicit domain modules so that MVP velocity does not create uncontrolled coupling.

**Acceptance Criteria:**

- Modules exist for identity, profiles, courses, geospatial, packages, rounds, scores, weather, corrections, operations, audit, and notifications.
- Cross-module calls use defined service interfaces rather than arbitrary table access.
- Health and readiness endpoints report application and database status.

### Story 1.3: Establish API Contracts and Error Standards

As a client developer, I want versioned OpenAPI contracts so that mobile, portal, and backend remain aligned.

**Acceptance Criteria:**

- OpenAPI defines auth, courses, packages, rounds, scores, weather, corrections, and admin endpoints.
- APIs return stable machine-readable error codes and correlation IDs.
- Write endpoints support idempotency keys; list endpoints support pagination; version checks support ETags or version fields.

### Story 1.4: Establish Design System Foundations

As a product team, I want shared semantic design foundations so that mobile and portal remain accessible and consistent.

**Acceptance Criteria:**

- Semantic color, typography, spacing, icon, focus, elevation, state, and motion tokens are defined.
- Components support high contrast, large text, reduced motion, loading/error/disabled states, and visible focus.
- No structural emoji icons or ad-hoc component colors are used.

### Story 1.5: Establish Observability and Security Baseline

As an operator, I want secure telemetry from the first deploy so that failures are diagnosable without exposing sensitive data.

**Acceptance Criteria:**

- Structured logs, metrics, traces/correlation IDs, and environment-specific alerting are configured.
- Secrets are externally managed and never shipped in clients or committed.
- TLS, encryption at rest, dependency scanning, backups, and audit retention are configured.

# Epic 2: Identity and Golfer Profile

Securely onboard golfers while supporting administrator roles and privacy lifecycle operations.

### Story 2.1: Register and Authenticate Golfer

As a golfer, I want to register with phone, email, Google, or Apple so that I can access the platform using a trusted method.

**Acceptance Criteria:**

- Phone/email registration supports verification and password recovery where applicable.
- Google and Apple authentication link to one canonical account when verified identifiers match.
- Auth failures expose clear, field-level, non-sensitive feedback.

### Story 2.2: Manage Sessions Securely

As a golfer, I want secure device sessions so that I can control account access.

**Acceptance Criteria:**

- Access tokens are short-lived and refresh tokens rotate.
- Tokens are stored in encrypted device storage.
- User can list and revoke sessions; revoked sessions cannot refresh.

### Story 2.3: Manage Golfer Profile and Preferences

As a golfer, I want to manage personal golf preferences so that distances and round defaults fit me.

**Acceptance Criteria:**

- Profile supports required identity, handicap, home club, unit, hand, skill, target, and distance fields.
- Unit changes update displayed distances without corrupting canonical values.
- Offline profile edits queue and synchronize safely.

### Story 2.4: Manage Golf Bag and Clubs

As a golfer, I want to maintain golf bags and clubs so that rounds can reference my active equipment.

**Acceptance Criteria:**

- User can create bags and add/edit/delete clubs with loft, carry, total, dispersion, shaft, and use date.
- Exactly one bag can be selected as active for a round.
- Data-driven recommendations remain disabled until minimum data threshold is met.

### Story 2.5: Administer Roles and Privacy Requests

As an administrator, I want role controls and privacy workflows so that privileged access and user rights are enforced.

**Acceptance Criteria:**

- RBAC supports super admin, course admin, greenkeeper, tournament director, caddie master, and auditor.
- Admin accounts require MFA.
- Users can request data export, account deletion, and round deletion with auditable processing.

# Epic 3: Course Catalog and Data Foundation

Create a trusted geospatial source of truth that golfers can search and operators can maintain.

### Story 3.1: Model Course and Golf Geometry

As a GIS administrator, I want standardized course entities and geometries so that all clients use consistent data.

**Acceptance Criteria:**

- PostGIS schema represents facilities, courses, holes, tees, fairways, rough, greens, bunkers, water, penalty areas, OB, paths, and landmarks.
- Geometry uses SRID 4326, validity constraints, and GIST indexes.
- Every object contains source, license, quality, confidence, verification, effective/expiry, publisher, and version metadata.

### Story 3.2: Search and Discover Courses

As a golfer, I want to search by name, location, favorites, recent, and nearby so that I can quickly find where I am playing.

**Acceptance Criteria:**

- Search supports text and geographic filters with paginated results.
- Nearby search uses index-aware spatial filtering.
- Results show verification, data freshness, download, and update state.

### Story 3.3: View Course Details

As a golfer, I want complete course details so that I can prepare before starting a round.

**Acceptance Criteria:**

- Details include contact, coordinates, facilities, holes, tee sets, local rules, ratings, current conditions, and update time.
- Unavailable data is shown as unavailable rather than fabricated.
- Official, estimated, stale, and community data are distinguishable by text/icon and color.

### Story 3.4: Import and Validate Course Data

As a GIS administrator, I want to import common formats so that pilot courses can be onboarded efficiently.

**Acceptance Criteria:**

- Import supports GeoJSON and prioritized MVP formats, retaining source/license metadata.
- Invalid coordinates, topology, geometry, or required attributes produce actionable errors.
- Imported data remains draft until reviewed and published.

# Epic 4: Offline Course Packages

Publish and consume immutable, versioned course packages so the round experience works without internet.

### Story 4.1: Define Course Package Contract

As a mobile developer, I want a stable package manifest so that clients can validate and use downloaded course data.

**Acceptance Criteria:**

- Manifest defines course/version identifiers, checksums, size, effective time, files, minimum client version, and licenses.
- Package contains metadata, local geometry, vector/PMTiles assets, scorecard, rules, and condition snapshots.
- Corrupt or incompatible packages are rejected without replacing the last valid package.

### Story 4.2: Generate and Publish Course Packages

As a course operator, I want publication to generate downloadable packages so golfers receive official updates.

**Acceptance Criteria:**

- Publishing queues validation, package build, upload, and CDN publication.
- Build status and actionable failures are visible in portal.
- Published package URLs are immutable and versioned.

### Story 4.3: Download and Manage Offline Courses

As a golfer, I want to download and manage course packages so that I can play with no network.

**Acceptance Criteria:**

- App shows package size, version, update time, Wi-Fi preference, progress, retry, and completion.
- User can update and delete packages without deleting round/score data.
- Downloaded courses expose an explicit offline-ready state.

### Story 4.4: Incrementally Update Course Data

As a golfer, I want efficient package updates so that fresh course data does not require wasteful full downloads.

**Acceptance Criteria:**

- Client checks version/ETag and downloads only required changed artifacts where supported.
- Update is atomic and rolls back to last valid version on failure.
- Active rounds are not silently switched to a new package version.

# Epic 5: Round Setup and Local-First Scoring

Allow golfers to configure, play, and complete rounds without network dependence or score loss.

### Story 5.1: Configure and Start a Round

As a golfer, I want to configure course, tee, format, players, mode, bag, and starting hole so that the round matches my game.

**Acceptance Criteria:**

- User can configure up to four players and required round options.
- App suggests nearby course/layout/starting hole but allows override.
- Round start validates an offline-ready course package or clearly warns of limitations.

### Story 5.2: Persist Round Locally

As a golfer, I want all round changes saved locally first so that network failures never lose my game.

**Acceptance Criteria:**

- Round, hole, player, score, and sync event changes are transactionally persisted in SQLite.
- App restart restores an incomplete round.
- UI immediately confirms offline save state.

### Story 5.3: Enter Scores for a Flight

As a scorer, I want fast score entry for up to four golfers so that scoring does not slow play.

**Acceptance Criteria:**

- Gross score is the primary entry; putts, penalties, fairway, GIR, bunker, and notes are available progressively.
- Frequent score actions take no more than two taps and have 44/48dp touch targets.
- Score indicators do not rely on color alone.

### Story 5.4: Synchronize Round Idempotently

As a golfer, I want automatic synchronization when connectivity returns so that cloud history matches local data.

**Acceptance Criteria:**

- Local events carry unique idempotency keys and retry with backoff.
- Server deduplicates repeated submissions.
- Pending, syncing, synced, and failed states are visible with retry action.

### Story 5.5: Complete and Review Round

As a golfer, I want to complete a round and see a summary so that I can verify results and fix mistakes later.

**Acceptance Criteria:**

- Completion works offline and marks pending synchronization when required.
- Summary displays hole scores, totals, basic stats, and sync state.
- User can reopen permitted fields for correction with audit history.

# Epic 6: Live Golf GPS Experience

Deliver the core value: trustworthy course detection, outdoor map rendering, distances, hazards, and target interaction.

### Story 6.1: Acquire and Qualify Location

As a golfer, I want clear GPS quality so that I understand whether displayed distances are trustworthy.

**Acceptance Criteria:**

- Location includes coordinates, accuracy, age, timestamp, and movement direction.
- Accuracy above 10m or stale positions trigger warning state.
- Battery-aware sampling reduces updates when stationary while preserving active play responsiveness.

### Story 6.2: Detect Course and Hole

As a golfer, I want automatic course/hole detection so that the app follows play with minimal interaction.

**Acceptance Criteria:**

- Detection combines proximity, hole geometry, direction, and confidence.
- Low-confidence detection does not auto-switch holes.
- User can manually select a hole; overrides and incorrect detections are logged.

### Story 6.3: Render Strategic Hole Map

As a golfer, I want a clear strategic map so that I can understand the hole and hazards outdoors.

**Acceptance Criteria:**

- MapLibre renders required course layers, pin, golfer, target, wind, and rings from local package data.
- High-contrast style remains readable in sunlight and supports safe areas and large text.
- Cached hole map loads in under 2 seconds on target devices.

### Story 6.4: Calculate Green and Hazard Distances

As a golfer, I want front/center/back and hazard distances so that I can choose a safe shot.

**Acceptance Criteria:**

- Local calculations produce green front/center/back, bunker/water near/far, and carry values in selected unit.
- Values update within 1 second after location update.
- UI shows GPS accuracy, source, timestamp, and confidence without claiming unsupported precision.

### Story 6.5: Place and Move a Target

As a golfer, I want to select a target so that I can evaluate intended landing and remaining distance.

**Acceptance Criteria:**

- Tap places a target and displays ball-to-target and target-to-pin distance.
- Drag behavior, if enabled, does not conflict with map pan/zoom.
- Target remains visible and usable offline.

### Story 6.6: Validate Pilot GPS Accuracy and Battery

As a product team, I want field validation against pilot checkpoints so that MVP reliability is proven.

**Acceptance Criteria:**

- Test protocol compares displayed distances against agreed RTK checkpoints.
- At least 95% of critical points meet agreed mapping criteria.
- Target devices complete 18 holes within battery goal; GPS/map latency telemetry is recorded.

# Epic 7: Weather, Conditions, and Tournament Safety

Show timely external and official conditions while preventing disallowed assistance in tournament play.

### Story 7.1: Integrate and Cache Weather

As a golfer, I want current weather and wind so that I understand playing conditions.

**Acceptance Criteria:**

- Backend integrates a configured provider and caches responses to control cost.
- Mobile shows wind direction/speed/gust, temperature, precipitation, and supported safety fields.
- Source, timestamp, forecast/measurement type, stale warning, and offline snapshot are visible.

### Story 7.2: Display Wind Relative to Shot Line

As a golfer, I want wind represented relative to my target so that it is immediately actionable.

**Acceptance Criteria:**

- App derives headwind, tailwind, and left/right crosswind from shot line.
- Missing or stale wind does not generate false precision.
- Wind indicator remains accessible without relying on arrow color alone.

### Story 7.3: Display Official Pin and Course Conditions

As a golfer, I want verified pin, green speed, and course condition data so that I can make informed decisions.

**Acceptance Criteria:**

- UI shows official status, source, effective/expiry time, confidence, and stale state.
- Expired exact pin data is never presented as current official data.
- Cached conditions remain available offline with timestamp.

### Story 7.4: Enforce Tournament Mode Restrictions

As a tournament organizer, I want restricted assistance disabled so that the app complies with configured rules.

**Acceptance Criteria:**

- Policy can disable plays-like, elevation, wind adjustment, club recommendation, contours, putting help, and AI.
- Locked mode cannot be changed after round start without authorized workflow.
- Enabled policy and changes are auditable; restricted controls are hidden or disabled with explanation.

# Epic 8: Course Operations Portal

Give course operators the tools to maintain official data, publish safely, and recover through versioning.

### Story 8.1: Manage Facilities and Courses

As a course administrator, I want to manage facility and course metadata so that golfers receive accurate official details.

**Acceptance Criteria:**

- Authorized roles can manage facilities, courses, layouts, holes, tees, scorecards, ratings, rules, and services.
- Validation prevents incomplete required data from publication.
- Changes remain draft until publish.

### Story 8.2: Edit Course Geometry

As a GIS administrator, I want layer-based draw/edit tools so that official course maps can be maintained.

**Acceptance Criteria:**

- Editor supports point/line/polygon tools, layer visibility, vertices, snapping, undo, and redo.
- Unsaved-change guard prevents accidental loss.
- Keyboard and pointer workflows remain accessible; controls have visible labels/focus.

### Story 8.3: Validate and Publish Course Version

As a course administrator, I want safe publication so that invalid geometry never reaches golfers.

**Acceptance Criteria:**

- Pre-publish validation checks geometry, metadata, source, license, and data quality.
- User reviews diff summary and provides publish note.
- Publish creates immutable version, audit record, and package build job.

### Story 8.4: Roll Back Published Data

As a course administrator, I want rollback so that harmful releases can be corrected quickly.

**Acceptance Criteria:**

- Authorized user can select a prior version and view impact.
- Rollback creates a new version rather than deleting history.
- New package generation and audit record are triggered.

### Story 8.5: Manage Pins, Green Speed, and Conditions

As a greenkeeper, I want to schedule operational data so that golfers see timely official conditions.

**Acceptance Criteria:**

- User can place/schedule pins and update speed, firmness, moisture, maintenance, and course statuses.
- Effective and expiration times are required where applicable.
- Mobile synchronization reflects newly published operational data.

### Story 8.6: Send Course Alerts

As a course operator, I want targeted alerts so that golfers receive relevant safety and operational notices.

**Acceptance Criteria:**

- Alerts support facility, course, hole, flight, or group targeting.
- Safety alerts are visually distinct from promotion messages.
- Delivery, expiry, acknowledgment where required, and audit status are recorded.

# Epic 9: Correction and Data Quality Loop

Allow golfers to report issues and operators to turn validated feedback into versioned improvements.

### Story 9.1: Submit Correction Offline

As a golfer, I want to report incorrect course data so that maps and conditions improve without interrupting play.

**Acceptance Criteria:**

- User selects issue type; app captures course, hole, location, accuracy, timestamp, optional photo, and note.
- Submission saves offline and synchronizes through local event queue.
- User sees pending, submitted, accepted, or rejected state.

### Story 9.2: Review Correction Queue

As a course administrator, I want a prioritized correction queue so that I can resolve credible issues efficiently.

**Acceptance Criteria:**

- Queue supports course, hole, type, status, confidence, and date filters.
- Review displays reporter evidence, location, map context, and existing official data.
- Reviewer can approve, reject, request information, or convert to draft edit.

### Story 9.3: Resolve Correction into Published Version

As a course administrator, I want approved corrections linked to data versions so that provenance remains clear.

**Acceptance Criteria:**

- Approved correction can produce a draft change and remains linked through publication.
- Reporter is notified after resolution.
- Audit history preserves reviewer, decision, reason, and resulting version.

### Story 9.4: Monitor Data Quality

As a data quality manager, I want quality metrics so that pilot reliability can be measured.

**Acceptance Criteria:**

- Dashboard shows geometry completeness, verified courses, Class A/B coverage, correction volume, and resolution time.
- Metrics can be filtered by facility/course and exported.
- Stale pin, green speed, and course condition records are flagged.

# Epic 10: Smartwatch and Shot Tracking

Extend the proven mobile experience to watch-first interactions and confidence-aware shot capture.

### Story 10.1: Deliver Apple Watch Core Round Experience

As an Apple Watch golfer, I want glanceable distances and score entry so that I can play without handling my phone.

**Acceptance Criteria:**

- Watch shows hole/par/score, front-center-back, pin/hazard, navigation, and quick score.
- Offline course subset supports an 18-hole round.
- Crown/touch controls meet platform accessibility and battery requirements.

### Story 10.2: Deliver Wear OS Core Round Experience

As a Wear OS golfer, I want the same core round value so that Android users have watch-first play.

**Acceptance Criteria:**

- Compose app supports equivalent MVP watch information and scoring.
- Bezel/crown/button behavior adapts by device capability.
- Offline, always-on, haptic, and battery-saving states are supported.

### Story 10.3: Track Shots Manually

As a golfer, I want to record and correct shots so that performance data is useful before automation is trusted.

**Acceptance Criteria:**

- User can start/end, assign club, edit, delete, merge, and mark penalty/provisional/mulligan.
- Each shot stores start/end, club, lie, distance, conditions, result, source, and confidence.
- Shot edits work offline and synchronize idempotently.

### Story 10.4: Detect Shots with Confidence

As a golfer, I want automatic shot suggestions so that tracking requires minimal interruption.

**Acceptance Criteria:**

- Detection combines sensor, GPS, movement, time, and hole context.
- Confidence thresholds determine automatic, review-later, confirm, or discard behavior.
- Practice swings, cart movement, nearby golfers, short shots, penalties, and mulligans have test coverage.

# Epic 11: Performance Analytics and Smart Caddie

Transform sufficient trusted shot data into explainable performance insight and strategy recommendations.

### Story 11.1: Calculate Club Performance and Dispersion

As a golfer, I want actual club distributions so that I understand carry, variability, and misses.

**Acceptance Criteria:**

- System calculates average/median carry, total, variability, left/right, short/long, and confidence.
- Low sample sizes are labeled and do not unlock recommendations.
- Dispersion overlays can be compared against course hazards.

### Story 11.2: Deliver Driving Zone and Round Analytics

As a golfer, I want hole-specific history and round review so that I can identify improvement opportunities.

**Acceptance Criteria:**

- Driving Zone supports time, club, tee, and wind filters.
- Round review includes required scoring and shot metrics with incomplete-data warnings.
- Charts include legends, accessible colors, labels, and non-color indicators.

### Story 11.3: Calculate Strokes Gained

As a golfer, I want benchmarked Strokes Gained so that I can identify where shots are lost.

**Acceptance Criteria:**

- System calculates supported categories against valid benchmarks.
- Missing shot data produces explicit limitations, not fabricated estimates.
- User can compare similar handicap, target handicap, self-history, and valid professional benchmark.

### Story 11.4: Generate Explainable Smart Target

As a golfer, I want safe, balanced, and aggressive strategies so that I can choose risk intentionally.

**Acceptance Criteria:**

- Recommendations use geometry, club data, dispersion, hazards, conditions, handicap, history, and policy.
- Output includes club, aim, carry, remaining distance, hazards, risk, confidence, and explanation.
- Tournament restrictions are applied before recommendation generation.

# Epic 12: Tournament and Smart Golf Ecosystem

Expand the validated data and round platform into tournament operations and commercial services.

### Story 12.1: Operate Tournament and Live Leaderboard

As a tournament director, I want to configure players, flights, tees, scoring, rules, and leaderboard so that events run digitally.

**Acceptance Criteria:**

- Tournament supports required formats, registration/import, flights, tee times, starting tees, score confirmation, tie-break, and result publication.
- Live leaderboard handles expected concurrency and degraded connectivity.
- Tournament policy propagates to participant round clients.

### Story 12.2: Add Booking, Membership, and Loyalty Boundaries

As a course operator, I want integrations for customer operations so that the platform supports B2B2C growth.

**Acceptance Criteria:**

- Booking, membership, loyalty, and sponsorship use documented contracts and consent boundaries.
- Domain boundaries prevent payment/customer operations from coupling to core GPS rounds.
- White-label configuration does not fork core product behavior.

### Story 12.3: Add Payments and Transaction Services

As a customer, I want secure transactions so that I can pay for supported products and services.

**Acceptance Criteria:**

- Payment provider handles sensitive payment details; platform stores no prohibited card data.
- Transactions are idempotent, auditable, refundable where required, and reconciled.
- Failure and pending states are explicit to user and operator.

### Story 12.4: Enable International Expansion

As a product operator, I want localized configuration so that the platform can expand beyond Vietnam safely.

**Acceptance Criteria:**

- Locale, language, units, timezone, currency, rules, providers, licenses, and retention policies are configurable by market.
- Vietnam defaults remain unchanged unless market configuration overrides them.
- Data licensing and redistribution validation occurs before a course package is published in a market.

## Delivery Sequence

Recommended dependency waves:

1. **Foundation:** Epic 1.
2. **Trusted data and identity:** Epics 2–3.
3. **Offline distribution and round persistence:** Epics 4–5.
4. **Core product value:** Epic 6.
5. **Conditions, operations, and quality loop:** Epics 7–9.
6. **MVP 1 pilot gate:** field accuracy, offline 18-hole, battery, security, and operator publish/rollback validation.
7. **Later phases:** Epics 10–12 only after MVP evidence and data readiness.

## Final Validation

- Every FR is mapped to at least one epic.
- MVP stories can be implemented without depending on later-phase epics.
- Architecture choices are reflected in foundation, data, package, sync, security, and observability stories.
- UX requirements are represented in design-system, active-round, portal, accessibility, and feedback acceptance criteria.
- AI is deferred until accurate course geometry and sufficient shot history exist.
- The first end-to-end milestone is a verified course version published by the portal, packaged, downloaded, rendered offline, and used to complete and synchronize a round.
