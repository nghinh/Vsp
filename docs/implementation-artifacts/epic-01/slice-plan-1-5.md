# Slice Plan — Story 1.5: Establish Observability and Security Baseline

## Story Metadata

| Field | Value |
|---|---|
| Story | 1.5 |
| Epic | 1 — Platform Foundation |
| Title | Establish Observability and Security Baseline |
| Status | `backlog` (ready-for-dev pending this plan) |
| Phase | MVP 1 |
| Dependencies | Story 1.4 (Design System Foundations) |
| Source | `docs/planning-artifacts/epics.md` §Epic 1 Story 1.5 |

---

## Evidence of Reading Required Docs

- `docs/planning-artifacts/epics.md` — Story 1.5 in §Epic 1, ACs: structured logs/metrics/traces/correlation IDs/alerting, secrets management, TLS/encryption/scanning/backups/audit retention
- `docs/planning-artifacts/prd.md` — NFR9 (TLS, encryption, RBAC, MFA, rate limiting), NFR10 (deletion/export/consent/retention), NFR11 (audit), §10.6 Security/Privacy checklist, §10.8 Observability
- `docs/planning-artifacts/architecture.md` — §12 Security Architecture (OAuth, tokens, MFA, RBAC, audit, encryption, no secrets in mobile/repo), §13 Observability Architecture (mobile crashes, map load, GPS, hole detection, package errors, sync, API latency, weather, publish/rollback, battery), §5 deployment environments (dev/staging/prod)
- `docs/planning-artifacts/ux-spec.md` — §10.8 Observability for UX: crash, performance, GPS quality, hole detection accuracy, package errors, weather API errors, battery, sync failures, map latency
- `docs/implementation-artifacts/epic-01/1-5-establish-observability-and-security-baseline.md` — Story source with ACs and tasks
- `.runtime/current/source-root-contract.json` — EffectiveSourceRoot=/Users/nghinh/Downloads/projects/vsp

---

## Acceptance Criteria Table

| # | Criterion | Verification |
|---|---|---|
| AC-1 | Structured logs, metrics, traces/correlation IDs, and environment-specific alerting are configured | JSON log output confirmed, Micrometer metrics endpoint enabled, OpenTelemetry tracing auto-instrumented, alert rules scoped per env |
| AC-2 | Secrets are externally managed and never shipped in clients or committed | `.env.example` documented, CI Gitleaks pass, no hardcoded secrets in source, secrets loaded from env/SM at runtime |
| AC-3 | TLS, encryption at rest, dependency scanning, backups, and audit retention are configured | TLS configured (server.ssl.* in prod profile), DB encryption at rest documented, OWASP dependency-check in CI, backup retention policy defined, audit schema + service implemented |

---

## Existing Infrastructure Analysis

### Already in place (Story 1.3)
- `CorrelationIdFilter.java` — generates/propagates `X-Correlation-ID` via MDC + response header ✅
- `CorrelationId.java` — `@Inherited` annotation for explicit correlation logging ✅
- `GlobalExceptionHandler.java` — structured `ErrorResponse` with `correlationId` ✅

### Already in place (repo-level)
- `SECRETS_POLICY.md` — zero-tolerance secrets policy documented ✅
- `ci-secrets.yml` — Gitleaks runs on every push/PR ✅
- `ci-api.yml` — includes secret scan step ✅

### Not yet configured (gaps to fill)
- **Structured logging** — SLF4J present but no JSON encoder; Logback config needed
- **Metrics** — `spring-boot-starter-actuator` present but `/actuator/prometheus` not exposed; Micrometer not wired
- **Distributed tracing** — OpenTelemetry not integrated; correlation IDs not propagated to spans
- **Environment-specific alerting** — no alerting config per env
- **Secrets management** — `.env.example` exists but no Vault/SM integration; no `.env.example` for API
- **TLS** — not configured in `application.yml`; no SSL bundle
- **Encryption at rest** — not configured; requires PostgreSQL `pgcrypto` or cloud KMS
- **Dependency scanning** — no OWASP dependency-check in CI
- **Backups** — no backup retention policy or script
- **Audit retention** — `AuditService` is a stub; `AuditModule` annotation only; no entity, no schema, no logging of mutations
- **Environment configs** — `application.yml` exists; `application-dev.yml` exists; no `application-staging.yml` / `application-prod.yml`

---

## Constraints

