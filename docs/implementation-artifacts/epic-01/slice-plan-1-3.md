# Slice Plan — Story 1.3: Establish API Contracts and Error Standards

## Story Metadata

| Field | Value |
|---|---|
| Story | 1.3 |
| Epic | 1 — Platform Foundation |
| Title | Establish API Contracts and Error Standards |
| Status | `ready-for-dev` |
| Phase | MVP 1 |
| Dependencies | Story 1.2 (backend modular monolith, apps/api/ with 12 modules) |
| Source | `docs/planning-artifacts/epics.md` §Epic 1 Story 1.3 |

---

## Acceptance Criteria Table

| # | Criterion | Verification |
|---|---|---|
| AC-1 | OpenAPI defines `/auth/*`, `/courses/*`, `/packages/*`, `/rounds/*`, `/scores/*`, `/weather/*`, `/corrections/*`, `/admin/*` endpoint groups | `openapi.yaml` paths entries validated against this list |
| AC-2 | Every API response includes stable machine-readable error `code` and `correlationId` | Global error schema includes `code` (string) and `correlationId` (string) fields; filter injects correlation ID header |
| AC-3 | Write endpoints support `Idempotency-Key` header; duplicate submissions return the original response | `IdempotencyFilter` + `IdempotencyService` with in-memory store (swap to Redis in later story); annotation marks idempotent endpoints |
| AC-4 | List endpoints support cursor-based pagination with `pageToken` / `pageSize` / `hasMore` | `Pagination` DTO schema + `PageTokenService` utility; `@Paged` annotation on list operations |
| AC-5 | Version-check endpoints (`GET /courses/{id}/packages`) return `ETag` / `If-None-Match` and 304 Not Modified | `ETag` header on versioned resources; `VersionedResponse` wrapper; filter handles `If-None-Match` |

---

## Constraints

1. **No controllers yet** — Story 1.2 delivered only module/service layer. Story 1.3 establishes the REST contract shell; actual controller implementations land in domain-specific stories.
2. **Spring Boot 3.2.5 + Java 21** — Use `spring-boot-starter-web` already present in `pom.xml`.
3. **No new modules** — Follow the 12-module structure from Story 1.2; error/pagination/idempotency are cross-cutting concerns under `apps/api/src/main/java/vnpt/vsp/`.
4. **Structured error codes** — Stable codes are `VSP-ERR-<DOMAIN>-<NUMBER>` (e.g., `VSP-ERR-AUTH-001`, `VSP-ERR-COURSE-003`). Domain codes: `AUTH`, `COURSE`, `PACKAGE`, `ROUND`, `SCORE`, `WEATHER`, `CORRECTION`, `ADMIN`, `VALIDATION`, `INTERNAL`.
5. **packages/contracts/openapi.yaml** is the single source of truth for the API surface — no duplicate spec files.
6. **ETags + pagination only for course-package endpoints in this story** — extension to other endpoints is a later-story decision.
7. **Idempotency store is in-memory** — replaced with Redis in Story 1.5 or later ops story. Store contract must not change.
8. **Do not implement auth logic** — auth is Story 2.1. This story only defines the contract and error handling infrastructure.

---

## Slice Decomposition

### Slice 1: OpenAPI Contract Population
**File:** `packages/contracts/openapi.yaml` (update) + `packages/contracts/schemas/` (new)

Populate the shell OpenAPI spec with full path definitions, schemas, and security schemes. No runtime behavior — this is a contract-only deliverable.

**Contents:**
- `openapi.yaml` — add all 8 path groups with representative operation signatures (no implementation)
- `schemas/common.yaml` — shared `Error`, `Pagination`, `PageToken`, `IdempotencyKey` schemas
- `schemas/auth.yaml` — `LoginRequest`, `LoginResponse`, `RegisterRequest`, `TokenRefreshRequest`
- `schemas/course.yaml` — `Course`, `CourseSummary`, `CourseVersion`, `CoursePackage`
- `schemas/round.yaml` — `Round`, `RoundCreate`, `RoundUpdate`
- `schemas/score.yaml` — `Score`, `ScoreEntry`, `Scorecard`
- `schemas/weather.yaml` — `WeatherSnapshot`, `WindData`
- `schemas/correction.yaml` — `Correction`, `CorrectionCreate`, `CorrectionReview`
- `schemas/admin.yaml` — `PublishRequest`, `RollbackRequest`, `AuditEntry`

**AC served:** AC-1

---

### Slice 2: Error Standards Infrastructure
**File:** `apps/api/src/main/java/vnpt/vsp/api/` (new structure)

Establish structured error response infrastructure and correlation ID injection.

**Contents:**
- `api/error/VspErrorCode.java` — enum of all stable error codes with code string + HTTP status mapping
- `api/error/VspApiException.java` — runtime exception carrying `VspErrorCode` + optional field name + details
- `api/error/ErrorResponse.java` — DTO: `{ code, message, correlationId, field?, details? }`
- `api/error/GlobalExceptionHandler.java` — `@RestControllerAdvice` converting `VspApiException` + Spring failures to `ErrorResponse`
- `api/error/CorrelationIdFilter.java` — `OncePerRequestFilter` that extracts `X-Correlation-ID` header or generates UUID; sets on `MDC` and response header
- `api/error/CorrelationId.java` — `@Inherited` annotation for endpoints to opt into explicit correlation ID logging

**AC served:** AC-2

---

### Slice 3: Idempotency Infrastructure
**File:** `apps/api/src/main/java/vnpt/vsp/api/idempotency/`

Implement idempotency key support for write endpoints.

