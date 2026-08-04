---
name: bmad-vnpt-api-integration-guard
description: Use before web frontend, React Native, Flutter, or mobile app work that integrates with an existing backend API, especially when OpenAPI/Swagger docs exist and precision matters.
---
# BMAD VNPT API Integration Guard

## When to use
Use this skill for:
- web frontend integration with an existing backend
- React Native or Flutter integration with an existing backend
- fixing incorrect API wiring, payloads, auth headers, response parsing, or pagination
- replacing mock data with real backend calls
- validating AI-generated API integration before completion

Do not use this for designing a new backend API from scratch. Use the backend stack skill first, then return here when consuming the API.

## Core stance
- Contract first. The OpenAPI/Swagger contract is the starting point.
- Backend live behavior must be tested before UI/mobile wiring is considered complete.
- No guessed endpoints, fields, auth schemes, status codes, response nesting, pagination, upload formats, or date formats.
- Fail closed when evidence is missing.
- Mock-only work requires explicit user permission.

## Mandatory execution protocol
Follow this exact order. Do not skip ahead.

1. Restate the feature scope in 1-3 lines.
2. Locate the contract source.
3. Read the contract sections needed for this feature.
4. Validate the contract shape or lint result.
5. Resolve base URL, auth, and runtime environment.
6. Probe the live backend with safe requests.
7. Build the endpoint map.
8. Write a short fix plan from the endpoint map and live probe results.
9. Only then change integration code.
10. Run validation commands.
11. Finish with the required evidence block.

If any step from 2-8 fails, do not code the integration.

## Required workflow
1. Discover the contract:
   - Search `docs/`, `openapi.*`, `swagger.*`, API docs routes, README/runbooks, and user-provided paths.
   - Read the selected spec file fully before concluding anything from it.
   - If multiple specs exist, identify the target service/version and state why.
   - If no contract is found, stop and use the `BLOCKED` template below.
2. Read the relevant contract fully:
   - Capture `servers`, `securitySchemes`, endpoint paths, methods, params, request bodies, response bodies, error shapes, pagination, upload/download formats, and examples.
   - For multi-step flows, capture required call order and dependencies.
   - Do not rely on endpoint names alone. Confirm request and response shapes.
3. Validate the contract:
   - Prefer existing repo scripts.
   - Otherwise use available tools such as Redocly, Spectral, Swagger parser, OpenAPI Generator validation, or a minimal JSON/YAML structural check.
   - If validation cannot run, state the exact reason. Continue only if the contract is still readable and the live backend can be probed.
4. Probe the live backend:
   - Resolve base URL from contract `servers`, env files, runtime config, docs, or running process output.
   - Identify auth, tenant, headers, cookies, and required env.
   - Use safe requests first: health, metadata, list, or read-only detail endpoint.
   - Record status code, content type, key response fields, and mismatch against contract.
   - If backend cannot be safely reached, stop unless the user explicitly allows mock-only work.
5. Build the endpoint map before coding:
   - Include method, path, base URL, auth, params, request body, success response, error response, and live probe evidence.
   - Only map endpoints needed by the current feature.
   - Do not code until this map is explicit.
6. Write a short fix plan:
   - Summarize the exact endpoint(s), mismatch(es), and implementation steps.
   - State the files or layers that will change.
   - State the validation checks that will prove the fix.
   - If the plan cannot be written, stop and return `BLOCKED`.
7. Integrate through a narrow client boundary:
   - Prefer generated clients/types if the repo already has OpenAPI codegen or an obvious generator setup.
   - Otherwise create or update a thin API adapter/service layer.
   - Keep UI/mobile components unaware of raw HTTP details.
   - Preserve existing repo conventions for fetch/axios/tanstack-query/RTK Query/SWR/Retrofit/Ktor/Dio/http clients.
8. Wire UI/mobile behavior:
   - Bind screens only to mapped endpoints.
   - Handle loading, empty, success, validation error, auth error, permission error, network error, and retry where the product flow needs them.
   - Do not silently swallow backend errors.
9. Validate:
   - Run the narrowest meaningful checks first: typecheck, lint, unit tests, component/widget tests, generated client checks, then build/smoke when affordable.
   - If validation fails because backend/spec is inconsistent, report it as an integration blocker instead of guessing a workaround.

## Fail-closed conditions
Stop and report before editing integration code when:
- no API contract is found
- target backend/base URL is unknown
- auth or required env is unknown
- live backend cannot be probed safely
- contract and live backend disagree for a required endpoint
- only mock data is available and the user did not approve mock-only integration

## Hard prohibitions
Never do any of these:
- invent an endpoint path because the screen name sounds similar
- rename fields to match frontend naming preference without proof
- assume `data`, `items`, `result`, or `payload` wrappers without a live response
- assume bearer auth, refresh token flow, or cookie auth without proof
- assume page numbering starts at `0` or `1` without proof
- assume date format, timezone, enum values, or nullable fields without proof
- connect UI directly to raw HTTP calls when the repo already has a client/service layer
- mark the task complete without a live probe or explicit mock-only approval

## BLOCKED template
When blocked, stop coding and respond with:

```markdown
## BLOCKED
- Reason:
- Missing evidence:
- Exact file or endpoint checked:
- What was attempted:
- Next required input or environment:
```

## Required endpoint map
Before editing integration code, produce this block in working notes or response:

```markdown
## Endpoint Map
| Feature action | Method | Path | Auth | Request body | Success response | Error response | Live probe |
|---|---|---|---|---|---|---|---|
```

## Required fix plan
Before editing integration code, produce this block in working notes or response:

```markdown
## Fix Plan
- Mismatch:
- Endpoint(s):
- Files/layers to change:
- Implementation steps:
- Validation:
```

## Required evidence block
Every final response after using this skill must include:

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

If any endpoint was not live-probed, say so explicitly in `Gaps:` and do not claim precise integration for that endpoint.

## Practical tool preferences
- For OpenAPI linting, prefer repo scripts; otherwise use Redocly/Spectral when available.
- For client generation, prefer the repo's existing generator and checked-in config.
- For live probes, prefer safe read-only endpoints and avoid destructive POST/PATCH/DELETE unless the user explicitly provides a sandbox/test target.
- For multi-call workflows, write the call sequence explicitly before coding.