1. **Java 21 + Spring Boot 3.2.5** — use `spring-boot-starter-actuator` already present in `pom.xml`; add Micrometer + OpenTelemetry BOMs
2. **No new build tools** — use Maven plugins (OWASP dependency-check-maven) already available
3. **Audit module is a stub** — this story completes the audit infrastructure (entity, service, logging)
4. **CorrelationId is already done** — re-used, not re-implemented
5. **Secrets already scanned** — expand existing Gitleaks CI, don't replace it
6. **Modular monolith** — audit logging must be injectable into other modules via `AuditService` interface
7. **No frontend/mobile work** — observability on backend only; mobile telemetry is later Epic 6+ scope
8. **No auth implementation** — MFA, RBAC are Epic 2 stories; this story only prepares the infrastructure
9. **Environment parity** — dev/staging/prod profiles must diverge only where necessary (alerts, TLS, retention)

---

## Slice Decomposition

### Slice OBS-1: Observability Infrastructure
**Files to create/modify:**
- `infra/docker/docker-compose.yaml` — add `otel-collector` service for traces/metrics aggregation
- `apps/api/src/main/resources/logback-spring.xml` — **create**: JSON structured log pattern, env-aware appender config, correlation ID pattern
- `apps/api/src/main/resources/application.yml` — **modify**: expose Micrometer metrics (`/actuator/prometheus`), add `management.metrics.*` config, add `management.tracing.*` config
- `apps/api/src/main/resources/application-dev.yml` — **modify**: dev-only log level overrides
- `apps/api/src/main/resources/application-staging.yml` — **create**: staging log level, no PII-logging
- `apps/api/src/main/resources/application-prod.yml` — **create**: prod log config, sampling rules, alerting thresholds
- `apps/api/pom.xml` — **modify**: add `micrometer-registry-prometheus`, `opentelemetry-instrumentation-bom`, `opentelemetry-exporter-otlp`, `logback encoder (logstash-logback-encoder)`
- `apps/api/src/main/java/vnpt/vsp/api/observability/OtelConfig.java` — **create**: OpenTelemetry bean auto-configuration
- `apps/api/src/main/java/vnpt/vsp/api/observability/MetricsConfig.java` — **create**: Micrometer custom meters (sync.queue.depth, api.latency, gps.quality, package.download.count)
- `apps/api/src/main/java/vnpt/vsp/api/observability/AlertRules.java` — **create**: env-specific alert thresholds loaded from config
- `.github/workflows/ci-api.yml` — **modify**: add dependency-check goal after test

**Purpose:** Full observability stack — structured JSON logs, Micrometer metrics, OpenTelemetry tracing, environment-specific alerting config.

**Verification:** `mvn test` passes; `mvn package` succeeds with JSON logs visible in stdout; `curl localhost:8080/actuator/prometheus` returns metrics; no hardcoded secrets.

---

### Slice OBS-2: Security Baseline
**Files to create/modify:**
- `apps/api/src/main/resources/application-prod.yml` — **modify** (or create if OBS-1 not done): add `server.ssl.*` TLS config, `spring.security.ssl.bundle.jks` keystore ref
- `infra/scripts/setupLocalEnv.sh` — **modify**: add `VSP_SECRETS_MANAGER_*` vars, `VSP_TLS_*` vars, backup retention vars, `VSP_DB_ENCRYPTION_KEY_REF`
- `apps/api/src/main/resources/application.yml` — **modify**: add `spring.jpa.properties.hibernate.dialect` with pgcrypto note; add backup schedule vars
- `infra/docker/docker-compose.yaml` — **modify**: add `backup-cron` service (volumes mounted, pg_dump cron)
- `apps/api/pom.xml` — **modify**: add `dependency-check-maven` plugin for OWASP scanning
- `.github/workflows/ci-api.yml` — **modify**: add `mvn org.owasp:dependency-check-maven:check` step
- `docs/ops/backup-retention-policy.md` — **create**: documented policy — daily incremental, weekly full, 30-day retention, 1-year archive, 7-year compliance
- `docs/ops/encryption-policy.md` — **create**: TLS 1.3 only, cipher suites, DB encryption at rest via pgcrypto/AWS RDS KMS, key rotation schedule
- `infra/scripts/backup.sh` — **create**: pg_dump script with encryption, S3 upload, retention pruning

**Purpose:** Security baseline — TLS config, DB encryption docs, dependency scanning, backup retention, no secrets committed.

**Verification:** OWASP dependency-check returns 0 unmitigated vulns; backup script is idempotent; TLS config is valid; no secrets in source.

---

