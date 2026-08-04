# Step 04: Test Case Design (Examples + Combinatorial + State + Property + API + Exploratory + Regression + Fixtures)

**Goal:** Design QA-grade test cases before automation: examples, combinatorial model, state model, properties, API fuzz plan, exploratory charter, regression plan, fixtures. This step produces the artifact set `04a` through `04k`. No automation, no execution, no oracle is allowed before this step finishes.

## Prerequisites

- `02-risk-map.md` exists with prioritized risks.
- `03-test-strategy.md` exists with executable strategies.
- `qa-state.json` `phase_status = "test_strategy_planning"`.

## Sequence

### Step 4.1 — Produce example-based test cases (`04a-example-test-cases.md`)

Generate example test cases for happy, negative, boundary, error, recovery, regression. Each test gets a stable ID with the `QA-EX-` prefix.

### Step 4.2 — Produce combinatorial dimensions and PICT model (`04b`, `04c`, `04d`)

Define combinatorial dimensions, constraints, and the PICT/ACTS-style model. Run the PICT generator (`scripts/run_pict.py`) to produce the test matrix in `04d-combinatorial-test-matrix.md`. Test IDs use the `QA-COMB-` prefix.

### Step 4.3 — Produce state model and sequence tests (`04e`, `04f`)

Build the state model with allowed transitions, forbidden transitions, invalid events, retry, cancel, timeout, duplicate, and concurrency when relevant. Derive sequence tests and persist them in `04f-state-sequence-tests.md`. Test IDs use the `QA-SM-` prefix.

### Step 4.4 — Produce property-based invariants (`04g`)

Define invariants and input generators. Property tests MUST encode invariants — random input without invariant is not accepted. Test IDs use the `QA-PROP-` prefix.

### Step 4.5 — Produce API fuzz plan (`04h`)

If OpenAPI/GraphQL schema exists, plan Schemathesis-style fuzzing. If it cannot run, write the planned command and reason. Test IDs use the `QA-API-` prefix.

### Step 4.6 — Produce exploratory charter (`04i`)

Define exploratory charters for ambiguous or manual-experience areas. Test IDs use the `QA-EXP-` prefix.

### Step 4.7 — Produce regression test plan (`04j`)

For every known bug and every recently changed file in the scope, define a regression case. Test IDs use the `QA-REG-` prefix.

### Step 4.8 — Produce test data / fixture plan (`04k`)

Define fixtures, seed data, and the cleanup strategy. Cross-reference with `schemas/test-data-fixtures.schema.json` so the fixture manifest is machine-readable.

### Step 4.9 — Apply the per-risk depth matrix

For each P0/P1 risk, create a table:

| Risk ID | Example tests | Negative tests | Boundary/edge tests | State tests | Property tests | API/E2E tests | Gaps |
|---|---:|---:|---:|---:|---:|---:|---|

Minimum rules:

- P0: 1 happy, 2 negative, 2 boundary/edge, 1 recovery/error, plus state/property/API/E2E where applicable.
- P1: 1 main-path, 1 negative, 1 boundary/edge, plus applicable strategy coverage.

### Step 4.10 — Apply the required bug-class sweep

For every feature, explicitly mark `Applicable`, `Not applicable`, or `Gap` for:

- state transition
- validation
- boundary / off-by-one
- null / empty / missing field
- duplicate action / event / request
- timeout / retry / cancel
- concurrency / rapid repeat
- persistence mismatch
- stale / wrong UI state
- API contract mismatch
- error handling
- regression around changed files
- security / permission when relevant
- offline / online / network when relevant
- performance / large data when relevant

### Step 4.11 — Apply the per-test schema

Every test case MUST include:

```yaml
test_id:
title:
test_type:
risk_ids: []
requirement_ids: []
oracle_ids: []
preconditions: []
steps: []
input_data:
expected_result:
forbidden_result:
assertions: []
automation_target:
priority:
generated_from:
```

## Required inputs

- outputs from earlier phases — `00-qa-mission.md`, `01-context-map.md`, `02-risk-map.md`, `03-test-strategy.md`.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map is the input; oracle is not yet built.

## Required work (deliverables for this step)

- happy / negative / boundary / error / recovery / regression cases (`04a`)
- combinatorial dimensions and constraints (`04b`)
- PICT/ACTS-style model and generated matrix (`04c`, `04d`)
- state model and forbidden transitions (`04e`)
- sequence tests (`04f`)
- invariants and generators (`04g`)
- API fuzz plan (`04h`)
- exploratory charter (`04i`)
- regression cases (`04j`)
- test data / fixture plan (`04k`)
- per-risk depth matrix
- per-feature bug-class sweep

## Required output

`docs/qa/<scope>/04a-04k artifacts`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved — every test has `risk_ids` and references at least one risk
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- negative and boundary cases are present for critical behavior
- duplicate / timeout / retry / cancel cases are considered when relevant
- impossible combinations are constrained in the combinatorial matrix
- state models include forbidden transitions
- property tests include invariants, not just random examples

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## State writes

Update `qa-state.json`:

```json
{
  "current_step": "step-04-test-case-design",
  "phase_status": "test_case_design",
  "scope_artifacts": {
    "04a-example-test-cases.md": "written",
    "04b-combinatorial-dimensions.md": "written",
    "04c-pict-model.pict": "written",
    "04d-combinatorial-test-matrix.md": "written",
    "04e-state-model.md": "written",
    "04f-state-sequence-tests.md": "written",
    "04g-property-invariants.md": "written",
    "04h-api-fuzz-plan.md": "written",
    "04i-exploratory-charter.md": "written",
    "04j-regression-test-plan.md": "written",
    "04k-test-data-fixtures.md": "written"
  },
  "test_inventory": {
    "by_prefix": {
      "QA-EX-": <int>,
      "QA-COMB-": <int>,
      "QA-SM-": <int>,
      "QA-PROP-": <int>,
      "QA-API-": <int>,
      "QA-E2E-": <int>,
      "QA-REG-": <int>,
      "QA-EXP-": <int>
    },
    "total": <int>,
    "p0_risks_with_tests": ["<RISK-*>"],
    "p1_risks_with_tests": ["<RISK-*>"]
  }
}
```

## Hard stops

- Never generate executable tests before `05-test-oracle.md` exists (enforced in step 06 but the gate starts here).
- Never accept a test case that lacks `risk_ids`.
- Never accept a P0 risk with zero test IDs after this step.
- Never treat a combinatorial matrix as sufficient by itself — each row must be turned into an executable test or an explicit manual test intent.
- Never accept property tests that are random-only; they MUST encode invariants.
- Never accept a state model without forbidden transitions when the feature has states.

## Next step

Proceed to `step-05-test-oracle-design.md`. Only load that file when every `04a-04k` artifact is written and the exit criteria above are satisfied. Never load multiple step files simultaneously.
