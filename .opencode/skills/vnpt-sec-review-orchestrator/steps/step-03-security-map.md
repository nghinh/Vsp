# Step 03: Security Risk Map — Stack Detection and Lane Routing

**Goal:** Detect stack coverage, route the review through relevant `bmad-vnpt-security` lanes, and build `security-risk-map.md` with control-family routing.

## Sequence

### 1. Stack detection

Scan the resolved scope for stack indicators:

| Stack | Indicators |
|-------|-----------|
| nodejs | `package.json`, `*.js`, `*.ts` (non-react), `node_modules/` |
| python | `requirements.txt`, `setup.py`, `pyproject.toml`, `*.py` |
| go | `go.mod`, `*.go` |
| java-spring | `pom.xml`, `build.gradle`, `application.properties` |
| dotnet | `*.csproj`, `*.sln` |
| php | `composer.json`, `*.php` |
| c-cpp | `CMakeLists.txt`, `*.c`, `*.cpp`, `*.h` |
| frontend-react | `package.json` + `react`, `*.jsx`, `*.tsx` |
| frontend-vue | `package.json` + `vue`, `*.vue` |
| frontend-angular | `angular.json`, `*.ng.ts` |
| mobile-flutter | `pubspec.yaml`, `lib/**/*.dart` |
| mobile-react | `package.json` + `react-native`, `App.tsx` |

### 2. Control family mapping

Map detected stack to control families using `config/security-lane-routing.yaml`:

```yaml
control_families:
  authn_authz_session_token: auth
  injection_input_handling: appsec
  secrets_crypto_logging: devsecops
  api_abuse_rate_limiting_object_authorization: api
  dependency_supply_chain_provenance_signing: devsecops
  container_kubernetes_iac_runtime_hardening: cloud-k8s
  observability_audit_compliance: compliance
```

### 3. Lane routing

Route review through `bmad-vnpt-security` lanes based on detected stacks:
- `appsec` — application security (default fallback)
- `api` — API-specific security
- `auth` — authentication/authorization
- `devsecops` — secrets, dependencies, supply chain
- `cloud-k8s` — container, Kubernetes, IaC
- `compliance` — observability, audit
- Plus stack-specific lanes: `nodejs`, `python`, `go`, `java-spring`, `dotnet`, `php`, `c-cpp`, `frontend-react`, `frontend-vue`, `frontend-angular`, `mobile-flutter`, `mobile-react`

### 4. Security risk taxonomy

Map each P0/P1 risk to at least one control family:
- authn/authz/session/token
- injection/input handling
- secrets/crypto/logging
- API abuse/rate limiting/object-level authorization
- dependency/supply-chain/provenance/signing
- container/Kubernetes/IaC/runtime hardening
- observability/audit/compliance

### 5. Build security-risk-map.md

Write `docs/vnpt-flow/<scope-id>/security-review/security-risk-map.md`:

```
# Security Risk Map

## Scope
- scope_id: <from state>
- scope_source: <from state>

## Stack Detection Result
[detected stacks and their indicators]

## Control Family Routing
[risk → lane mapping per control family]

## Risk IDs and Validation Routes
| Risk ID | Control Family | Lane | Validation Route |
|---------|---------------|------|------------------|
| R-001 | authn/authz | auth | validate_authz |
| R-002 | injection | appsec | validate_injection |

## Phase Trace
| Input checked | Decision made | Output artifact | Open gap | Next action |
|---------------|---------------|-----------------|----------|-------------|
| context-map done | stack detected | risk-map done | none | proceed to review pass |
```

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-risk-map.md`

## Next step

After security risk map is complete, update `security-review-state.json` status to `review_pass` and proceed to `step-04-review-pass.md`.
