# Slice 2-5-B Implementation: Backend Privacy + Admin Portal

**Run ID:** run_2026_08_02_005
**Story:** 2.5 — Administer Roles and Privacy Requests
**Slice:** 2-5-B — Backend Privacy + Admin Portal
**Status:** IMPLEMENTED

---

## 1. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-02/2-5-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-4-A-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-5-administer-roles-and-privacy-requests.md"
  ],
  "mockup_sources_read": []
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story.

---

## 2. AC Coverage

| AC | Verification |
|----|-------------|
| AC-3: Users can request data export, account deletion, round deletion with auditable processing | `PrivacyServiceImpl`: `createRequest()` creates PENDING request; `processRequest()` transitions state with audit; `deleteAccount()` anonymizes PII; `deleteRound()` soft-deletes round+scores; `getDataExport()` generates JSON export; `PrivacyServiceImplTest` covers all 17 test cases |

---

## 3. Files Changed / Created

### New Files (19)

**Migrations (3)**
- `apps/api/src/main/resources/db/migration/V12__privacy_requests.sql` — `privacy_requests` table + anonymization columns on `golfer_accounts`
- `apps/api/src/main/resources/db/migration/V13__rounds_and_scores.sql` — `rounds` + `scores` tables with soft-delete support
- `apps/api/src/main/resources/db/migration/V14__privacy_requests_fk.sql` — FK from `privacy_requests.target_round_id` to `rounds(id)`

**Entities (3)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/entity/PrivacyRequest.java` — JPA entity with `RequestType` (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION) and `Status` (PENDING, PROCESSING, COMPLETED, REJECTED) enums
- `apps/api/src/main/java/vnpt/vsp/module/round/entity/Round.java` — JPA entity with soft-delete `deletedAt` column
- `apps/api/src/main/java/vnpt/vsp/module/score/entity/Score.java` — JPA entity with soft-delete `deletedAt` column

**Module marker (1)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyModule.java` — lightweight `@interface` annotation

**Repositories (3)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/repository/PrivacyRequestRepository.java` — CRUD + findByStatus, findByRequesterGolferAccountId, countByStatus
- `apps/api/src/main/java/vnpt/vsp/module/round/repository/RoundRepository.java` — findByGolferAccountIdAndDeletedAtIsNull, countByGolferAccountIdAndDeletedAtIsNull
- `apps/api/src/main/java/vnpt/vsp/module/score/repository/ScoreRepository.java` — findByRoundIdAndDeletedAtIsNull

**DTOs (3)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/PrivacyRequestResponse.java` — response DTO with all privacy request fields
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/CreatePrivacyRequestRequest.java` — request DTO: requestType, targetRoundId
- `apps/api/src/main/java/vnpt/vsp/module/privacy/dto/ProcessPrivacyRequestRequest.java` — request DTO: status, rejectionReason

**Service (2)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyService.java` — interface: `createRequest()`, `getMyRequests()`, `getRequestById()`, `getRequestsByStatus()`, `processRequest()`, `getDataExport()`, `deleteAccount()`, `deleteRound()`
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyServiceImpl.java` — full implementation with state machine, audit logging, anonymization, soft-delete

**Controller (1)**
- `apps/api/src/main/java/vnpt/vsp/module/privacy/PrivacyController.java` — REST endpoints for all privacy operations

**Contracts (1)**
- `packages/contracts/schemas/privacy.yaml` — all privacy DTO schemas

**Tests (1)**
- `apps/api/src/test/java/vnpt/vsp/module/privacy/PrivacyServiceImplTest.java` — 17 unit tests

### Modified Files (2)

| File | Change |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` | Added `PRIVACY_001` through `PRIVACY_008` error codes |
| `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` | Added `PRIVACY_REQUEST_SUBMITTED`, `PRIVACY_REQUEST_PROCESSED`, `ACCOUNT_DATA_EXPORTED`, `ACCOUNT_DELETED`, `ROUND_DELETED` |

### Updated Files (1)

| File | Change |
|------|--------|
| `packages/contracts/openapi.yaml` | Added `/privacy/requests`, `/privacy/requests/{id}`, `/privacy/requests/{id}/export`, `/admin/privacy-requests`, `/admin/privacy-requests/{id}` paths; added `Privacy` tag; added schema refs for privacy schemas |

---

## 4. API Endpoints Implemented

| Method | Path | Description |
|--------|------|-------------|
| POST | `/privacy/requests` | Submit a new privacy request (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION) |
| GET | `/privacy/requests` | List all privacy requests for authenticated golfer |
| GET | `/privacy/requests/{id}` | Get a specific privacy request for authenticated golfer |
| GET | `/privacy/requests/{id}/export` | Download data export for a privacy request |
| GET | `/admin/privacy-requests` | Admin: list all privacy requests filtered by status |
| PUT | `/admin/privacy-requests/{id}` | Admin: process (complete or reject) a privacy request |

All golfer endpoints are authenticated (`bearerAuth`). All mutations produce audit log entries.

---

## 5. Entity Design

**PrivacyRequest**: id, requesterGolferAccountId (FK), requestType (DATA_EXPORT/ACCOUNT_DELETION/ROUND_DELETION), status (PENDING/PROCESSING/COMPLETED/REJECTED), targetRoundId (UUID, nullable), requestedAt, processedAt, processedBy, rejectionReason. Timestamps.

