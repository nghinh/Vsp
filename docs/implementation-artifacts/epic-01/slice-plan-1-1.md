# Slice Plan — Story 1.1: Initialize Repository and Delivery Environments

## Story Metadata

| Field | Value |
|---|---|
| **Story** | 1.1 |
| **Epic** | 1 — Platform Foundation |
| **Title** | Initialize Repository and Delivery Environments |
| **Status** | in-progress |
| **Phase** | MVP 1 |
| **Source** | `docs/planning-artifacts/epics.md` |

## Acceptance Criteria (source of truth)

| # | Given | When | Then |
|---|---|---|---|
| AC-1 | the target architecture | the repository is initialized | it contains mobile, portal, API, contracts, map-style, course-package, docs, and infrastructure boundaries |
| AC-2 | developer setup | bootstrap commands run | dependencies, local database, and required services start from documented configuration |
| AC-3 | code changes | CI runs | format, lint, typecheck, test, build, migration, and secret checks execute |

## Constraints

- Preserve Flutter, MapLibre, modular-monolith, PostgreSQL/PostGIS, local-first, versioned-contract decisions
- No deferred AI, smartwatch, analytics, tournament-platform, or ecosystem scope
- Dependencies: None beyond approved architecture and repository foundation

---

## Slice Decomposition

### Slice 1 — Repository Structure (AC-1)

**Sub-agent:** `vnpt-epic-story-implementer` in implementation mode

**Purpose:** Create the full directory tree and minimal package files so every boundary is a valid, buildable unit.

**Files to create/modify:**

| Path | Action | Purpose |
|---|---|---|
| `apps/mobile/README.md` | create | Flutter app placeholder |
| `apps/mobile/pubspec.yaml` | create | Minimal Flutter pubspec (flutter SDK constraint, no deps yet) |
| `apps/portal/README.md` | create | Course Operations Portal placeholder |
| `apps/portal/package.json` | create | Minimal Node/web package |
| `apps/api/README.md` | create | Modular monolith backend placeholder |
| `apps/api/pom.xml` | create | Maven or Gradle wrapper for Java/Spring (or Go.mod if Go) — defer language choice to Story 1.2 unless already implied |
| `packages/contracts/README.md` | create | OpenAPI + shared DTO schemas placeholder |
| `packages/contracts/openapi.yaml` | create | Shell OpenAPI document with info object and empty paths |
| `packages/domain/README.md` | create | Shared domain model placeholder |
| `packages/map-style/README.md` | create | MapLibre styles and layer definitions placeholder |
| `packages/map-style/style.json` | create | Shell MapLibre style document |
| `packages/course-package/README.md` | create | Package manifest schema and tooling placeholder |
| `packages/course-package/manifest.schema.json` | create | Shell JSON schema for course package manifest |
| `infra/docker/README.md` | create | Docker infrastructure placeholder |
| `infra/docker/docker-compose.yaml` | create | Docker Compose file with named volumes (PostgreSQL+PostGIS, Redis); no app services yet |
| `infra/migrations/README.md` | create | Database migration tooling placeholder |
| `infra/scripts/README.md` | create | Developer bootstrap scripts placeholder |
| `docs/planning-artifacts/` | preserve | Keep existing planning-artifacts/ contents as-is |
| `docs/implementation-artifacts/` | preserve | Keep existing implementation-artifacts/ contents as-is |

**Verification for Slice 1:**
- `find . -type d | sort` shows all 8 top-level directories (apps/{mobile,portal,api}, packages/{contracts,domain,map-style,course-package}, infra/{docker,migrations,scripts}, docs)
- Each package directory contains at least one file (no empty directories)
- `docker compose -f infra/docker/docker-compose.yaml config` validates without error

**Dependency order:** Slice 1 is independent. It runs first.

---

### Slice 2 — Developer Bootstrap (AC-2)

**Sub-agent:** `vnpt-epic-story-implementer` in implementation mode

**Purpose:** Provide documented, runnable bootstrap so any developer can `git clone && ./bootstrap.sh` and have a working local environment.

**Files to create/modify:**

| Path | Action | Purpose |
|---|---|---|
| `infra/scripts/bootstrap.sh` | create | Master bootstrap: checks prerequisites (Flutter, Docker, git), runs per-component setup |
| `infra/scripts/bootstrapFlutter.sh` | create | Flutter setup: `flutter pub get`, IDE config hints |
| `infra/scripts/bootstrapApi.sh` | create | Backend setup: dependency install, migrations baseline |
| `infra/scripts/setupLocalEnv.sh` | create | Environment variable template (`.env.local.example`) with all required keys |
| `infra/docker/docker-compose.yaml` | update | Add named volume mounts and port bindings for PostgreSQL (5432), Redis (6379); add healthcheck blocks |
| `infra/migrations/001_baseline.sql` | create | Empty migration file with PostGIS extension comment and version marker |
| `infra/scripts/runLocalServices.sh` | create | Starts docker-compose services, waits for healthy, prints connection info |
| `infra/scripts/stopLocalServices.sh` | create | Stops docker-compose services gracefully |
| `apps/mobile/README.md` | update | Document Flutter bootstrap steps and `flutter doctor` requirement |
| `apps/api/README.md` | update | Document API bootstrap, database migration, and environment variable requirements |

