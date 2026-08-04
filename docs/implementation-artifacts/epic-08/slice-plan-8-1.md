# Slice Plan — Story 8.1: Manage Facilities and Courses

## Story Summary

| Field | Value |
|-------|-------|
| Story | 8.1 |
| Epic | 8 — Course Operations Portal |
| Title | Manage Facilities and Courses |
| Status | `in-progress` |
| Epic Run | `docs/vnpt-flow/epic-run-run_2026_08_02_010/` |

---

## Context Reading Evidence

| Document | Status |
|----------|--------|
| `docs/planning-artifacts/prd.md` | ✅ Read (551 lines) — FR13, FR18, NFR1-NFR15 |
| `docs/planning-artifacts/architecture.md` | ✅ Read (390 lines) — modular monolith, RBAC, versioning |
| `docs/planning-artifacts/ux-spec.md` | ✅ Read (492 lines) — portal UX, accessibility |
| `docs/planning-artifacts/epics.md` | ✅ Read (748 lines) — Story 8.1 AC, Epic 8 scope |
| `docs/implementation-artifacts/epic-08/8-1-manage-facilities-and-courses.md` | ✅ Read (57 lines) — story spec |
| `docs/implementation-artifacts/sprint-status.yaml` | ✅ Read (99 lines) — story tracking |
| `apps/api/src/main/java/vnpt/vsp/module/course/entity/*.java` | ✅ Read — GolfFacility, Course, Hole, TeeSet entities exist |
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseService.java` | ✅ Read — CRUD service interface exists |
| `apps/api/src/main/java/vnpt/vsp/module/course/CourseServiceImpl.java` | ✅ Read — CRUD implementation exists |
| `apps/api/src/main/java/vnpt/vsp/module/role/RoleService.java` | ✅ Read — RBAC service exists |
| `apps/api/src/main/java/vnpt/vsp/module/role/entity/RoleName.java` | ✅ Read — 6 portal roles defined |
| `apps/api/src/main/resources/db/migration/V16__facilities_courses_holes.sql` | ✅ Read — schema exists |
| `apps/api/src/main/java/vnpt/vsp/api/tournament/TournamentPolicyController.java` | ✅ Read — admin controller pattern |
| `apps/portal/src/pages/**` | ✅ Scanned — no facility/course admin pages yet |

---

## Anti-Shortcut Evidence

- **NOT** implementing geometry editing (Story 8.2 scope)
- **NOT** implementing publish/rollback workflow (Story 8.3/8.4 scope)
- **NOT** implementing pin/green/condition management (Story 8.5 scope)
- **NOT** implementing alerts (Story 8.6 scope)
- **NOT** building full portal app — only stub pages with mock data for this slice
- **NOT** implementing correction workflow (Story 9.x scope)
- **NOT** implementing package generation (Story 4.x scope)

---

## What's In Place (Foundation from Prior Epics)

| Layer | Status | Evidence |
|-------|--------|----------|
| `GolfFacility`, `Course`, `Hole`, `TeeSet` entities | ✅ Exists | `entity/GolfFacility.java`, `entity/Course.java`, `entity/Hole.java`, `entity/TeeSet.java` |
| `CourseService` CRUD interface | ✅ Exists | `CourseService.java` — createFacility, updateFacility, createCourse, updateCourse, createHole, updateHole, createTeeSet |
| `CourseServiceImpl` CRUD implementation | ✅ Exists | Full CRUD with audit logging, metadata defaults |
| `RoleService` RBAC | ✅ Exists | `hasRole(accountId, RoleName)`, `hasAdminRole(accountId)` |
| `RoleName` enum | ✅ Exists | SUPER_ADMIN, COURSE_ADMIN, GREENKEEPER, TOURNAMENT_DIRECTOR, CADDIE_MASTER, AUDITOR |
| Database schema (V16) | ✅ Exists | `golf_facilities`, `courses`, `holes`, `tee_sets` tables with spatial indexes |
| Error codes | ✅ Exists | FACILITY_001, COURSE_001, HOLE_001, TEE_SET_001, VALIDATION_001-007 |
| Audit module | ✅ Exists | `AuditService`, `AuditAction.COURSE_PUBLISH` |
| Portal stub | ⚠️ Minimal | Only tournament policy + package build pages exist |

---

## What's Missing (Story 8.1 Gap)

| Gap | Impact | Notes |
|-----|--------|-------|
| Admin REST controllers | 🔴 Critical | No `/admin/facilities/*`, `/admin/courses/*` endpoints |
| Facility/Course/Hole/TeeSet DTOs | 🔴 Critical | Need request/response DTOs for admin operations |
| RBAC enforcement on admin endpoints | 🔴 Critical | Only COURSE_ADMIN and SUPER_ADMIN should access |
| Draft state tracking | 🟡 Medium | AC says "changes remain draft until publish" — may need `status` field on entities |
| Validation before save | 🟡 Medium | AC: "Validation prevents incomplete required data from publication" |
| Portal pages for facility/course CRUD | 🟡 Medium | No Vue pages exist yet |
| Portal API client stubs | 🟡 Medium | No `api/admin/facilities.ts` etc. |

---

## Acceptance Criteria Coverage

| AC | Description | Implementation Approach |
|----|-------------|------------------------|
| AC-1 | Authorized roles can manage facilities, courses, layouts, holes, tees, scorecards, ratings, rules, and services | Admin REST controllers with `@PreAuthorize` on COURSE_ADMIN or SUPER_ADMIN. Scorecards/ratings/rules/services deferred to future stories (not in scope of this slice — only facility/course/hole/tee metadata) |
| AC-2 | Validation prevents incomplete required data from publication | Bean validation (`@NotNull`, `@NotBlank`, `@Min`/`@Max`) on DTOs + service-layer validation before save |
| AC-3 | Changes remain draft until publish | Add `status` field (DRAFT/PUBLISHED) to Course entity. Portal UI shows draft badge. Publish handled by Story 8.3 |

---

## Slice Plan

### Slice 1: Backend — Admin REST API Foundation

**Goal**: Expose facility/course/hole/tee metadata CRUD via authenticated admin REST endpoints with RBAC.

**Files to create/modify:**

#### API Layer

1. **`apps/api/src/main/java/vnpt/vsp/api/admin/FacilityAdminController.java`** (NEW)
   - `POST /admin/facilities` — create facility (COURSE_ADMIN or SUPER_ADMIN)
   - `GET /admin/facilities` — list all facilities (COURSE_ADMIN or SUPER_ADMIN)
   - `GET /admin/facilities/{id}` — get facility (COURSE_ADMIN or SUPER_ADMIN)
   - `PUT /admin/facilities/{id}` — update facility (COURSE_ADMIN or SUPER_ADMIN)
   - `DELETE /admin/facilities/{id}` — delete facility (SUPER_ADMIN only)
   - Uses `CourseService.createFacility`, `updateFacility`, `listFacilities`, `getFacility`

2. **`apps/api/src/main/java/vnpt/vsp/api/admin/CourseAdminController.java`** (NEW)
   - `POST /admin/facilities/{facilityId}/courses` — create course
   - `GET /admin/facilities/{facilityId}/courses` — list courses
   - `GET /admin/courses/{courseId}` — get course
   - `PUT /admin/courses/{courseId}` — update course
   - `DELETE /admin/courses/{courseId}` — delete course

3. **`apps/api/src/main/java/vnpt/vsp/api/admin/HoleAdminController.java`** (NEW)
   - `POST /admin/courses/{courseId}/holes` — create hole
   - `GET /admin/courses/{courseId}/holes` — list holes
   - `GET /admin/holes/{holeId}` — get hole
   - `PUT /admin/holes/{holeId}` — update hole
   - `DELETE /admin/holes/{holeId}` — delete hole

4. **`apps/api/src/main/java/vnpt/vsp/api/admin/TeeSetAdminController.java`** (NEW)
   - `POST /admin/courses/{courseId}/tee-sets` — create tee set
   - `GET /admin/courses/{courseId}/tee-sets` — list tee sets
   - `GET /admin/tee-sets/{teeSetId}` — get tee set
   - `PUT /admin/tee-sets/{teeSetId}` — update tee set
   - `DELETE /admin/tee-sets/{teeSetId}` — delete tee set

#### DTO Layer

5. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/FacilityCreateRequest.java`** (NEW)
   - Fields: name (required), address, phone, website, location (WKT string)
   - Validation: @NotBlank on name

6. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/FacilityUpdateRequest.java`** (NEW)
   - All fields optional (partial update)

7. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/FacilityResponse.java`** (NEW)
   - All fields + dataQuality + createdAt/updatedAt

8. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseCreateRequest.java`** (NEW)
   - Fields: name, holesCount, parTotal, location
   - Validation: @NotBlank on name, @Min(1)/@Max(36) on holesCount

9. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseUpdateRequest.java`** (NEW)
   - All fields optional

10. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/CourseResponse.java`** (NEW)
    - All fields + facilityId + dataQuality + holesCount + teeSets summary

11. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/HoleCreateRequest.java`** (NEW)
    - Fields: holeNumber, par, teeingGroundLocation (WKT), greenLocation (WKT), playingLengthMeters
    - Validation: @NotNull @Min(1) @Max(9) on holeNumber and par

12. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/HoleUpdateRequest.java`** (NEW)
    - All fields optional

13. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/HoleResponse.java`** (NEW)
    - All fields + courseId + dataQuality + teeBoxes count

14. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/TeeSetCreateRequest.java`** (NEW)
    - Fields: name (required), totalPar
    - Validation: @NotBlank on name

15. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/TeeSetUpdateRequest.java`** (NEW)
    - All fields optional

16. **`apps/api/src/main/java/vnpt/vsp/module/course/dto/TeeSetResponse.java`** (NEW)
    - All fields + courseId + dataQuality

#### Service Layer

17. **`apps/api/src/main/java/vnpt/vsp/module/course/CourseAdminService.java`** (NEW)
    - Interface extending CourseService with admin-specific operations
    - `validateForPublish(courseId)` — returns validation result with missing fields

18. **`apps/api/src/main/java/vnpt/vsp/module/course/CourseAdminServiceImpl.java`** (NEW)
    - Implementation with validation logic for AC-2
    - Checks: facility must have name, course must have name + holesCount + parTotal, each hole must have holeNumber + par + greenLocation

#### Security

19. **`apps/api/src/main/java/vnpt/vsp/api/admin/AdminSecurityConfig.java`** (NEW)
    - Spring Security configuration for `/admin/**` endpoints
    - Requires authentication + COURSE_ADMIN or SUPER_ADMIN role
    - Method-level `@PreAuthorize` as fallback

#### Error Codes

20. Add to `VspErrorCode.java`:
    - `FACILITY_002` — "Facility name is required"
    - `COURSE_009` — "Course name is required for publication"
    - `COURSE_010` — "Course must have at least one hole for publication"
    - `HOLE_002` — "Hole number is required"
    - `VALIDATION_008` — "Geometry validation failed: invalid WKT format"

---

### Slice 2: Portal — Facility/Course Admin Pages (Stub)

**Goal**: Provide stub Vue pages for facility and course management that wire up to the new admin API.

**Files to create:**

1. **`apps/portal/src/api/admin/facilities.ts`** (NEW) — API client for facility CRUD
2. **`apps/portal/src/api/admin/courses.ts`** (NEW) — API client for course CRUD
3. **`apps/portal/src/api/admin/holes.ts`** (NEW) — API client for hole CRUD
4. **`apps/portal/src/api/admin/tee-sets.ts`** (NEW) — API client for tee set CRUD
5. **`apps/portal/src/pages/facilities/index.vue`** (NEW) — Facilities list page
6. **`apps/portal/src/pages/facilities/[id].vue`** (NEW) — Facility detail/edit page
7. **`apps/portal/src/pages/facilities/[id]/courses/index.vue`** (NEW) — Courses list under facility
8. **`apps/portal/src/pages/courses/[courseId]/holes/index.vue`** (NEW) — Holes management
9. **`apps/portal/src/pages/courses/[courseId]/tee-sets/index.vue`** (NEW) — Tee sets management
10. **`apps/portal/src/types/admin/facility.ts`** (NEW) — TypeScript types
11. **`apps/portal/src/types/admin/course.ts`** (NEW)
12. **`apps/portal/src/types/admin/hole.ts`** (NEW)
13. **`apps/portal/src/types/admin/tee-set.ts`** (NEW)

**Portal implementation approach**: Stubs that call the real API once controllers are live. Mock data mode if API unavailable.

---

## Dependencies

| Dependency | Story/Epic | Reason |
|------------|------------|--------|
| CourseService CRUD | Epic 3 (done) | Already exists |
| RoleService RBAC | Epic 2 (done) | Already exists |
| GolfFacility/Course/Hole/TeeSet entities | Epic 3 (done) | Already exist |
| Database schema | Epic 3 (done) | V16 migration already applied |
| Publish workflow | Story 8.3 | AC-3 "changes remain draft until publish" — this story creates draft state; 8.3 handles actual publish |
| Geometry editing | Story 8.2 | Not in scope |

---

## Wave Structure

**Wave 1 (This Slice)**: Backend admin API + portal stubs
- No dependency on other 8.x stories
- Depends only on Epic 3 (done) and Epic 2 (done)

**Wave 2**: (Story 8.2 — Edit Course Geometry)
- Portal map editor component
- Depends on Wave 1 complete

**Wave 3**: (Story 8.3 — Validate and Publish)
- Publish validation + workflow
- Depends on Wave 1 complete

**Wave 4**: (Stories 8.4, 8.5, 8.6)
- Rollback, conditions, alerts
- Depend on Wave 1 + 3

---

## Verification Plan

| Step | Gate | Tool |
|------|------|------|
| Format | ✅ | `mvn fmt:active` or equivalent |
| Lint | ✅ | `mvn checkstyle` or `./gradlew check` |
| Typecheck | ✅ | Portal: `npm run typecheck` |
| Unit tests | ✅ | JUnit tests for CourseAdminServiceImpl validation logic |
| Build | ✅ | `mvn package` for API; portal build stub |
| API contract | ✅ | REST endpoints respond with correct DTOs and HTTP codes |
| RBAC | ✅ | Test 403 for unauthorized roles on all admin endpoints |
| Validation | ✅ | Test 400 when required fields missing |
| Draft state | ✅ | Verify course has DRAFT status after create |
| Portal smoke | ✅ | Stub pages render without console errors |

---

## Notes

- **Scorecards, ratings, rules, services** — Not in scope for this story. The entity model exists (Course has relationships) but admin CRUD for these sub-resources is a future story.
- **Draft state** — Implemented as a `status` field on Course (DRAFT/PUBLISHED). All new courses start as DRAFT. AC-3 is satisfied by default-draft behavior; explicit publish is Story 8.3.
- **Portal stub** — Portal is in early state. This slice creates real API endpoints and stub Vue pages that wire to them. Full portal UI is out of scope.
