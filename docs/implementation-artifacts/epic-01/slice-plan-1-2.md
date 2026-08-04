---
story: "1.2"
epic: 1
title: "Establish Backend Modular Monolith"
status: ready-for-dev (planning)
phase: "MVP 1"
source: docs/planning-artifacts/epics.md
---

# Slice Plan — Story 1.2: Establish Backend Modular Monolith

## Story Metadata

| Field | Value |
|-------|-------|
| Story | 1.2 |
| Epic | 1 — Platform Foundation |
| Title | Establish Backend Modular Monolith |
| Status | ready-for-dev |
| Phase | MVP 1 |
| Source | `docs/planning-artifacts/epics.md` |
| Dependencies | Story 1.1 (`apps/api/pom.xml` shell exists) |
| Tech | Java 21, Spring Boot, Maven, PostgreSQL/PostGIS |

---

## Acceptance Criteria Table

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-1 | 12 modules exist for identity, profiles, courses, geospatial, packages, rounds, scores, weather, corrections, operations, audit, notifications | `mvn compile` succeeds; each module dir contains service interface |
| AC-2 | Cross-module calls use defined service interfaces, not direct table access | Each module exposes only interface types to other modules |
| AC-3 | Health and readiness endpoints report application and database status | `GET /actuator/health` returns `{"status":"UP","components":{"db":...}}` |

---

## Constraints

- **Language/framework**: Java 21 + Spring Boot (already declared in Story 1.1 pom.xml)
- **Build tool**: Maven (`mvnw`)
- **Database**: PostgreSQL + PostGIS via `docker-compose` from Story 1.1
- **No runtime dependencies added beyond Spring Boot starter + actuator + postgresql**
- **No business logic implemented** — only module scaffolding, interfaces, and infrastructure wiring
- **Do not change `apps/api/pom.xml` groupId/artifactId/version**

---

## Module Inventory (Architecture Section 6)

| # | Module | Package | Purpose |
|---|--------|---------|---------|
| 1 | Identity | `vnpt.vsp.module.identity` | User auth, sessions, tokens |
| 2 | Profiles | `vnpt.vsp.module.profile` | Golfer profile, preferences |
| 3 | Courses | `vnpt.vsp.module.course` | Course catalog, metadata |
| 4 | Geospatial | `vnpt.vsp.module.geospatial` | PostGIS geometry, spatial queries |
| 5 | Packages | `vnpt.vsp.module.package` | Course package manifest, generation |
| 6 | Rounds | `vnpt.vsp.module.round` | Round lifecycle, configuration |
| 7 | Scores | `vnpt.vsp.module.score` | Score entry, flight scoring |
| 8 | Weather | `vnpt.vsp.module.weather` | Weather snapshots, provider integration |
| 9 | Corrections | `vnpt.vsp.module.correction` | Course data correction workflow |
| 10 | Operations | `vnpt.vsp.module.operations` | Course ops portal backend |
| 11 | Audit | `vnpt.vsp.module.audit` | Audit logging, version history |
| 12 | Notifications | `vnpt.vsp.module.notification` | Async notification dispatch |

---

## Slice Decomposition

### Slice 1 — Spring Boot Foundation + Health/Readiness

**Sub-agent**: `bmad-dev-story` (amelia / dev agent)  
**Purpose**: Establish a compile-ready, runnable Spring Boot application with health endpoints

**Files to create:**

