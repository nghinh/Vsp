# Workflow: bmad-vnpt-api-integration-guard

## Intent
Use this workflow when a web or mobile feature must integrate with an existing backend API.

The goal is precise integration, not fast guessing. The agent must prove the API contract and live backend behavior before changing UI or mobile code.

## Execution order
1. Scope gate: restate feature scope and target backend/service.
2. Discovery gate: find the OpenAPI/Swagger contract in `docs/`, `openapi.*`, `swagger.*`, runtime API docs, or the path provided by the user.
3. Contract gate: read the relevant contract sections fully and create an endpoint map before coding.
4. Validation gate: lint or structurally validate the API contract before trusting it.
5. Runtime gate: identify base URL, auth, environment, and required headers/cookies.
6. Live backend gate: probe a safe endpoint against the running backend.
7. Fix-plan gate: write a short plan from the endpoint map and live probe results.
8. Integration gate: use generated clients/types when the repo already supports them; otherwise create a thin API adapter matching the contract.
9. UI/mobile gate: wire screens only to endpoints that passed contract and live checks.
10. Evidence gate: report contract source, backend probe, integrated endpoints, changed files, validation commands, and gaps.

## Fail-closed rules
- Stop if no API contract is found.
- Stop if the backend cannot be reached or safely probed.
- Stop if auth, tenant, base URL, or required env is unknown.
- Stop if the live response contradicts the contract for the endpoint being integrated.
- Stop before using mock data unless the user explicitly asked for mock-only work.
- Stop if the endpoint map was not written before coding.
- Stop if a fix plan was not written before coding.

## Required output
Before coding, write:

```markdown
## Endpoint Map
| Feature action | Method | Path | Auth | Request body | Success response | Error response | Live probe |
|---|---|---|---|---|---|---|---|
```

Then write:

```markdown
## Fix Plan
- Mismatch:
- Endpoint(s):
- Files/layers to change:
- Implementation steps:
- Validation:
```

When blocked, write:

```markdown
## BLOCKED
- Reason:
- Missing evidence:
- Exact file or endpoint checked:
- What was attempted:
- Next required input or environment:
```

After coding or validation, finish with:

```markdown
## API Integration Evidence
- Spec source:
- Spec validation:
- Backend base URL:
- Auth/env used:
- Endpoints integrated:
- Live probes:
- Client/adapter files:
- UI/mobile files:
- Tests/validation:
- Gaps:
```
