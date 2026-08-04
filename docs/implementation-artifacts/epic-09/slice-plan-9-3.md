# Slice Plan: Story 9.3 — Resolve Correction into Published Version

## Story Overview

**Epic:** 9 (Data Quality)
**Story:** 9.3
**Status:** `ready-for-dev` → `in-progress`
**Phase:** MVP 1
**Run Folder:** `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

## Dependencies

- **Hard dependency:** Story 9.2 (Review Correction Queue) — creates the `Correction` entity and review workflow
- **Soft dependency:** Story 8.3 (Validate and Publish Course Version) — provides the `PublishService` and `DataVersion` infrastructure that corrections link into
- **Foundation dependency:** Story 9.1 (Submit Correction Offline) — Correction entity must exist

**Note:** Stories 9.1 and 9.2 are both `ready-for-dev`. Story 9.3 MUST wait for the Correction entity to be created in 9.2. Implementation will use the entity definition implied by 9.2's review workflow.

## Acceptance Criteria Analysis

| AC | Description | Implementation Owner |
|----|-------------|---------------------|
| AC-1 | Approved correction can produce a draft change and remains linked through publication | `CorrectionService.resolveCorrection()` + `DataVersion` link |
| AC-2 | Reporter is notified after resolution | `NotificationService` push dispatch |
| AC-3 | Audit history preserves reviewer, decision, reason, and resulting version | `AuditAction.CORRECTION_RESOLVED` + `AuditService.log()` |

## Slice Plan

### Wave 1: BACKEND-CONTRACT + DOMAIN (Backend)

**Goal:** Define Correction resolution domain model and service contract.

**Files to create/modify:**

```
apps/api/src/main/java/vnpt/vsp/module/correction/
  ├─ entity/
  │   └─ Correction.java                    # NEW — Correction entity with resolution fields
  │   └─ CorrectionStatus.java              # NEW — PENDING | APPROVED | REJECTED
  │   └─ CorrectionType.java                # NEW — GEOMETRY | PIN_POSITION | CONDITION | etc.
  └─ dto/
      ├─ CorrectionResolutionRequest.java    # NEW — {decision: APPROVE|REJECT, reason, produceDraftChange: bool}
      └─ CorrectionResolutionResponse.java  # NEW — {correctionId, status, resultingVersionId, notifiedAt}
```

**Key design decisions:**
- `Correction` entity is course-scoped: `courseId` + `holeId` (nullable for course-level corrections)
- `CorrectionType` enum: `GEOMETRY`, `PIN_POSITION`, `GREEN_SPEED`, `COURSE_CONDITION`, `HAZARD`, `OTHER`
- `CorrectionStatus` enum: `PENDING` → `APPROVED` | `REJECTED`
- `resultingVersionId` (FK to `DataVersion`) is set when an approved correction is published — stored as nullable, populated by publish flow
- `resolutionNote` (String) stores reviewer decision reason
- `reviewedAt`, `reviewedBy` track resolution metadata

### Wave 2: BACKEND-SERVICE + AUDIT (Backend)

**Goal:** Implement `CorrectionService.resolveCorrection()` with audit logging and notification dispatch.

**Files to create/modify:**

```
apps/api/src/main/java/vnpt/vsp/module/correction/
  ├─ CorrectionService.java                  # ADD: resolveCorrection() interface method
  └─ CorrectionServiceImpl.java             # IMPLEMENT: resolveCorrection(), _notifyReporter()

apps/api/src/main/java/vnpt/vsp/module/audit/
  └─ AuditAction.java                       # ADD: CORRECTION_RESOLVED
```

**Key behavior:**
1. Validate correction exists and is PENDING
2. Transition status: PENDING → APPROVED or PENDING → REJECTED
3. If APPROVED + `produceDraftChange = true`: create draft entity changes (geometry edits, pin updates, etc.) linked to correction
4. Fire async push notification to reporter via `NotificationService`
5. Write `CORRECTION_RESOLVED` audit entry with: reviewer, decision, reason, resultingVersionId (if published), correctionId

**RBAC:** `COURSE_ADMIN` or `SUPER_ADMIN` required. Reviewer becomes `reviewedBy`.

### Wave 3: BACKEND-API (Backend)

**Goal:** Expose `POST /admin/corrections/{id}/resolve` REST endpoint.

**Files to create/modify:**

```
apps/api/src/main/java/vnpt/vsp/api/correction/
  └─ CorrectionResolutionController.java     # NEW — POST /admin/corrections/{id}/resolve
