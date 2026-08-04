---
stepsCompleted:
  - step-01-init
  - autonomous-prd-generation
inputDocuments:
  - docs/Requirements.md
  - docs/project-context.md
workflowType: prd
documentStatus: draft
---

# Product Requirements Document - Vietnam Smart Golf Platform

**Author:** nghinh  
**Date:** 2026-08-01  
**Product Manager:** John  
**Output Language:** English  
**Source:** `docs/Requirements.md`

---

## 1. Executive Summary

Vietnam Smart Golf Platform is a mobile-first, offline-first golf GPS and course operations ecosystem for Vietnam, expanding later to Southeast Asia and international markets. The product combines accurate golf course maps, GPS distances, scorecards, pin/green/course condition data, course operations tooling, tournament workflows, and phased Smart Caddie intelligence.

The MVP must not attempt to become a full AI golf platform immediately. The first validated product increment is **Reliable Golf GPS + Course Operations Data Loop**: golfers get accurate, fast, offline distances and scorekeeping; course operators get the portal needed to keep official course data current.

## 2. Product Positioning

**Positioning statement:**

> A deeply localized Smart Golf platform combining golfer experience, official golf-course operations data, and future AI Smart Caddie capabilities.

**Differentiation:**

- Vietnam-first verified course data.
- Official pin position, green speed, and course condition updates.
- Offline-first golf GPS for weak network conditions.
- Course Operations Portal as data quality engine, not just admin tooling.
- Confidence-aware GPS, course data, and recommendation UX.
- Phased expansion into smartwatch, performance analytics, tournaments, and AI.

## 3. Goals and Non-Goals

### 3.1 Product Goals

1. Deliver reliable front/center/back green and hazard distance on pilot courses.
2. Enable golfers to complete an 18-hole round offline without losing score or shot data.
3. Provide course operators with tools to maintain official geometry, pin, green speed, and course condition data.
4. Establish a scalable geospatial data model for future Smart Caddie and analytics.
5. Validate demand from both golfers and golf courses before advanced AI investment.

### 3.2 MVP 1 Non-Goals

- Full automatic shot tracking.
- Complete Smart Caddie recommendations.
- Full Strokes Gained.
- Advanced green contour.
- Voice assistant.
- Full Apple Watch and Wear OS experience.
- Booking, payment, loyalty, food and beverage, and white-label ecosystem.

## 4. Target Users

### 4.1 Primary MVP Users

#### Golfer

Needs fast, accurate on-course distance, map, score, wind/weather, and offline reliability.

#### Golf Course Operator

Needs official digital course data management, pin/green/course condition updates, alerts, correction workflow, and auditability.

### 4.2 Secondary Users

- Caddie: confirms pins, reports conditions, supports scoring and pace-of-play.
- Tournament organizer: configures tournament rules, flights, scoring, leaderboards.
- Advanced golfer: later needs club dispersion, shot history, Strokes Gained, Smart Target.

## 5. Product Principles

1. **Glanceable:** Critical data readable in under 2 seconds.
2. **Offline-first:** Core on-course features work without internet.
3. **One-hand and max-two-tap UX:** On-course flows must not slow pace of play.
4. **Confidence-aware:** GPS, course data, pins, shot detection, and recommendations expose confidence.
5. **Correctable later:** Users can fix mistakes post-round.
6. **No fabricated precision:** Never present unofficial or estimated data as official.
7. **Vector-first maps:** Optimize cost, offline size, and custom golf rendering.

## 6. Recommended Technology Decisions

### 6.1 Mobile

- **Selected:** Flutter.
- **Rationale:** Cross-platform iOS/Android delivery, strong UI velocity, native module bridge support, suitable for offline-first MVP.
- **Context7:** `/flutter/website`.

### 6.2 Maps

- **Selected:** MapLibre Flutter.
- **Map strategy:** OpenStreetMap base where suitable, custom golf vector tiles, PMTiles or offline regions for course packages, optional licensed satellite imagery.
- **Context7:** `/maplibre/flutter-maplibre-gl`.
- **Best practices applied:**
  - Use vector sources/layers for golf geometry.
  - Use offline region download lifecycle for course packages.
  - Use annotations/layers for target, pin, hazards, shot paths.
  - Prefer PMTiles/offline region packaging for predictable offline behavior.

### 6.3 Data Layer

