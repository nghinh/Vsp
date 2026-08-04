# Slice 2-4-A Implementation: Backend GolfBag Entity, Club Entity, Repository, and API

**Run ID:** run_2026_08_02_005
**Story:** 2.4 — Manage Golf Bag and Clubs
**Slice:** 2-4-A — Backend bag/club entities + API
**Status:** IMPLEMENTED

---

## 1. Source Status Transitions

| Phase | Status Before | Status After |
|-------|--------------|-------------|
| Story ready-for-dev | `ready-for-dev` | (not changed by implementer) |
| Slice work started | — | `in-progress` |
| Slice complete | — | `done` |

---

## 2. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-02/2-4-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-3-A-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-4-manage-golf-bag-and-clubs.md"
  ],
  "mockup_sources_read": [
    "docs/vnpt-stitch-mockup-batch/README.md"
  ]
}
```

**Note:** Acceptance matrices for 1-2 and 1-3 do not exist on disk. No Figma/wireframe/mockup docs exist for this story.

---

## 3. AC Coverage

| AC | Verification |
|----|-------------|
| AC-1: User can create bags and add/edit/delete clubs with loft, carry, total, dispersion, shaft, and use date | `BagServiceImpl`: full CRUD for bags and clubs; `Club` entity has all AC-1 fields; `BagServiceImplTest` covers create bag (sets name), create club (sets all 7 fields), update club (partial update), delete club |
| AC-2: Exactly one bag can be selected as active for a round | `BagServiceImpl.setActiveBag()` runs `deactivateAllForAccount()` then activates target; `BagServiceImplTest.setActiveBag_deactivatesOthers_andActivatesTarget()` verifies transactional enforcement; `BagServiceImplTest.deleteBag_throwsBAG_002_whenLastBag` prevents orphan state |
| AC-3: Data-driven recommendations remain disabled until minimum data threshold is met | `BagService.hasMinimumClubData()` checks `countByGolfBagIdAndCarryDistanceIsNotNull >= 1`; `BagServiceImplTest.hasMinimumClubData_returnsTrue_whenAtLeastOneClubHasCarryDistance` and `hasMinimumClubData_returnsFalse_whenNoClubsWithCarryDistance` verify threshold |

---

## 4. Files Changed / Created

### New Files (16)

**Migrations (2)**
- `apps/api/src/main/resources/db/migration/V7__golf_bags.sql` — `golf_bags` table (id, golfer_account_id FK, name, is_active, created_at, updated_at)
- `apps/api/src/main/resources/db/migration/V8__clubs.sql` — `clubs` table (id, golf_bag_id FK, club_type enum, loft, carry_distance, total_distance, dispersion, shaft, use_date, timestamps)

**Entities (2)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/entity/GolfBag.java` — JPA entity; `isActive` boolean; lazy club list; timestamps
- `apps/api/src/main/java/vnpt/vsp/module/bag/entity/Club.java` — JPA entity; `ClubType` enum (DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER); all AC-1 fields; timestamps

**Repositories (2)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/repository/GolfBagRepository.java` — `findByGolferAccountId`, `findByGolferAccountIdAndIsActiveTrue`, `findByIdAndGolferAccountId`, `countByGolferAccountId`, `deactivateAllForAccount`
- `apps/api/src/main/java/vnpt/vsp/module/bag/repository/ClubRepository.java` — `findByGolfBagId`, `findByIdAndGolfBagId`, `countByGolfBagId`, `countByGolfBagIdAndCarryDistanceIsNotNull`

**Module marker (1)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagModule.java` — lightweight `@interface` annotation