```

**Request body (`CorrectionResolutionRequest`):**
```json
{
  "decision": "APPROVE",          // REQUIRED — APPROVE | REJECT
  "reason": "Corrected pin position per RTK survey",
  "produceDraftChange": true      // REQUIRED for APPROVE — whether to create draft edits
}
```

**Response (`CorrectionResolutionResponse`):**
```json
{
  "correctionId": 42,
  "status": "APPROVED",
  "resultingVersionId": null,    // Populated when correction's draft is published
  "auditId": 1001,
  "notifiedAt": "2026-08-02T15:00:00Z"
}
```

**Error codes:** Uses existing `CORRECTION_001`, `CORRECTION_002`, `CORRECTION_003`, `CORRECTION_004` from `VspErrorCode`.

### Wave 4: BACKEND-PUBLISH-INTEGRATION (Backend)

**Goal:** When a draft version is published that originated from an approved correction, back-link `resultingVersionId` to the correction and preserve provenance.

**Files to create/modify:**

```
apps/api/src/main/java/vnpt/vsp/module/course/
  ├─ PublishService.java                     # ADD: overload publishVersion(correctionId, ...)
  └─ PublishServiceImpl.java                 # IMPLEMENT: link correction → published version
```

**Key behavior:**
- `publishVersion(versionId, publishNote, publishedBy)` gets an optional `correctionId` parameter
- After DRAFT → PUBLISHED transition, update `Correction.resultingVersionId = publishedVersion.id`
- This preserves the "correction → draft → published" lineage chain (AC-1: "remains linked through publication")

**Note:** This requires that the draft version created from an approved correction carries the `correctionId` reference. The draft creation in Wave 2 stores this.

### Wave 5: BACKEND-TESTS (Backend)

**Goal:** Comprehensive unit tests for `CorrectionServiceImpl.resolveCorrection()`.

**Files to create/modify:**

```
apps/api/src/test/java/vnpt/vsp/module/correction/
  └─ CorrectionServiceImplTest.java         # NEW — ~10 test cases
```

**Test scenarios:**
1. Happy path: PENDING → APPROVED, status updated, audit logged, notification dispatched
2. PENDING → REJECTED with reason
3. Correction not found → CORRECTION_001
4. Correction already reviewed (status != PENDING) → CORRECTION_002
5. Invalid status transition → CORRECTION_003
6. Reporter notification failure (notification service stub throws) — non-fatal, log and continue
7. APPROVED with `produceDraftChange = false` — no draft created
8. APPROVED with `produceDraftChange = true` — draft entity created and linked
9. Publish integration: published version back-links to correction via `resultingVersionId`
10. Audit entry contains all required fields: reviewer, decision, reason, resultingVersionId

**Framework:** JUnit 5 + Mockito (consistent with existing test patterns in repo)

## Implementation Order

```
Wave 1 (CONTRACT+DOMAIN)    → Entity, DTOs, enums
Wave 2 (SERVICE+AUDIT)      → Service logic, audit action
Wave 3 (API)                → REST controller
Wave 4 (PUBLISH-INTEGRATION) → Version linking on publish
Wave 5 (TESTS)              → Unit tests
```

## Verification Plan

| Gate | Command | Pass Criteria |
|------|---------|---------------|
| Format | `mvn compile` (main sources) | 0 errors |
| Tests | `mvn test -Dtest=CorrectionServiceImplTest` | All tests PASS |
| Integration | `mvn package -DskipTests` | 0 errors (JAR built) |
| Review | Manual: POST /admin/corrections/1/resolve → verify audit entry + notification dispatch | Audit entry contains reviewer, decision, reason, versionId |

## Portal UI Note

Portal resolution UI (approve/reject buttons + resolve modal) belongs to Story 9.2 (Review Correction Queue), not 9.3. Story 9.3 provides the backend resolve endpoint that 9.2's UI calls.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Correction entity not yet created (9.2 not done) | High — cannot implement service | Define entity contract in Wave 1; implement against assumed entity shape; adjust if 9.2's entity differs |
| Publish integration requires correctionId on draft version | Medium — needs DataVersion link field | Add `correctionId` nullable FK to `DataVersion` entity in Wave 1 |
| Notification service is stub (no FCM/APNs yet) | Low — non-fatal, logs payload | Notification failure is non-fatal to resolution flow |