**Verification for Slice 2:**
- `infra/scripts/bootstrap.sh` exits 0 on a clean macOS/Linux machine with prerequisites installed
- `docker compose -f infra/docker/docker-compose.yaml up -d` starts PostgreSQL and Redis with healthy status within 60s
- `pg_isready -h localhost -p 5432` returns true after `runLocalServices.sh`
- `redis-cli -h localhost -p 6379 ping` returns PONG
- `flutter pub get` inside `apps/mobile/` exits 0

**Dependency order:** Slice 2 depends on Slice 1 (repository structure must exist before bootstrap scripts reference paths)

---

### Slice 3 — CI Pipeline (AC-3)

**Sub-agent:** `vnpt-epic-story-implementer` in implementation mode

**Purpose:** Enforce quality gates on every commit/PR covering format, lint, typecheck, test, build, migration, and secret scanning across all three surfaces.

**Files to create/modify:**

| Path | Action | Purpose |
|---|---|---|
| `.github/workflows/ci-mobile.yml` | create | Mobile CI: Flutter format, flutter analyze, flutter test, flutter build |
| `.github/workflows/ci-portal.yml` | create | Portal CI: npm format/lint/typecheck/test/build |
| `.github/workflows/ci-api.yml` | create | API CI: maven/gradle/go fmt, static analysis, unit tests, build, DB migration check |
| `.github/workflows/ci-secrets.yml` | create | Shared CI: git-secrets or detect-secrets scan on every push |
| `apps/mobile/analysis_options.yaml` | create | Flutter analysis options (strict null safety, recommended rules) |
| `apps/portal/.eslintrc.json` | create | Portal ESLint config |
| `apps/portal/tsconfig.json` | create | Portal TypeScript config |
| `SECRETS_POLICY.md` | create | Document secret scanning policy and allowed-secrets workflow |

**CI Gate Map:**

| Check | Mobile | Portal | API |
|---|---|---|---|
| Format | `flutter format` | `npm run format` | `gofmt` / `mvn fmt` |
| Lint | `flutter analyze` | `npm run lint` | `staticcheck` / `mvn checkstyle` |
| Typecheck | `flutter analyze` | `npm run typecheck` | `go vet` / `mvn validate` |
| Test | `flutter test` | `npm test` | `go test` / `mvn test` |
| Build | `flutter build apk` | `npm run build` | `go build` / `mvn package` |
| Migration | — | — | Flyway/Liquibase dry-run against baseline |
| Secret scan | `git secrets --scan` | `git secrets --scan` | `git secrets --scan` |

**Verification for Slice 3:**
- Each workflow file is valid YAML and references existing paths
- `docker compose -f infra/docker/docker-compose.yaml config` still valid after any workflow edits to it
- Workflow files use official marketplace actions with pinned SHA or semver pin
- No hardcoded secrets in any workflow file

**Dependency order:** Slice 3 depends on Slices 1 and 2 (CI must reference real paths and scripts that exist after those slices)

---

## Wave Execution Order

```
Wave 1: Slice 1 (Repository Structure)
         ↓
Wave 2: Slice 2 (Developer Bootstrap)
         ↓
Wave 3: Slice 3 (CI Pipeline)
```

Wave 2 may begin only after Wave 1 artifacts exist (paths referenced in bootstrap scripts must exist).
Wave 3 may begin only after Waves 1 and 2 artifacts exist (CI references `apps/`, `infra/scripts/`, `packages/`).

---

## Completeness Check

| AC | Covered by | Evidence |
|---|---|---|
| AC-1 (directory boundaries) | Slice 1 | Directory tree created; each boundary has at least one placeholder file |
| AC-2 (bootstrap) | Slice 2 | `bootstrap.sh`, `docker-compose.yaml`, env templates, `runLocalServices.sh`, `stopLocalServices.sh` |
| AC-3 (CI gates) | Slice 3 | Three workflow files covering mobile/portal/api + shared secret scan workflow |

---

## Risks and Notes

1. **Language choice for `apps/api/`**: Story 1.1 creates only a placeholder. The actual language/framework (Java/Spring, Go, Node, etc.) is deferred to Story 1.2. The `pubspec.yaml`, `package.json`, and `pom.xml` (or `go.mod`) are shells — no runtime dependencies.

2. **Flutter version**: `pubspec.yaml` should use a recent stable Flutter SDK constraint (`>=3.10.0`) without pinning a specific version, to allow `flutter upgrade` without breaking CI.

3. **Secret scanning tool**: GitHub Actions `git-secrets` or `awslabs/git-secrets` is recommended. If not available as a marketplace action, use `zricethezav/gitleaks-action` as a fallback.

4. **PostgreSQL/PostGIS image**: Use `postgis/postgis:16-3.4` (or latest stable) for the Docker Compose service to ensure PostGIS extension is available from the start.

5. **No external secrets in templates**: `.env.local.example` must list all required keys with empty values and clearly comment that real values are injected at runtime, never committed.

---

*Plan authored by `vnpt-epic-story-runner` in planning mode. Ready for `vnpt-dev-epic-orchestrator` to dispatch `vnpt-epic-story-implementer` for each slice in wave order.*
