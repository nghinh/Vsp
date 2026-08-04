# Phase: 04-test-case-design

## Purpose

Design QA-grade test cases before automation: examples, combinatorial model, state model, properties, API fuzz, exploratory, regression, fixtures.

## Required inputs

- outputs from all earlier phases
- relevant project files read from 0-EOF
- current risk map and oracle where applicable

## Required work

- happy/negative/boundary/error/recovery cases
- PICT/ACTS dimensions and constraints
- state model and forbidden transitions
- invariants and generators
- API fuzz plan
- exploratory charter
- regression cases
- test data

## Required output

`docs/qa/<feature>/04a-04k artifacts`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark SPEC_AMBIGUITY

## Medium-model strict checklist

Before leaving this phase, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## Required test-case depth matrix

For each P0/P1 risk, create a table:

| Risk ID | Example tests | Negative tests | Boundary/edge tests | State tests | Property tests | API/E2E tests | Gaps |
|---|---:|---:|---:|---:|---:|---:|---|

Minimum rules:

- P0: 1 happy, 2 negative, 2 boundary/edge, 1 recovery/error, plus state/property/API/E2E where applicable.
- P1: 1 main-path, 1 negative, 1 boundary/edge, plus applicable strategy coverage.

## Required bug-class sweep

For every feature, explicitly mark `Applicable`, `Not applicable`, or `Gap` for:

- state transition
- validation
- boundary/off-by-one
- null/empty/missing field
- duplicate action/event/request
- timeout/retry/cancel
- concurrency/rapid repeat
- persistence mismatch
- stale/wrong UI state
- API contract mismatch
- error handling
- regression around changed files
- security/permission when relevant
- offline/online/network when relevant
- performance/large data when relevant