| File | Purpose |
|------|---------|
| `apps/api/pom.xml` | Updated parent POM with Spring Boot, actuator, postgresql deps |
| `apps/api/src/main/java/vnpt/vsp/VspApiApplication.java` | Spring Boot main class |
| `apps/api/src/main/java/vnpt/vsp/config/HealthConfig.java` | Health contributor for DB |
| `apps/api/src/main/java/vnpt/vsp/config/DatabaseConfig.java` | PostgreSQL DataSource |
| `apps/api/src/main/resources/application.yml` | Server port, datasource URL, actuator path |
| `apps/api/src/main/resources/db/migration/001_baseline.sql` | PostGIS extension + schema version marker |
| `apps/api/src/test/java/vnpt/vsp/VspApiApplicationTests.java` | Smoke test: context loads |
| `apps/api/src/test/java/vnpt/vsp/HealthEndpointTest.java` | Verifies `/actuator/health` returns UP |
| `apps/api/.mvn/wrapper/maven-wrapper.properties` | Maven wrapper (copied from standard dist) |

**Verification Criteria:**
- `mvn compile -q` exits 0
- `mvn test -q` exits 0
- `GET /actuator/health` HTTP 200 with `{"status":"UP"}`
- `GET /actuator/health/liveness` HTTP 200
- `GET /actuator/health/readiness` HTTP 200 with db component present

**Dependency Order**: First — no dependencies

---

### Slice 2 — 12 Module Skeleton with Service Interfaces

**Sub-agent**: `bmad-dev-story` (amelia / dev agent)  
**Purpose**: Create the 12 module directories and their public service interfaces; establish cross-module contract convention

**Files to create (12 modules × 2 files each minimum):**

| Module | Interface | Stub Impl |
|--------|-----------|-----------|
| identity | `IdentityService.java` | `IdentityServiceImpl.java` |
| profile | `ProfileService.java` | `ProfileServiceImpl.java` |
| course | `CourseService.java` | `CourseServiceImpl.java` |
| geospatial | `GeospatialService.java` | `GeospatialServiceImpl.java` |
| package | `PackageService.java` | `PackageServiceImpl.java` |
| round | `RoundService.java` | `RoundServiceImpl.java` |
| score | `ScoreService.java` | `ScoreServiceImpl.java` |
| weather | `WeatherService.java` | `WeatherServiceImpl.java` |
| correction | `CorrectionService.java` | `CorrectionServiceImpl.java` |
| operations | `OperationsService.java` | `OperationsServiceImpl.java` |
| audit | `AuditService.java` | `AuditServiceImpl.java` |
| notification | `NotificationService.java` | `NotificationServiceImpl.java` |

**Convention**: Every `*Service` interface is `public interface` in module's package. No module may `@Autowired` a concrete `*Impl` from another module — only the interface.

**Additional files:**
- `apps/api/src/main/java/vnpt/vsp/module/<name>/<Name>Module.java` — lightweight marker annotation (e.g., `@IdentityModule`)
- `apps/api/src/main/java/vnpt/vsp/module/<name>/dto/` — placeholder DTO directory (empty, for structure only)

**Verification Criteria:**
- `mvn compile -q` exits 0
- Each module package contains exactly one `*Service.java` interface
- No `*ServiceImpl.java` referenced by `@Autowired` from another module
- All 12 module marker annotations are present

**Dependency Order**: After Slice 1

---

### Slice 3 — Database Baseline Migration + Integration Smoke Test

**Sub-agent**: `bmad-dev-story` (amelia / dev agent)  
**Purpose**: Connect to database, run baseline migration, verify health endpoint reflects DB status

**Files to create:**

| File | Purpose |
|------|---------|
| `apps/api/src/test/java/vnpt/vsp/DatabaseHealthIntegrationTest.java` | Verifies DB connectivity via health endpoint |
| `apps/api/src/main/resources/application-dev.yml` | Dev profile with local DB connection |
| `apps/api/src/test/resources/application-test.yml` | Test profile with H2 in-memory (if feasible) or testcontainers |

**Verification Criteria:**
- `mvn verify -q` (includes test phase) exits 0
- `GET /actuator/health` response includes `"db":{"status":"UP","details":{"database":"PostgreSQL"}}`
- Flyway migration `001_baseline` applies without error

**Dependency Order**: After Slice 2 (requires module structure to exist)

---