**State Machine**: PENDING → PROCESSING → COMPLETED / REJECTED
- PENDING → PROCESSING (admin starts)
- PENDING → REJECTED (admin rejects directly)
- PROCESSING → COMPLETED (triggers action: data export / account anonymization / round deletion)
- PROCESSING → REJECTED (admin rejects with reason)

**Anonymization**: ACCOUNT_DELETION sets `displayName="Deleted User"`, clears phone/email/passwordHash/social subjects, stores encrypted PII in `anonymizedData`, sets `anonymizedAt`, sets `status=DELETED`. Login credentials invalidated.

**Soft-delete**: ROUND_DELETION sets `deletedAt=NOW()` on round and cascades to all associated scores. Active round queries filter `WHERE deleted_at IS NULL`.

---

## 6. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| PRIVACY_001 | Privacy request not found | Request lookup fails |
| PRIVACY_002 | Privacy request already processed | Status is COMPLETED or REJECTED |
| PRIVACY_003 | Invalid privacy request status transition | e.g., PENDING → COMPLETED directly |
| PRIVACY_004 | Cannot delete account with active rounds — delete rounds first | ACCOUNT_DELETION when active rounds exist |
| PRIVACY_005 | Target round not found | Round ID invalid or not owned by requester |
| PRIVACY_006 | Invalid request type | Not DATA_EXPORT/ACCOUNT_DELETION/ROUND_DELETION |
| PRIVACY_007 | Target round does not belong to the requesting account | ROUND_DELETION ownership check |
| PRIVACY_008 | Cannot process request — missing required permissions | Admin check (future RBAC integration) |

---

## 7. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → `clean` → POST_WRITE → `clean` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/dedup_report.json`
Final symbol status: `clean`

---

## 8. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS (144 source files) |
| `mvn test -Dtest=PrivacyServiceImplTest` | ✅ 17 PASS |
| `mvn test -Dtest=PrivacyServiceImplTest,BagServiceImplTest` | ✅ 33 PASS |
| `mvn package -DskipTests` | ✅ PASS |

**Pre-existing failures** (documented in 2-4-A): `VspApiApplicationTests.contextLoads`, `DatabaseHealthIntegrationTest`, `HealthEndpointTest` — OpenTelemetry GlobalOpenTelemetry double-init. Not introduced by this slice.

**Parallel slice conflict** (2-5-A RoleServiceImplTest): 2 errors in `RoleServiceImplTest` (Mockito strictness) — from parallel 2-5-A slice, not this slice.

---

## 9. GET /privacy/requests Response Schema

```json
GET /privacy/requests
[
  {
    "id": 1,
    "requesterGolferAccountId": 42,
    "requestType": "DATA_EXPORT",
    "status": "COMPLETED",
    "targetRoundId": null,
    "requestedAt": "2026-08-02T10:00:00Z",
    "processedAt": "2026-08-02T14:30:00Z",
    "processedBy": 1,
    "rejectionReason": null,
    "createdAt": "2026-08-02T10:00:00Z",
    "updatedAt": "2026-08-02T14:30:00Z"
  }
]
```

---

## 10. Unit Test Coverage

| Test | What It Verifies |
|------|-----------------|
| `createRequest_dataExport_createsPendingRequest` | DATA_EXPORT creates PENDING request with audit |
| `createRequest_accountDeletionWithActiveRounds_throwsPRIVACY_004` | ACCOUNT_DELETION blocked if active rounds exist |
| `createRequest_accountDeletionWithNoActiveRounds_createsRequest` | ACCOUNT_DELETION succeeds when no active rounds |
| `createRequest_roundDeletionWithInvalidRoundId_throwsPRIVACY_005` | ROUND_DELETION fails for invalid round |
| `createRequest_roundDeletionWithValidRound_createsRequest` | ROUND_DELETION creates request with correct targetRoundId |
| `createRequest_invalidRequestType_throwsPRIVACY_006` | Invalid type throws PRIVACY_006 |
| `processRequest_pendingToProcessing_transitionsStatus` | PENDING → PROCESSING with audit |
| `processRequest_alreadyCompleted_throwsPRIVACY_002` | Cannot process already-completed request |
| `processRequest_rejectWithReason_setsRejectionReason` | REJECTED status with rejection reason |
| `processRequest_notFound_throwsPRIVACY_001` | 404 for unknown request |
| `processRequest_invalidStatusTransition_throwsPRIVACY_003` | PENDING → COMPLETED (invalid) throws PRIVACY_003 |
| `deleteAccount_anonymizesAccount` | Account anonymized: name="Deleted User", PII cleared, status=DELETED |
| `deleteAccount_notFound_throwsAUTH_010` | 404 for unknown account |
| `deleteRound_softDeletesRoundAndScores` | Round and scores soft-deleted with audit |
| `deleteRound_roundNotFound_throwsPRIVACY_005` | 404 for unknown or unauthorized round |
| `getMyRequests_returnsAllRequestsForAccount` | Returns all requests for owner |
| `getRequestById_notFound_throwsPRIVACY_001` | 404 for unauthorized or unknown request |

---

## 11. Next Steps

1. **Slice 2-5-A** (parallel): Backend RBAC/MFA — role entity, admin account, MFA, role service/controller
2. **Slice 2-5-C** (depends on A+B): Mobile — Privacy Request Screen UI
3. **Story 2.5 status**: Move to `review` after all slices complete