**DTOs (6)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/GolfBagResponse.java` — response DTO with all bag fields + list of clubs
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/CreateGolfBagRequest.java` — name field with validation
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/UpdateGolfBagRequest.java` — name + isActive (partial update)
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/ClubResponse.java` — response DTO with all club fields
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/CreateClubRequest.java` — all club fields with validation
- `apps/api/src/main/java/vnpt/vsp/module/bag/dto/UpdateClubRequest.java` — partial update DTO

**Service (2)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagService.java` — interface: `getBags`, `createBag`, `updateBag`, `deleteBag`, `setActiveBag`, `getActiveBag`, `getClubs`, `createClub`, `updateClub`, `deleteClub`, `hasMinimumClubData`
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagServiceImpl.java` — full implementation with audit, auto-create default bag, transactional active-bag enforcement

**Controller (1)**
- `apps/api/src/main/java/vnpt/vsp/module/bag/BagController.java` — REST endpoints for all bag and club operations

**Contracts (2)**
- `packages/contracts/schemas/bag.yaml` — all bag/club DTO schemas
- Updated `packages/contracts/openapi.yaml` — added all `/bags/*` endpoints, `Bags` tag, schema refs

**Tests (1)**
- `apps/api/src/test/java/vnpt/vsp/module/bag/BagServiceImplTest.java` — 16 unit tests

### Modified Files (2)

| File | Change |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` | Added `BAG_001`, `BAG_002`, `CLUB_001`, `CLUB_002` error codes |
| `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` | Added `BAG_CREATE`, `BAG_UPDATE`, `BAG_DELETE`, `CLUB_CREATE`, `CLUB_UPDATE`, `CLUB_DELETE` audit actions |

---

## 5. API Endpoints Implemented

| Method | Path | Description |
|--------|------|-------------|
| GET | `/bags` | List all bags for authenticated golfer (auto-creates default bag on first access) |
| POST | `/bags` | Create a new golf bag |
| GET | `/bags/{bagId}` | Get a specific bag by ID |
| PUT | `/bags/{bagId}` | Update a bag (partial update; `isActive: true` activates bag) |
| DELETE | `/bags/{bagId}` | Delete a bag (fails with BAG_002 if last bag) |
| POST | `/bags/{bagId}/activate` | Set a bag as active (AC-2: deactivates all others) |
| GET | `/bags/{bagId}/clubs` | List all clubs in a bag |
| POST | `/bags/{bagId}/clubs` | Add a club to a bag (all AC-1 fields) |
| PUT | `/bags/{bagId}/clubs/{clubId}` | Update a club (partial update) |
| DELETE | `/bags/{bagId}/clubs/{clubId}` | Delete a club |

All endpoints are authenticated (`bearerAuth`). All mutations produce audit log entries.

---

## 6. Entity Design

**GolfBag**: id, golferAccountId (FK), name (VARCHAR 255), isActive (BOOLEAN), createdAt, updatedAt. Cascade delete from clubs.

**Club**: id, golfBagId (FK), clubType (enum DRIVER/WOOD/HYBRID/IRON/WEDGE/PUTTER), loft (DOUBLE, degrees), carryDistance (DOUBLE, meters, canonical), totalDistance (DOUBLE, meters, canonical), dispersion (DOUBLE, degrees — Phase 2 scope, stored but not used in MVP), shaft (VARCHAR 100), useDate (DATE), createdAt, updatedAt.

**Canonical Unit Storage**: `carryDistance` and `totalDistance` stored in **meters**. The mobile layer handles display conversion (meters ↔ yards).

**AC-2 Enforcement**: `setActiveBag()` runs in a transaction: `UPDATE golf_bags SET is_active=false WHERE golfer_account_id=X; UPDATE golf_bags SET is_active=true WHERE id=bagId`. Service-layer enforcement (no partial unique index needed).

**Auto-create Default Bag**: On first `GET /bags` call, if no bags exist, auto-creates a default bag named "My Bag" with `isActive=true`.

**AC-3 Threshold**: `hasMinimumClubData(bagId)` returns `countByGolfBagIdAndCarryDistanceIsNotNull(bagId) >= 1`.

---

## 7. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| BAG_001 | Golf bag not found | Bag lookup fails for ownership check |
| BAG_002 | Cannot delete the last remaining bag | `deleteBag` when count <= 1 |
| CLUB_001 | Club not found | Club lookup fails for ownership check |
| CLUB_002 | Club does not belong to the specified bag | Club bag-id mismatch (not used — bag ownership verified first) |

---

## 8. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → `clean` → POST_WRITE → `clean` → precheck → `new_duplicate_likely: false` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/dedup_report.json`
Final symbol status: `clean`

---

## 9. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS |
| `mvn test -Dtest=BagServiceImplTest` | ✅ 16 PASS |
| `mvn test` (full suite) | ✅ 53 PASS, 8 pre-existing errors (see below) |
| `mvn package -DskipTests` | ✅ PASS |

**Pre-existing failures** (documented in 2-2-A and 2-3-A): `VspApiApplicationTests.contextLoads`, `DatabaseHealthIntegrationTest`, `HealthEndpointTest` — OpenTelemetry GlobalOpenTelemetry double-init. Not introduced by this slice.

---

## 10. GET /bags Response Schema

```json
GET /bags
[
  {
    "id": 1,
    "golferAccountId": 42,
    "name": "My Bag",
    "isActive": true,
    "clubs": [
      {
        "id": 1,
        "golfBagId": 1,
        "clubType": "DRIVER",
        "loft": 10.5,
        "carryDistance": 220.0,
        "totalDistance": 235.0,
        "dispersion": 5.2,
        "shaft": "Graphite, Regular Flex",
        "useDate": "2026-01-15",
        "createdAt": "2026-08-02T10:00:00Z",
        "updatedAt": "2026-08-02T10:00:00Z"
      }
    ],
    "createdAt": "2026-08-02T10:00:00Z",
    "updatedAt": "2026-08-02T10:00:00Z"
  }
]
```

---

## 11. POST /bags/{bagId}/clubs Response Schema

```json
POST /bags/1/clubs
{
  "id": 2,
  "golfBagId": 1,
  "clubType": "IRON",
  "loft": 25.0,
  "carryDistance": 150.0,
  "totalDistance": 160.0,
  "dispersion": 4.5,
  "shaft": "Steel, Stiff Flex",
  "useDate": "2026-02-01",
  "createdAt": "2026-08-02T12:00:00Z",
  "updatedAt": "2026-08-02T12:00:00Z"
}
```

---

## 12. Unit Test Coverage

| Test | What It Verifies |
|------|-----------------|
| `getBags_returnsBags_whenBagsExist` | Returns bag list without save |
| `getBags_createsDefaultBag_whenNoBagsExist` | Auto-creates "My Bag" with active=true on first access |
| `createBag_setsBagFields` | Name set, isActive=false, audit logged |
| `updateBag_updatesName` | Partial update works for name |
| `setActiveBag_deactivatesOthers_andActivatesTarget` | AC-2: `deactivateAllForAccount()` called before activation |
| `setActiveBag_throws_whenBagNotFound` | BAG_001 thrown for unknown bag |
| `updateBag_withIsActiveTrue_deactivatesOthers` | Setting isActive via PUT also deactivates others |
| `deleteBag_throwsBAG_002_whenLastBag` | Cannot delete last bag (BAG_002) |
| `deleteBag_succeeds_whenNotLastBag` | Delete works with audit and count > 1 |
| `createClub_setsAllFields` | All 7 club fields set correctly; audit logged |
| `updateClub_updatesOnlyProvidedFields` | Partial update preserves unset fields |
| `deleteClub_deletesAndAudits` | Delete works with audit |
| `createClub_throwsBAG_001_whenBagNotFound` | BAG_001 on bad bag ownership |
| `updateClub_throwsCLUB_001_whenClubNotFound` | CLUB_001 on club not in bag |
| `hasMinimumClubData_returnsTrue_whenAtLeastOneClubHasCarryDistance` | AC-3: threshold >= 1 with carryDistance |
| `hasMinimumClubData_returnsFalse_whenNoClubsWithCarryDistance` | AC-3: threshold fails when no carryDistance |

---

## 13. Next Steps

1. **Slice 2-4-B**: Mobile — Bag/Club DTO, Repository, Offline Queue (depends on these API contracts)
2. **Slice 2-4-C**: Mobile — Bag/Club Screen UI (depends on these API contracts)
3. **Story 2.4 status**: Move to `review` after all slices complete