## Wave Execution Order

```
Wave 1: Slice 1 (Spring Boot + health endpoints)
        ↓
Wave 2: Slice 2 (12 module skeletons + interfaces)
        ↓
Wave 3: Slice 3 (DB baseline + DB-aware health)
```

Each slice is independently implementable and verifiable. Wave N+1 does not begin until Wave N's verification criteria are clean.

---

## Completeness Check Table

| Criterion | Slice 1 | Slice 2 | Slice 3 |
|-----------|---------|---------|---------|
| All 12 module dirs exist | — | ✅ | — |
| Each module has `*Service` interface | — | ✅ | — |
| Each module has stub `*Impl` | — | ✅ | — |
| No cross-module impl coupling | — | ✅ | — |
| Health endpoint returns UP | ✅ | — | — |
| Health endpoint has DB component | — | — | ✅ |
| `mvn compile` passes | ✅ | ✅ | ✅ |
| `mvn test` passes | ✅ | — | ✅ |
| `mvn verify` passes | — | — | ✅ |

---

## Anti-Shortcut Evidence

- **No module contains business logic** — only interfaces and empty stub implementations
- **No `*Repository` or `*Entity` classes created** — those belong to later stories (Epic 3+)
- **No REST controllers created** — those belong to Story 1.3 (API contracts)
- **Health endpoint DB check uses Spring Boot `DataSourceHealthIndicator`** — no custom SQL unless Flyway baseline
- **`001_baseline.sql` only creates `PostGIS` extension and `schema_version` table** — no domain tables

---

## Risks and Notes

| Risk | Mitigation |
|------|------------|
| Spring Boot version mismatch with Java 21 | Use Spring Boot 3.2.x which supports Java 21 |
| H2 test DB incompatibility with PostGIS | Use testcontainers for integration tests; unit tests use mocks |
| Module naming conflict with future Spring components | Use explicit `@Module` annotation + package-scanning base-package restriction |
| Cross-module circular dependencies | No module `*Impl` annotated `@Service`; interfaces only at boundaries |

---

## Source Root Contract Evidence

- `effectiveSourceRoot`: `/Users/nghinh/Downloads/projects/vsp`
- All file paths in this plan are relative to that root
- No files are created outside `apps/api/`

---

## prd_sources_read

- `docs/planning-artifacts/prd.md` — lines 1–551 (full read)
  - Technology decisions: Flutter, MapLibre, PostgreSQL/PostGIS (lines 93–127)
  - MVP 1 scope: backend API platform (lines 128–174)

## project_context_sources_read

- `docs/planning-artifacts/architecture.md` — lines 1–390 (full read)
  - Section 6: Modular Monolith Boundaries, 12 modules listed (lines 94–113)
  - Section 11: API Architecture (lines 259–290)
  - Section 17: Repository Shape (lines 359–380)

## story_sources_read

- `docs/implementation-artifacts/epic-01/1-2-establish-backend-modular-monolith.md` — lines 1–57 (full read)
  - Status: ready-for-dev
  - AC: 12 modules, interface-based cross-module calls, health/readiness endpoints
- `docs/planning-artifacts/epics.md` — lines 1–748 (full read)
  - Story 1.2 description (lines 145–153)
  - Epic 1 scope (lines 131–184)

## mockup_sources_read

N/A — no mockups for backend infrastructure story

## source_root_contract_read

- `.runtime/current/source-root-contract.json` — lines 1–10 (full read)
  - `effectiveSourceRoot`: `/Users/nghinh/Downloads/projects/vsp`

## story_1_1_output_read

- `docs/implementation-artifacts/epic-01/1-1-initialize-repository-and-delivery-environments.md` — lines 1–57 (full read)
  - Status: done
  - `apps/api/pom.xml` is a bare Maven shell (Java 21, no deps)
  - `apps/api/README.md` describes bootstrap scripts and docker-compose from Story 1.1