### Slice OBS-3: Backend Module Audit Infrastructure
**Files to create/modify:**
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditEntry.java` — **create**: JPA entity — id, actor, role, action, objectType, objectId, beforeJson, afterJson, metadataJson, correlationId, timestamp, version
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAction.java` — **create**: enum — COURSE_PUBLISH, COURSE_ROLLBACK, PIN_UPDATE, GREEN_UPDATE, CONDITION_UPDATE, ADMIN_LOGIN, CORRECTION_APPROVE, CORRECTION_REJECT, ROLE_ASSIGN
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditServiceImpl.java` — **modify**: implement `log(AuditAction, objectType, objectId, before, after, metadata)` writing to `audit_entries` table via JPA; also write to structured log with correlation ID
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditService.java` — **modify**: add `log(AuditAction, objectType, objectId, beforeJson, afterJson, metadataJson)` method signature
- `apps/api/src/main/java/vnpt/vsp/module/audit/Audited.java` — **create**: `@Audited` annotation for methods that must emit audit log on invocation
- `apps/api/src/main/java/vnpt/vsp/module/audit/AuditAspect.java` — **create**: AOP aspect intercepting `@Audited` methods; extracts actor/role from SecurityContext; calls AuditService
- `apps/api/src/main/resources/db/migration/V1__audit_entries.sql` — **create**: Flyway migration — `audit_entries` table with all columns, indexes on (object_type, object_id), (actor, timestamp), (action, timestamp), GIST index on bounding box if PostGIS available
- `apps/api/src/main/resources/application.yml` — **modify**: add `audit.retention-days: 2555` (7-year compliance per NFR10)
- `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityServiceImpl.java` — **modify**: inject AuditService; add `log(ADMIN_LOGIN)` on successful admin authentication
- `apps/api/src/main/java/vnpt/vsp/module/course/CourseServiceImpl.java` — **modify**: inject AuditService; add `log(COURSE_PUBLISH)` and `log(COURSE_ROLLBACK)` calls
- `apps/api/src/main/java/vnpt/vsp/module/operations/OperationsServiceImpl.java` — **modify**: inject AuditService; add `log(PIN_UPDATE)`, `log(GREEN_UPDATE)`, `log(CONDITION_UPDATE)` calls
- `apps/api/src/main/java/vnpt/vsp/module/correction/CorrectionServiceImpl.java` — **modify**: inject AuditService; add `log(CORRECTION_APPROVE)`, `log(CORRECTION_REJECT)` calls

**Purpose:** Audit infrastructure for all admin and course-data mutations — entity, service, AOP aspect, Flyway migration, module integration.

**Verification:** Flyway migration runs; `audit_entries` table exists with correct schema; audit logs written on audited operations; audit log entries contain correlation ID matching request correlation ID.

---

## Wave Execution Order

```
Wave 1 (foundation — must execute first)
  └─ OBS-1: Observability Infrastructure
      ├─ Add Micrometer + OpenTelemetry + Logback encoder dependencies (pom.xml)
      ├─ Create logback-spring.xml (JSON structured logging)
      ├─ Create application-staging.yml, application-prod.yml
      ├─ Create OtelConfig, MetricsConfig, AlertRules
      ├─ Update application.yml with actuator metrics + tracing config
      └─ Add dependency-check to CI

Wave 2 (security and ops — parallel with Wave 1, no direct OBS-1 dependency)
  ├─ OBS-2: Security Baseline
  │   ├─ Add dependency-check-maven to pom.xml + CI
  │   ├─ Create backup-retention-policy.md + backup.sh
  │   ├─ Create encryption-policy.md
  │   ├─ Update application-prod.yml with TLS config
  │   └─ Update setupLocalEnv.sh with secrets manager vars
  └─ OBS-3: Audit Infrastructure
      ├─ Create audit_entries Flyway migration
      ├─ Create AuditEntry entity + AuditAction enum
      ├─ Implement AuditServiceImpl
      ├─ Create Audited annotation + AuditAspect
      └─ Integrate into IdentityModule, CourseModule, OperationsModule, CorrectionModule

Wave 1 must complete before Wave 2 artifacts are final, but OBS-2 and OBS-3 can be planned in parallel.
```

**Dependency reasoning:**
- OBS-2 (security baseline) has no code dependency on OBS-1, but both share `application-prod.yml` — coordination needed so OBS-1's prod profile is not overwritten by OBS-2's additions.
- OBS-3 (audit) uses the correlation ID from OBS-1's `CorrelationIdFilter` — so OBS-1's `MDC` setup must be confirmed before finalizing audit log correlation.
- Wave order is `OBS-1 → [OBS-2 ‖ OBS-3]` in practice, or `OBS-1 → OBS-2 + OBS-3` sequentially if implementer prefers.

---

## Completeness Check Table