**Contents:**
- `IdempotencyService.java` — interface
- `InMemoryIdempotencyService.java` — in-memory `ConcurrentHashMap` implementation (contract ready for Redis swap)
- `IdempotencyFilter.java` — `OncePerRequestFilter` reading `Idempotency-Key` header; if duplicate key seen, returns cached response with `X-Idempotent-Replay: true`
- `Idempotent.java` — `@Target(ElementType.METHOD)` annotation marking write endpoints; `keyHeader()` defaults to `Idempotency-Key`

**AC served:** AC-3

---

### Slice 4: Pagination Infrastructure
**File:** `apps/api/src/main/java/vnpt/vsp/api/pagination/`

Implement cursor-based pagination for list endpoints.

**Contents:**
- `PageTokenService.java` — encodes/decodes cursor tokens (Base64 JSON: `{ page, pageSize, sortField, sortDir, anchor? }`)
- `Pagination.java` — DTO: `{ items, pageToken, hasMore, totalCount? }`
- `Paged.java` — `@Target(ElementType.METHOD)` annotation: `defaultPageSize()`, `maxPageSize()`
- `PaginationArgumentResolver.java` — `HandlerMethodArgumentResolver` that reads `pageToken` / `pageSize` from request, validates bounds, and injects `PageRequest`
- `PaginationAdvice.java` — `@RestControllerAdvice` wrapping list responses in `Pagination`

**AC served:** AC-4

---

### Slice 5: ETag / Version-Check Infrastructure
**File:** `apps/api/src/main/java/vnpt/vsp/api/versioning/`

Implement `ETag` support for versioned resources.

**Contents:**
- `Versioned.java` — `@Target(ElementType.TYPE)` annotation marking entities that carry a version hash
- `VersionedEntity.java` — interface: `getVersionHash()` → String (SHA-1 of content version)
- `ETagFilter.java` — `OncePerRequestFilter` handling `If-None-Match`; returns `304 Not Modified` when ETag matches; adds `ETag` header otherwise
- `ETagService.java` — utility: `computeETag(Object entity)` using SHA-1 of serialized content

**AC served:** AC-5

---

## Wave Execution Order

```
Wave A (contract + cross-cutting — can run sequentially or parallel within wave)
  ├─ Slice 1: OpenAPI Contract Population  (packages/contracts/openapi.yaml)
  └─ Slice 2: Error Standards Infrastructure  (apps/api/)

Wave B (cross-cutting built on Wave A)
  ├─ Slice 3: Idempotency Infrastructure  (depends on: Slice 2)
  ├─ Slice 4: Pagination Infrastructure  (depends on: Slice 2)
  └─ Slice 5: ETag Infrastructure  (depends on: Slice 2)

All slices complete → story done
```

**Dependency note:** Slices 3, 4, 5 all depend on Slice 2's `ErrorResponse` and `GlobalExceptionHandler`. Slice 1 (OpenAPI contract) has no runtime dependency and should execute first or in parallel with Slice 2.

---

## Completeness Check Table

| Criterion | Slice(s) | Check |
|---|---|---|
| AC-1: OpenAPI has all 8 endpoint groups | Slice 1 | Path count ≥ 8 groups; `grep -c '^\s*- /'` in openapi.yaml |
| AC-1: OpenAPI paths are syntactically valid | Slice 1 | `openapi.yaml` passes `yamllint` or equivalent validation |
| AC-2: Error schema has `code` and `correlationId` | Slice 1 + 2 | Schema `ErrorResponse` includes both fields; filter injects correlation ID |
| AC-3: Idempotency-Key handled | Slice 3 | `IdempotencyFilter` present; duplicate key returns cached response |
| AC-4: Pagination on list endpoints | Slice 4 | `Pagination` DTO + `PaginationArgumentResolver` + `Paged` annotation |
| AC-5: ETag on versioned resources | Slice 5 | `ETag` filter + `VersionedEntity` interface |
| All 12 modules from Story 1.2 remain unmodified | — | `git diff` on module directories is empty |
| No new Spring controllers | — | No `*Controller.java` files added in this story |
| Error codes are stable (no `VSP-ERR-INTERNAL-999` exposed) | Slice 2 | All public errors use domain-scoped codes |
| Idempotency store is swappable | Slice 3 | `IdempotencyService` interface + `InMemoryIdempotencyService` impl |

---

## Risks and Notes

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Idempotency in-memory store loses data on restart (acceptable for MVP, Redis in later story) | Low | Low | Contract is Redis-ready; in-memory is explicit MVP choice |
| Pagination approach needs to be cursor-based (not offset) to avoid inconsistent results on moving data | Low | Medium | `PageToken` uses cursor (opaque encoded token), not SQL `OFFSET` |
| ETag computation on large entities may be expensive | Low | Medium | ETag computed from version hash field, not full entity serialization |
| OpenAPI spec getting out of sync with runtime controllers | Medium | High | Spec is contract-first; controllers reference shared schema objects; dedup script catches drift |
| Error code enum growth needs governance | Low | Medium | Domain-scoped codes (AUTH, COURSE, etc.) prevent collisions; new codes require justification |

---

## Implementation Notes

- **openapi-generator not used in this story** — contract is hand-authored for precision. Code generation from spec is a later-story decision.
- **`apps/api/src/main/java/vnpt/vsp/api/`** — new `api/` package under `vsp` root holds all cross-cutting REST infrastructure. This keeps it separate from domain modules.
- **No test controllers** — this story produces contract + infrastructure only. Integration tests that exercise the filter chain are in scope.
- **pom.xml additions needed:** `spring-boot-starter-validation` (already in web starter) for bean validation on request DTOs.
