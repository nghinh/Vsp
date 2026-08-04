# Slice 2-3-A Implementation: Backend Profile Entity, Repository, and API

**Run ID:** run_2026_08_02_005
**Story:** 2.3 — Manage Golfer Profile and Preferences
**Slice:** 2-3-A — Backend Profile Entity + API
**Status:** IMPLEMENTED

---

## 1. Source Status Transitions

| Phase | Status Before | Status After |
|-------|--------------|-------------|
| Story ready-for-dev | `ready-for-dev` | (not changed by implementer) |
| Implementer started | — | `in-progress` |
| Slice complete | — | `done` |

---

## 2. AC Coverage

| AC | Verification |
|----|-------------|
| AC-1: Profile supports all required identity, handicap, home club, unit, hand, skill, target, distance fields | `GolferProfile` entity has all fields; `GolferProfileResponse` returns them all; `ProfileServiceImplTest` verifies all 7 field groups |
| AC-2: Canonical meters storage — unit changes do not corrupt canonical values | `ProfileServiceImplTest.updateProfile_preservesCanonicalDriverDistance_whenDistanceUnitChanges`: updates only `distanceUnit` to YARDS, asserts `driverDistance` remains 200 (meters); `driverDistance` column stores canonical meters; `distanceUnit` is display-only preference |

---

## 3. Files Changed / Created

### New Files (10)

**Migration (1)**
- `apps/api/src/main/resources/db/migration/V6__golfer_profiles.sql`

**Entity (1)**
- `apps/api/src/main/java/vnpt/vsp/module/profile/entity/GolferProfile.java`

**Repository (1)**
- `apps/api/src/main/java/vnpt/vsp/module/profile/repository/GolferProfileRepository.java`

**DTOs (2)**
- `apps/api/src/main/java/vnpt/vsp/module/profile/dto/GolferProfileResponse.java`
- `apps/api/src/main/java/vnpt/vsp/module/profile/dto/UpdateGolferProfileRequest.java`

**Service (2)**
- Updated `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileService.java` — added `getProfile()`, `updateProfile()` interface methods
- Updated `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileServiceImpl.java` — full implementation with auto-create and audit

**Controller (1)**
- `apps/api/src/main/java/vnpt/vsp/module/profile/ProfileController.java`

**Contracts (2)**
- `packages/contracts/schemas/profile.yaml` — `GolferProfileResponse` and `UpdateGolferProfileRequest` schemas
- Updated `packages/contracts/openapi.yaml` — added `/profiles/me` GET+PUT endpoints, `Profiles` tag, schema refs

**Tests (1)**
- `apps/api/src/test/java/vnpt/vsp/module/profile/ProfileServiceImplTest.java` — 7 tests

### Modified Files (3)

| File | Change |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` | Added `PROFILE_UPDATE` audit action |
| `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` | Added `PROFILE_001`, `PROFILE_002`, `PROFILE_003` error codes |

---

## 4. API Endpoints Implemented

| Method | Path | Description |
|--------|------|-------------|
| GET | `/profiles/me` | Get authenticated golfer's profile (auto-creates default on first access) |
| PUT | `/profiles/me` | Update authenticated golfer's profile (partial update supported) |

---

## 5. Entity Design

**Canonical Unit Storage**: All distance values (`driverDistance`) stored in **meters**. The `distanceUnit` field on the profile indicates display preference only — it never triggers conversion of stored values.

**Auto-creation**: `GET /profiles/me` lazily creates a default profile (unit=METERS, hand=RIGHT, skill=INTERMEDIATE) on first access.

**Fields**: id, golferAccountId, handicap, homeClub, distanceUnit, dominantHand, skillLevel, targetScore, driverDistance (meters), swingSpeed, gender, birthYear, country, imageUrl, createdAt, updatedAt

---

## 6. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| PROFILE_001 | Profile not found | Profile lookup fails (not used in current impl — auto-creates) |
| PROFILE_002 | Invalid distance unit value | Invalid `distanceUnit` in request |
| PROFILE_003 | Invalid skill level value | Invalid `skillLevel` in request |

---

## 7. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → `clean` → POST_WRITE → `clean` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/dedup_report.json`
Final symbol status: `clean`

---

## 8. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS |
| `mvn test -Dtest=ProfileServiceImplTest` | ✅ 7 PASS |
| `mvn test` (excluding pre-existing context failures) | ✅ 37 tests PASS (30 Identity + 7 Profile) |
| `mvn package -DskipTests` | ✅ PASS |
| Pre-existing failures | `VspApiApplicationTests.contextLoads`, `DatabaseHealthIntegrationTest`, `HealthEndpointTest` — OpenTelemetry GlobalOpenTelemetry double-init (Epic-01 pre-existing, documented in 2-2-A) |

---

## 9. GET /profiles/me Response Schema

```json
GET /profiles/me
{
  "id": 1,
  "golferAccountId": 42,
  "handicap": 12.5,
  "homeClub": "Vietnam Golf & Country Club",
  "distanceUnit": "METERS",
  "dominantHand": "RIGHT",
  "skillLevel": "INTERMEDIATE",
  "targetScore": 90,
  "driverDistance": 220,
  "swingSpeed": 95,
  "gender": "MALE",
  "birthYear": 1985,
  "country": "Vietnam",
  "imageUrl": "https://cdn.vsp.example.com/profiles/42/avatar.jpg",
  "createdAt": "2026-08-01T10:00:00Z",
  "updatedAt": "2026-08-02T12:30:00Z"
}
```

---

## 10. PUT /profiles/me Response Schema

```
PUT /profiles/me → 200 OK
{
  "id": 1,
  "golferAccountId": 42,
  "handicap": 11.0,
  "homeClub": "Saigon Golf Club",
  "distanceUnit": "YARDS",
  "dominantHand": "LEFT",
  "skillLevel": "ADVANCED",
  "targetScore": 88,
  "driverDistance": 230,    // still meters — AC-2 canonical preservation
  "swingSpeed": 100,
  "gender": "MALE",
  "birthYear": 1980,
  "country": "Vietnam",
  "imageUrl": "https://cdn.vsp.example.com/profiles/42/avatar.jpg",
  "createdAt": "2026-08-01T10:00:00Z",
  "updatedAt": "2026-08-02T14:00:00Z"
}
```

---

## 11. Unit Test Coverage

| Test | What It Verifies |
|------|-----------------|
| `getProfile_returnsExistingProfile_whenProfileExists` | Returns profile with all fields, no save called |
| `getProfile_createsDefaultProfile_whenNoProfileExists` | Auto-creates with defaults (METERS, RIGHT, INTERMEDIATE) |
| `updateProfile_setsAllFields` | All 13 fields are correctly set from request |
| `updateProfile_partialUpdate_onlyUpdatesProvidedFields` | Unset fields remain unchanged |
| `updateProfile_preservesCanonicalDriverDistance_whenDistanceUnitChanges` | AC-2: driverDistance stays 200 meters when distanceUnit changes to YARDS |
| `updateProfile_callsAuditService` | AuditService.PROFILE_UPDATE is logged on update |
| `updateProfile_autoCreatesProfile_whenNoneExists` | Auto-create then update flow on PUT when no profile exists |

---

## 12. Next Steps

1. **Slice 2-3-B**: Mobile — Profile DTO, Repository, Offline Queue (depends on this slice's API contracts)
2. **Slice 2-3-C**: Mobile — Profile Screen UI (depends on this slice's API contracts)
3. **Story 2.3 status**: Move to `review` after all slices complete