- **Selected:** PostgreSQL + PostGIS.
- **Context7:** `/websites/postgis_net`.
- **Best practices applied:**
  - Store geometries in WGS84 / GeoJSON compatible forms.
  - Use PostGIS geometry for spatial objects.
  - Use geography or projected calculations where meter-accurate distance is needed.
  - Use `ST_DWithin` for index-aware nearby/distance filtering.
  - Add GIST indexes on spatial columns.

### 6.4 Supporting Infrastructure

- Redis for caching and session/rate-limit use cases.
- Object Storage + CDN for course packages, tiles, media, and downloadable assets.
- Event streaming/message queue for sync, telemetry, shot events, data corrections, notifications.
- Data warehouse and feature store deferred until analytics/AI phases.

## 7. MVP 1 Scope

### 7.1 MVP Name

**Reliable Golf GPS + Course Operations Data Loop**

### 7.2 Included Capabilities

#### Mobile App

- Account registration and login.
- Golfer profile.
- Course search and nearby course detection.
- Course download and offline course package management.
- Round setup.
- GPS current position.
- Automatic course/hole detection with manual override.
- Strategic 2D hole map.
- Satellite map where licensed.
- Front/center/back green distance.
- Hazard near/far and carry distances.
- Tap-to-target distance.
- Wind/weather display with source and timestamp.
- Scorecard for up to four golfers on one device.
- Basic Casual / Practice / Tournament Mode switch.
- Data correction report submission.

#### Course Operations Portal

- Facility/course/hole metadata management.
- Golf map editor for tee, fairway, rough, green, bunker, water, OB, cart path, landmark layers.
- Pin position management.
- Green speed and condition management.
- Course alerts.
- Data correction review workflow.
- Version history, publish, rollback, and audit log.

#### Backend/Data Platform

- Identity and user profile APIs.
- Course, hole geometry, and course package APIs.
- Round and score APIs.
- Weather snapshot APIs.
- Correction workflow APIs.
- Versioning and audit support.
- Offline sync support with local-first queue.

### 7.3 Explicitly Deferred

- Full smartwatch apps.
- Manual/automatic shot tracking beyond basic data structures.
- Club recommendation.
- Driving Zone.
- Dispersion analytics.
- Strokes Gained.
- Smart Caddie AI.
- Tournament platform beyond basic mode restrictions.
- Booking/payment/membership/loyalty.

## 8. Functional Requirements

### 8.1 Account and Profile

- Users can register with phone, email, Google Sign-In, or Apple Sign-In.
- Users can verify OTP, recover password, manage sessions, delete account, and export personal data.
- Golfer profile supports name, image, gender, birth year, country, handicap, home club, distance unit, dominant hand, target handicap, skill level, driver distance, and optional swing speed.

### 8.2 Course Search

- Users can search by course name, province/city, nearby location, country, favorites, and recently played.
- Course details include address, coordinates, phone, website, images, holes, tee sets, services, local rules, current condition, rating/slope, and last data update.

### 8.3 Offline Course Package

- Users can download course metadata, hole geometry, vector maps, scorecards, tee data, local rules, pin positions, course conditions, latest weather snapshot, and optional satellite/3D assets.
- App shows package size, last update, and download progress.
- App supports incremental updates, Wi-Fi-only downloads, deletion, and local persistence.
- A full 18-hole round must remain playable offline.

### 8.4 Round Setup

- User selects course, layout, holes, tee, game format, players, handicap, mode, and active bag.
- App may suggest nearest course, layout, tee, starting hole, and frequent partners.

### 8.5 Course and Hole Detection

- App detects current facility, course, and likely hole.
- App distinguishes adjacent or crossing holes.
- App avoids auto-switching when GPS accuracy is low.
- App uses location, travel direction, and geometry confidence.
- App allows manual hole override.
- App logs incorrect detection events for quality improvement.

### 8.6 Hole Map

- Strategic map displays tee, fairway, rough, green, bunker, water, penalty area, OB, cart path, landmarks, pin, golfer position, target, wind direction, and distance rings.
- Satellite map displays licensed aerial imagery when available.
- 3D map is deferred from MVP except optional preview assets.

### 8.7 Distance Measurement

- App displays distance to front/center/back green, pin, bunker near/far, water near/far/carry, OB, dogleg, lay-up, selected target.
- Each measurement includes actual distance, optional elevation/plays-like flag, GPS accuracy, timestamp, data source, and confidence.
- Supported units: meters and yards.

### 8.8 Target Interaction

- User can tap to place target.
- User can view ball-to-target and target-to-pin distance.
- Drag target can be included if interaction quality is acceptable in MVP.
- Watch crown target control deferred to smartwatch phase.

### 8.9 Weather and Wind

