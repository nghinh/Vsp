# Slice Plan: Story 8.6 — Send Course Alerts

## Story Metadata
- **Story**: 8.6
- **Epic**: epic-08 (Course Editing)
- **Status**: `in-progress`
- **Phase**: MVP 1
- **Story File**: `docs/implementation-artifacts/epic-08/8-6-send-course-alerts.md`

---

## Planning Evidence

### Context Reading Completed
| Document | Source | Key Findings |
|----------|--------|--------------|
| `prd.md` | `docs/planning-artifacts/prd.md` | §8.11 Course Operations Portal: alerts capability; §9.1 data entities (no CourseAlert entity yet) |
| `architecture.md` | `docs/planning-artifacts/architecture.md` | Notification Module scaffolded; modular monolith boundaries; PostgreSQL/PostGIS; Audit Module present |
| `ux-spec.md` | `docs/planning-artifacts/ux-spec.md` | §7 Portal Alerts nav item; visual distinction for safety vs promotion |
| `8-6-send-course-alerts.md` | Story spec | 3 ACs; 6 tasks; dependencies on 8.5 and foundational epics |
| `sprint-status.yaml` | `docs/implementation-artifacts/sprint-status.yaml` | 8-6-send-course-alerts: `backlog` → needs update to `in-progress` |

### Existing Foundation
- **NotificationService**: Stub interface + impl at `apps/api/src/main/java/vnpt/vsp/module/notification/`
- **AuditModule**: AuditAction enum (PIN_UPDATE, GREEN_UPDATE, etc.), AuditEntry JPA entity present
- **OpenAPI**: WeatherAlert schema exists at `packages/contracts/schemas/weather.yaml:123`; no CourseAlert schema
- **Portal UI**: `packages/portal-ui/` exists with VSP component patterns

### Anti-Shortcut Evidence
- 8.5 (manage pins/green speed/conditions) is listed as dependency — but 8.5 is also `backlog` in sprint-status
- Story spec AC requires: targeting scope, visual distinction, delivery/expiry/acknowledge/audit
- Must NOT implement: deferred AI, smartwatch, analytics, tournament-platform scope

---

## Slice Plan

### Slice 1: Domain Model & Persistence
**Task**: Define CourseAlert entity, targeting enum, alert type enum, repository

**Scope**:
- [ ] `entity/CourseAlert.java` — JPA entity with:
  - `id`, `facilityId`, `courseId`, `holeId`, `flightId`, `groupId` (targeting fields, nullable)
  - `alertType` enum: SAFETY, PROMOTION
  - `title`, `body`, `priority`
  - `effectiveAt`, `expiresAt`
  - `deliveryStatus` enum: PENDING, DELIVERED, FAILED, EXPIRED
  - `acknowledgmentRequired` boolean
  - `acknowledgedAt`, `acknowledgedBy`
  - `createdAt`, `createdBy`, `publishedVersion`
  - `source`, `license`, `accuracyClass`, `confidence`, `verificationStatus`, `version` (data quality fields from architecture §9.3)
- [ ] `entity/AlertTargetType.java` — enum: FACILITY, COURSE, HOLE, FLIGHT, GROUP
- [ ] `entity/CourseAlertRepository.java` — JPA repository with:
  - `findByFacilityIdAndAlertTypeAndEffectiveAtBefore`, `findActiveAlerts`, `findByCourseId`, `findAcknowledgmentPending`
- [ ] `db/migration/VXX__course_alerts.sql` — schema for course_alerts table with indexes

**AC Mapped**:
- AC1: Targeting via facility/course/hole/flight/group fields
- AC3: Delivery, expiry, acknowledgment tracking; audit via data quality fields

---

### Slice 2: OpenAPI Contracts
**Task**: Add CourseAlert schemas and endpoints to OpenAPI contract

**Scope**:
- [ ] `schemas/course.yaml` — Add CourseAlert, CourseAlertCreate, CourseAlertUpdate, CourseAlertListResponse schemas
  - Safety alert visual distinction field: `alertType` discriminator
  - Targeting: `targetType` + `targetId` pattern
  - Delivery tracking: `deliveryStatus`, `deliveredAt`, `acknowledgmentRequired`, `acknowledgedAt`
  - Audit fields: `createdAt`, `createdBy`, `version`
- [ ] `openapi.yaml` — Add `/admin/alerts/*` paths:
  - `POST /admin/alerts` — create/send alert
  - `GET /admin/alerts` — list alerts with filtering
  - `GET /admin/alerts/{id}` — get alert detail
  - `PATCH /admin/alerts/{id}` — update alert (only before effective)
  - `DELETE /admin/alerts/{id}` — cancel alert
  - `POST /admin/alerts/{id}/acknowledge` — acknowledge alert (for mobile)

**AC Mapped**:
- AC1: Targeting filtering in GET /admin/alerts (by targetType, targetId)
- AC3: Audit status via version field

---

### Slice 3: Service Layer
**Task**: Implement CourseAlertService with send, track, acknowledge, audit