| Criterion | Slice(s) | Check |
|---|---|---|
| AC-1: Structured JSON logs | OBS-1 | `logback-spring.xml` uses `LogstashEncoder`; `grep -c '"correlationId"'` on log output |
| AC-1: Metrics endpoint | OBS-1 | `curl /actuator/prometheus | grep vsp_api` returns histogram/counter entries |
| AC-1: Traces/correlation IDs | OBS-1 | OpenTelemetry auto-instrumentation in pom.xml; `CorrelationIdFilter` already propagates to spans |
| AC-1: Environment-specific alerting | OBS-1 | `AlertRules.java` reads env-specific thresholds from `application-*.yml` |
| AC-2: No secrets committed | OBS-2 | Gitleaks CI passes; `grep -r "password\|secret\|key" apps/api/src/main/resources/*.yml` returns only env var refs |
| AC-2: External secrets management | OBS-2 | `VSP_SECRETS_MANAGER_*` vars in `setupLocalEnv.sh`; no hardcoded values in source |
| AC-3: TLS configured | OBS-2 | `server.ssl.*` present in `application-prod.yml` |
| AC-3: Encryption at rest | OBS-2 | `encryption-policy.md` documents pgcrypto/RDS KMS; `backup.sh` encrypts dumps |
| AC-3: Dependency scanning | OBS-2 | OWASP dependency-check in CI returns 0 unmitigated vulns |
| AC-3: Backups | OBS-2 | `backup.sh` exists and is executable; `backup-retention-policy.md` exists |
| AC-3: Audit retention | OBS-3 | `audit_entries` table exists; `audit.retention-days: 2555` in `application.yml`; Flyway migration V1 runs |
| AC-3: Admin/course-data mutations audited | OBS-3 | `AuditService` called from `IdentityServiceImpl`, `CourseServiceImpl`, `OperationsServiceImpl`, `CorrectionServiceImpl`; audit entries visible in DB |
| All existing stories unaffected | — | Stories 1.1–1.3 still pass their tests after changes |
| No new structural coupling | — | AuditService remains an interface; AuditModule annotation unchanged |

---

## Risks and Notes

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| JSON logging breaks existing plain-text log grep patterns in developer tooling | Low | Medium | Keep `logback-spring.xml` env-aware so dev profile can use plain-text; prod uses JSON |
| OpenTelemetry collector adds infra complexity for local dev | Low | Low | `docker-compose.yaml` adds otel-collector as optional; dev can run without it using in-agent export |
| Audit logging in high-throughput path adds latency | Low | Medium | Use async log appender + ring buffer; audit write is non-blocking |
| OWASP dependency-check causes CI failure on known CVE in transitive dep with no fix | Medium | Medium | Add `dependencyCheck failBuildOnCVSS=7` threshold; known false positives go to `dependency-check-suppressions.xml` |
| Backup script requires cloud credentials (S3) that aren't available in dev | Low | Low | backup.sh detects `AWS_*` env vars; skips upload if absent; local pg_dump still runs |
| AuditAspect creates circular dependency risk (module AOP depends on module services) | Low | Medium | AuditAspect lives in audit module; modules only depend on AuditService interface; no circular dep |
| TLS config requires keystore file not yet generated | High | Medium | `application-prod.yml` uses `${VSP_SSL_KEYSTORE_PATH}` env var; keystore generation deferred to deployment automation (not in MVP scope); this story configures the config contract only |
| Story 1.4 (Design System) not yet started — Story 1.5 depends on it | Low | Low | Story 1.5 does not actually depend on Story 1.4 for code; "dependency" in story file is framework/context only; proceeding with plan |

---

## Implementation Notes

- **OBS-1 first** — all other slices benefit from the observability output (metrics, tracing, structured logs)
- **OBS-2 and OBS-3 are independent** — can be implemented in parallel once OBS-1 is confirmed
- **pom.xml additions for OBS-1**: `micrometer-registry-prometheus`, `opentelemetry-instrumentation-bom`, `opentelemetry-exporter-otlp`, `logstash-logback-encoder`, `opentelemetry-spring-boot-starter`
- **pom.xml additions for OBS-2**: `org.owasp:dependency-check-maven`
- **No Flutter/mobile changes** — mobile observability is Epic 6+ (NFR15 telemetry scope)
- **No new Spring Security config** — auth/MFA/RBAC are Epic 2; this story only prepares the TLS and audit infrastructure
- **Audit entries are append-only** — no update/delete operations on `audit_entries` table; retention enforced by scheduled job (later ops story)
- **Correlation IDs from OBS-1 flow into OBS-3** — the `CorrelationIdFilter` MDC context is propagated into the audit log entry via `MDC.get("correlationId")` at the time of logging