- App shows wind direction/speed/gust, temperature, humidity, rain probability, pressure, UV, lightning risk, sunrise/sunset where provider supports.
- Wind is displayed relative to shot line.
- UI shows source, last update, forecast/direct measurement status, and stale warning.

### 8.10 Scorecard

- MVP supports score entry for up to four golfers on one device.
- Fields: gross score, putts, penalties, fairway hit, GIR, bunker, notes where practical.
- Score data is persisted locally before sync.
- Score colors are consistent across scorecard, leaderboard, and summary.

### 8.11 Course Operations Portal

- Admin can create and edit facility/course metadata.
- Admin can edit geometry layers with polygon, line, point tools.
- Admin can import GeoJSON/KML/KMZ/Shapefile/CSV where feasible.
- Admin can update pin positions, green speed, conditions, and alerts.
- Admin can review golfer correction reports.
- Every published change creates version history and audit log.
- Admin can roll back published course data.

### 8.12 Tournament Mode

- MVP includes basic mode flag and configurable feature restrictions.
- Restricted features must be hidden or disabled.
- Enabled feature set is auditable.
- Tournament Mode may lock after round start.

## 9. Data Requirements

### 9.1 Core Entities

- User
- Golfer Profile
- Golf Facility
- Course
- Hole
- Tee Set
- Tee Box
- Fairway
- Rough
- Green
- Pin Position
- Bunker
- Water Hazard
- Penalty Area
- Out-of-Bounds
- Cart Path
- Landmark
- Course Condition
- Green Condition
- Weather Snapshot
- Club
- Golf Bag
- Round
- Flight
- Score
- Shot
- Tournament
- Leaderboard
- Course Correction
- Data Version
- Data License

### 9.2 Geospatial Standards

- WGS84 coordinate system.
- GeoJSON interchange format.
- PostGIS geometry/geography storage and calculation.
- Spatial indexes for course, hole, hazard, and feature lookup.

### 9.3 Data Quality Fields

Every data object includes source, license, created date, updated date, last verified date, accuracy class, confidence, verification status, effective date, expiration date, version, and publisher.

### 9.4 Accuracy Classes

- Class A: RTK surveyed or course verified.
- Class B: Licensed professional provider.
- Class C: Verified satellite digitization.
- Class D: Unverified community data.

Priority: A → B → C → D.

## 10. Non-Functional Requirements

### 10.1 Accuracy

- Show GPS accuracy.
- Warn when GPS error exceeds 10 meters.
- Do not claim precision beyond device capability.
- Avoid stale positions.
- Support location smoothing without excessive lag.
- Pilot target: at least 95% critical points correctly mapped at pilot courses.

### 10.2 Performance

- Cached hole screen loads in under 2 seconds.
- Distance updates within 1 second after location update.
- Smooth pan/zoom on mid-range devices.
- Near-instant score entry.
- Background sync does not block UI.
- Course packages optimized for size.

### 10.3 Offline

Offline-supported functions:

- Hole map.
- GPS distance.
- Hazard distance.
- Target.
- Scorecard.
- Club selection.
- Temporary round history.
- Cached pin, weather, and course condition.

### 10.4 Battery

- Mobile device should complete 18 holes without charging.
- Battery Saving Mode reduces GPS frequency when stationary.
- No excessive weather polling.
- Efficient geofencing.
- Reduced animation under low battery.
- Battery telemetry is captured.

### 10.5 Availability and Sync

- Backend target: 99.9% production availability.
- Local persistence before sync.
- Retry and idempotency support.
- No score loss during backend outage.
- CDN-backed course package delivery.

### 10.6 Security and Privacy

- TLS everywhere.
- Encryption at rest.
- Token expiration and refresh-token rotation.
- Role-based access control.
- MFA for admins.
- Audit logs.
- API rate limiting.
- Secrets management.
- Vulnerability scanning.
- Account deletion, round deletion, and data export.
- No default sharing of detailed location history with courses.
- Clear retention policy.
- OWASP Mobile and Web controls.

### 10.7 Accessibility

- Large text.
- High contrast.
- Color-blind-friendly indicators.
- Haptic feedback.
- Non-color-only score indicators.

### 10.8 Observability

Track crashes, app performance, GPS quality, hole detection accuracy, course package errors, weather API errors, battery consumption, sync failures, correction volume, and map rendering latency.

## 11. Success Metrics

### 11.1 MVP Acceptance Criteria

MVP 1 is accepted when:

1. At least 5 pilot courses are available.
2. Every pilot hole includes real-world tee, green, bunker, and water features.
3. Front/center/back distances work reliably.
4. Hazard distances follow correct near/far/carry logic.
5. Touch target works.
6. Course packages can be downloaded offline.
7. A full 18-hole round can be completed offline.
8. Scorecard data is never lost.
9. Automatic hole detection reaches agreed pilot target.
10. GPS accuracy is visible.
11. Portal users can edit geometry.
12. Portal users can update pin position.
13. Portal users can update green speed.
14. Portal users can update course condition.
15. Golfers can report incorrect data.
16. Weather and wind show timestamp and source.
17. Mobile devices complete 18 holes within battery target.
18. All data licenses are valid.
19. Course-data changes have audit logs.
20. Course versions can be rolled back.
21. Basic Tournament Mode is available.
22. Crash-free session rate reaches agreed threshold.

### 11.2 Product KPIs

- Monthly active golfers.
- Weekly active golfers.
- Rounds per golfer.
- Course downloads.
- 30-day and 90-day retention.
- Round-completion rate.
- Time from app open to first distance.
- Interactions per hole.
- Offline success rate.
- Map load time.
- GPS update latency.
- Percentage of verified holes.
- Data errors per 1,000 rounds.
- Correction processing time.
- Active courses.
- B2B course contracts.

## 12. Phased Roadmap

### Phase 1: Reliable Golf GPS

- Pilot courses.
- Mobile app for iOS/Android.
- Strategic and satellite map.
- Distance, hazard, target, weather, scorecard.
- Offline course package.
- Course Operations Portal.
- Data correction and versioning.

### Phase 2: Watch and Performance

- Apple Watch and Wear OS.
- Mini 2D map.
- Watch target control.
- Quick score.
- Manual shot tracking.
- Automatic shot detection.
- Club distance, Driving Zone, dispersion.
- End-of-hole review and round review.

### Phase 3: Smart Caddie

- Smart Target.
- Club recommendation.
- Safe/balanced/aggressive strategy.
- Advanced plays-like distance.
- Personalized game plan.
- Strokes Gained.
- AI round review.
- 3D preview and replay.
- Shareable Round Story.

### Phase 4: Smart Golf Ecosystem

- Tournament platform.
- Booking.
- Payment.
- Membership.
- Loyalty.
- Caddie Companion.
- Food and beverage order.
- Course analytics.
- Marketing automation.
- White-label application.
- International expansion.

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Inaccurate course data | Product trust failure | Small pilot, RTK survey, course verification, confidence classes, correction workflow |
| Provider lock-in | Cost and licensing constraints | Multi-source strategy, first-party data, standardized geospatial model |
| Map/imagery cost | Margin pressure | Vector-first design, MapLibre, controlled zoom/download policy |
| GPS instability | Wrong distances and hole detection | Accuracy indicator, smoothing, manual override, low-confidence lockout |
| Battery drain | On-course abandonment | Adaptive GPS, offline data, telemetry, reduced animation |
| Shot detection errors | User trust loss | Defer full automation, use confidence and correction flows |
| Tournament rule violations | Compliance risk | Tournament Mode, feature restrictions, audit logs |
| Stale pin/green data | Bad decisions | Expiration time, official/unofficial labels, course portal updates |

## 14. Open Decisions Before Build

The PRD assumes best-practice choices where possible, but these decisions still require business confirmation before implementation commitment:

1. Pilot-course list.
2. Course-data provider and redistribution rights.
3. Satellite imagery provider and licensing.
4. RTK/drone survey plan.
5. Accuracy tolerance for pilot acceptance.
6. Golf-course partnership model.
7. Pricing model.
8. Tournament compliance policy.
9. Data retention policy.
10. Operating model for pin and green-speed updates.

## 15. Delivery Workstreams

1. Product Management.
2. Golf Domain.
3. Course Data.
4. Mobile Application.
5. Backend Platform.
6. GIS and Maps.
7. Course Operations Portal.
8. QA.
9. Security and Privacy.
10. Business Development.
11. Course Partnerships.
12. Customer Support.

## 16. Implementation Readiness Notes

- Build Phase 1 around data accuracy, offline map reliability, GPS quality, and course-data update loop.
- Do not invest heavily in AI before enough accurate course data, shot history, and operations data exist.
- Keep the architecture open for Smart Caddie, but validate MVP usage first.
- Treat Course Operations Portal as a core product, not a back-office afterthought.
- Use MapLibre + custom vector tiles to control offline capability and cost.
- Use PostGIS as the geospatial source of truth.