**Scope**:
- [ ] `CourseAlertService.java` — interface:
  - `sendAlert(CourseAlertCreateRequest)` → returns CourseAlert
  - `getAlert(id)`, `listAlerts(filter)`, `updateAlert(id, request)`, `cancelAlert(id)`
  - `acknowledgeAlert(id, acknowledgedBy)`
  - `getActiveAlertsForTarget(targetType, targetId)`
- [ ] `CourseAlertServiceImpl.java` — implementation:
  - Validates targeting scope (at least one target required)
  - Sets effectiveAt (default: now) and expiresAt
  - Calls NotificationService for push dispatch (stub if needed)
  - Records delivery status transitions
  - Audit via @Audited annotation or explicit AuditService call
- [ ] Add `ALERT_SEND`, `ALERT_UPDATE`, `ALERT_CANCEL`, `ALERT_ACK` to `AuditAction.java`

**AC Mapped**:
- AC1: Targeting validation and filtering
- AC3: Delivery tracking, acknowledgment, audit via AuditService

---

### Slice 4: Portal Controller
**Task**: REST controller for admin alert management

**Scope**:
- [ ] `CourseAlertController.java` — REST endpoints under `/admin/alerts`
  - RBAC: COURSE_ADMIN role required
  - OpenAPI integration via @Operation annotations
  - Pagination support via existing PageTokenService pattern
  - Structured error responses via GlobalExceptionHandler

**AC Mapped**:
- AC3: Portal access for course operators to send alerts

---

### Slice 5: Mobile Push Integration (Contract Only)
**Task**: Define push notification contract for alert delivery to mobile

**Scope**:
- [ ] `schemas/notification.yaml` — Add PushNotification payload schema:
  - `alertId`, `alertType`, `title`, `body`, `targetType`, `targetId`, `priority`
  - `effectiveAt`, `expiresAt`
- [ ] `NotificationService` stub enhancement:
  - `sendPushNotification(pushPayload)` method signature
  - Documentation that actual push (FCM/APNs) integration is deferred

**AC Mapped**:
- AC1: Mobile receives targeted alerts
- AC2: alertType discriminator for visual distinction on mobile

---

### Slice 6: Testing
**Task**: Unit and integration tests

**Scope**:
- [ ] `CourseAlertServiceTest.java` — unit tests:
  - Send alert with valid targeting
  - Reject alert with no targeting
  - Delivery status transitions
  - Acknowledgment flow
  - Expiry handling
- [ ] `CourseAlertControllerTest.java` — integration tests:
  - CRUD endpoints with auth
  - RBAC enforcement (COURSE_ADMIN vs GOLFER)
  - Input validation
  - Error handling

---

## Wave Dependencies

```
Slice 1 (Domain/Persistence)
    ↓
Slice 2 (OpenAPI Contracts)
    ↓
Slice 3 (Service Layer) ← Slice 2
    ↓
Slice 4 (Controller) ← Slice 3
    ↓
Slice 5 (Mobile Push) ← Slice 2
    ↓
Slice 6 (Tests) ← All
```

---

## Verification Checklist

| AC | Verification Method |
|----|---------------------|
| AC1: Targeting (facility/course/hole/flight/group) | Unit test: `sendAlert_withHoleTarget_succeeds`, `sendAlert_withNoTarget_fails` |
| AC2: Safety vs promotion visual distinction | `alertType` enum + OpenAPI discriminator + schema documentation |
| AC3: Delivery/expiry/acknowledge/audit | Unit tests for status transitions + AuditEntry assertion |

---

## File List (Expected)

| File | Action |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/entity/CourseAlert.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/entity/AlertTargetType.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/entity/CourseAlertRepository.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/CourseAlertService.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/CourseAlertServiceImpl.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/CourseAlertController.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/coursealert/CourseAlertModule.java` | New |
| `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` | Modify |
| `apps/api/src/main/resources/db/migration/VXX__course_alerts.sql` | New |
| `packages/contracts/schemas/course.yaml` | Modify |
| `packages/contracts/schemas/notification.yaml` | New |
| `packages/contracts/openapi.yaml` | Modify |
| `packages/contracts/lib/src/dto/course_alert_dto.dart` | New |

---

## Out of Scope (Per Story Spec §37)
- Deferred AI, smartwatch, analytics, tournament-platform, ecosystem scope
- Actual FCM/APNs push implementation (contract only per Slice 5)
- Mobile UI for alerts (story focuses on send/manage from portal)

---

## Risk & Notes
- **Risk**: Story 8.5 dependency not yet implemented — CourseAlert targeting may reference entities (Course, Hole, Flight, Group) that need 8.1-8.3 foundation. **Mitigation**: Design CourseAlert with optional String targetId fields rather than entity references to avoid coupling.
- **Note**: AlertModule placement under `module/coursealert/` (not `notification/`) — alerts are course-operation domain objects; NotificationModule is for generic push infrastructure.
