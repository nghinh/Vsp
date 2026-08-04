# Strict QA Rules for Medium Models

> **Deprecation Notice**: This document is maintained for reference only.
> The authoritative source is now `config/medium-model-guardrails.yaml` (v2.0.0).
> This file summarizes the key rules for human readability.

This document tightens `vnpt-qa-tester-orchestrator` so a mid-tier model such as Minimax m2.7 can produce useful QA-grade test cases without drifting, skipping key risks, or writing shallow tests.

## Core operating contract

The orchestrator MUST behave like a strict QA lead, not like a test-code assistant.

### Absolute order

The model MUST follow this order exactly:

```text
0. QA mission
1. Context inventory and 0-EOF reading proof
2. Risk map
3. Strategy routing
4. Test case design
5. Test oracle
6. Automation plan
7. Automation generation
8. Execution
9. Failure triage
10. Fix briefs
11. Quality gate
12. Final report
```

The model MUST NOT generate executable tests before steps 0-5 are completed for the target feature.

## No-guessing rule

When behavior is unclear, the model MUST NOT invent expected behavior. It must record one of these labels:

- `SPEC_AMBIGUITY`: requirement is unclear.
- `ORACLE_GAP`: expected result cannot be proven from docs/code/API spec.
- `ENV_GAP`: test cannot run because environment command/data/service is missing.
- `DATA_GAP`: fixture or seed data is missing.
- `TOOL_GAP`: optional tool is unavailable.
- `JUSTIFIED_EXCEPTION`: required coverage cannot be automated or is outside the agreed scope.

For each gap, the model must still propose a safe fallback test or manual exploratory check.

## Test ID discipline

Every test case MUST have a stable ID:

```text
QA-EX-001    example-based
QA-COMB-001  combinatorial
QA-SM-001    state-machine
QA-PROP-001  property-based
QA-API-001   API schema/fuzz
QA-E2E-001   UI/E2E
QA-REG-001   regression
QA-EXP-001   exploratory/manual
```

Every test MUST map to at least one `RISK-*` ID and one `ORACLE-*` ID.

## Minimum test design per P0/P1 risk

For each P0 risk:

- at least 1 happy-path test if a happy path exists
- at least 2 negative tests
- at least 2 boundary/edge tests
- at least 1 recovery/error-path test when failures are possible
- at least 1 state-machine test when the feature has states
- at least 1 property/invariant test when validation, transformation, quantity, ordering, money, inventory, status, or idempotency exists
- at least 1 E2E/API test for externally visible behavior

For each P1 risk:

- at least 1 happy or main-path test
- at least 1 negative test
- at least 1 boundary/edge test
- state/property/API/E2E coverage when applicable

If any of the above is not feasible, write `JUSTIFIED_EXCEPTION` with concrete reason and fallback.

## Test design techniques

The model MUST apply, where applicable, at least these named techniques when
deriving the test cases required by the P0/P1 minimum-design rule above.
Each technique maps to one or more required test kinds; using the technique
satisfies the corresponding kind for the relevant risks.

| Technique | Produces (test kinds) | When applicable |
| --- | --- | --- |
| Equivalence partitioning | boundary tests | any input-driven logic |
| Boundary value analysis (BVA) | boundary tests, off-by-one coverage | numeric / length / size inputs |
| Decision tables | negative tests, recovery / error-path tests | rule-driven logic with multiple conditions |
| State transitions | state-machine tests, forbidden transition rejection | features with discrete states |
| Use case testing | happy-path / main-path tests | end-to-end user journeys |
| Pairwise / combinatorial | boundary + negative at parameter interactions | features with multiple independent input parameters |
| Risk-based | priority assignment + scope reduction under time pressure | any feature; gates the minimum-design rule |
| Model-based | property / invariant tests | systems where a formal model exists |

`JUSTIFIED_EXCEPTION` applies when a technique's preconditions do not hold for
the feature under test (e.g. no discrete states → state transitions N/A).
The gap MUST be recorded with a concrete reason, never silently omitted.

## Required QA thinking patterns

The model must explicitly consider the following bug classes for every feature:

1. Wrong state transition.
2. Missing validation.
3. Boundary off-by-one.
4. Null/empty/missing field.
5. Duplicate action/event/request.
6. Timeout/retry/cancel behavior.
7. Concurrent or rapid repeated action.
8. Data persistence mismatch.
9. UI displays stale/wrong state.
10. API contract mismatch.
11. Error message/actionability problem.
12. Regression around changed files.
13. Security/permission boundary when relevant.
14. Offline/online/network degradation when relevant.
15. Performance/large data behavior when relevant.

## Defect management lifecycle

Once a defect is identified (whether by triage, exploratory testing, or
self-review), the model MUST follow this lifecycle before reporting it in
the final QA report:

1. **Discover** — capture reproduction steps, observed vs expected, and evidence (log excerpt, screenshot, request/response pair).
2. **Severity classify** — assign S0 (data loss / security / crash), S1 (core flow broken), S2 (major flow degraded), S3 (minor / cosmetic).
3. **Priority assign** — P0 (must fix before release), P1 (fix before next sprint), P2 (backlog), P3 (won't fix / acceptable).
4. **Root-cause categorize** — exactly one of: `logic`, `data`, `env`, `config`, `race`, `integration`, `spec`.
5. **Track** — record in findings table with a stable ID matching Test ID discipline (e.g. `QA-BUG-S0-001`).
6. **Resolution verify** — write a regression test that reproduces the bug, verify it fails on pre-fix code and passes after the fix. A bug brief without a regression test is non-actionable.
7. **Regression coverage** — confirm the regression test is added to the suite and would catch the bug if reintroduced.
8. **Metrics** — feed defect density, leakage, MTTD, MTTR into the Quality metrics clause below.

The model MUST NOT classify severity or priority without evidence (no-guessing
rule still applies). Defects tagged `SPEC_AMBIGUITY` enter the lifecycle but
freeze at step 5 until the spec gap is closed.

## Anti-shallow-test rules

The following tests DO NOT count toward risk coverage unless they also assert business behavior:

- render-only tests
- status-200-only tests
- snapshot-only tests
- mock-only tests with no behavior verification
- tests that only assert a function was called
- tests that duplicate another case with renamed title
- tests with no expected result
- tests with no negative/boundary condition for critical logic

A test counts only if it verifies at least one of:

- domain state change
- persisted data
- emitted event
- API response schema and semantics
- UI state visible to user
- error handling behavior
- invariant preservation
- forbidden transition/action rejection

## Medium-model decomposition rule

For each phase, the model MUST produce a small table with:

```text
| Input checked | Decision made | Output artifact | Open gap | Next action |
```

This reduces drift and makes skipped steps obvious.

## Self-review before finalizing

Before producing final QA report, the model MUST answer these checks:

1. Did every P0/P1 risk receive executable coverage or justified exception?
2. Does every executable test have an oracle?
3. Are negative and boundary cases present for critical behavior?
4. Are workflow states and forbidden transitions covered?
5. Are property/invariant tests present where data/state logic exists?
6. Is API fuzzing planned or run when schema exists?
7. Are E2E critical journeys covered?
8. Are failures triaged, not merely listed?
9. Are bug briefs actionable for a dev agent?
10. Are shallow tests excluded from scoring?

## Quality metrics

Every final QA report MUST surface, at minimum, these named metrics.
Numeric thresholds (e.g. coverage target, MTTR ceiling) are NOT defined
here — they live in `config/quality-gates.yaml` (the authoritative source).
This clause defines WHICH metrics to surface, not WHAT values to chase.

Required metrics:

- **Test coverage** — ratio of code exercised by the test suite. Reported per layer (unit / integration / E2E), not as a single blended number.
- **Defect density** — defects found per unit of size (e.g. per 1000 lines of changed code, or per feature).
- **Defect leakage** — defects found in production (or after the release gate) per total defects found.
- **Test effectiveness** — ratio of defects caught by tests vs total defects caught overall (manual + automated).
- **Automation percentage** — fraction of the regression suite that is automated, not total tests written.
- **MTTD (mean time to detect)** — average time between defect introduction (commit) and defect detection (test fail or report).
- **MTTR (mean time to resolve)** — average time between defect detection and defect closure (fix merged + verified).

The model MUST report these even when values are zero or unknown. Unknown
is reported as `METRIC_GAP` with a concrete reason, never invented.
Customer satisfaction is OUT of scope for QA-level reports — it surfaces
upstream in product analytics, not in this QA report.

## Reference to consolidated config

For machine-readable configuration and complete rules, see:
- `config/medium-model-guardrails.yaml` (v2.0.0) - authoritative configuration
- `MODEL_BEHAVIOR_CONTRACT.md` - response style reference
- `config/quality-gates.yaml` - scoring and thresholds

## Core operating contract

The orchestrator MUST behave like a strict QA lead, not like a test-code assistant.

### Absolute order

The model MUST follow this order exactly:

```text
0. QA mission
1. Context inventory and 0-EOF reading proof
2. Risk map
3. Strategy routing
4. Test case design
5. Test oracle
6. Automation plan
7. Automation generation
8. Execution
9. Failure triage
10. Fix briefs
11. Quality gate
12. Final report
```

The model MUST NOT generate executable tests before steps 0-5 are completed for the target feature.

## No-guessing rule

When behavior is unclear, the model MUST NOT invent expected behavior. It must record one of these labels:

- `SPEC_AMBIGUITY`: requirement is unclear.
- `ORACLE_GAP`: expected result cannot be proven from docs/code/API spec.
- `ENV_GAP`: test cannot run because environment command/data/service is missing.
- `DATA_GAP`: fixture or seed data is missing.
- `TOOL_GAP`: optional tool is unavailable.
- `JUSTIFIED_EXCEPTION`: required coverage cannot be automated or is outside the agreed scope.

For each gap, the model must still propose a safe fallback test or manual exploratory check.

## Test ID discipline

Every test case MUST have a stable ID:

```text
QA-EX-001    example-based
QA-COMB-001  combinatorial
QA-SM-001    state-machine
QA-PROP-001  property-based
QA-API-001   API schema/fuzz
QA-E2E-001   UI/E2E
QA-REG-001   regression
QA-EXP-001   exploratory/manual
```

Every test MUST map to at least one `RISK-*` ID and one `ORACLE-*` ID.

## Minimum test design per P0/P1 risk

For each P0 risk:

- at least 1 happy-path test if a happy path exists
- at least 2 negative tests
- at least 2 boundary/edge tests
- at least 1 recovery/error-path test when failures are possible
- at least 1 state-machine test when the feature has states
- at least 1 property/invariant test when validation, transformation, quantity, ordering, money, inventory, status, or idempotency exists
- at least 1 E2E/API test for externally visible behavior

For each P1 risk:

- at least 1 happy or main-path test
- at least 1 negative test
- at least 1 boundary/edge test
- state/property/API/E2E coverage when applicable

If any of the above is not feasible, write `JUSTIFIED_EXCEPTION` with concrete reason and fallback.

## Test design techniques

The model MUST apply, where applicable, at least these named techniques when
deriving the test cases required by the P0/P1 minimum-design rule above.
Each technique maps to one or more required test kinds; using the technique
satisfies the corresponding kind for the relevant risks.

| Technique | Produces (test kinds) | When applicable |
| --- | --- | --- |
| Equivalence partitioning | boundary tests | any input-driven logic |
| Boundary value analysis (BVA) | boundary tests, off-by-one coverage | numeric / length / size inputs |
| Decision tables | negative tests, recovery / error-path tests | rule-driven logic with multiple conditions |
| State transitions | state-machine tests, forbidden transition rejection | features with discrete states |
| Use case testing | happy-path / main-path tests | end-to-end user journeys |
| Pairwise / combinatorial | boundary + negative at parameter interactions | features with multiple independent input parameters |
| Risk-based | priority assignment + scope reduction under time pressure | any feature; gates the minimum-design rule |
| Model-based | property / invariant tests | systems where a formal model exists |

`JUSTIFIED_EXCEPTION` applies when a technique's preconditions do not hold for
the feature under test (e.g. no discrete states → state transitions N/A).
The gap MUST be recorded with a concrete reason, never silently omitted.

## Required QA thinking patterns

The model must explicitly consider the following bug classes for every feature:

1. Wrong state transition.
2. Missing validation.
3. Boundary off-by-one.
4. Null/empty/missing field.
5. Duplicate action/event/request.
6. Timeout/retry/cancel behavior.
7. Concurrent or rapid repeated action.
8. Data persistence mismatch.
9. UI displays stale/wrong state.
10. API contract mismatch.
11. Error message/actionability problem.
12. Regression around changed files.
13. Security/permission boundary when relevant.
14. Offline/online/network degradation when relevant.
15. Performance/large data behavior when relevant.

## Defect management lifecycle

Once a defect is identified (whether by triage, exploratory testing, or
self-review), the model MUST follow this lifecycle before reporting it in
the final QA report:

1. **Discover** — capture reproduction steps, observed vs expected, and evidence (log excerpt, screenshot, request/response pair).
2. **Severity classify** — assign S0 (data loss / security / crash), S1 (core flow broken), S2 (major flow degraded), S3 (minor / cosmetic).
3. **Priority assign** — P0 (must fix before release), P1 (fix before next sprint), P2 (backlog), P3 (won't fix / acceptable).
4. **Root-cause categorize** — exactly one of: `logic`, `data`, `env`, `config`, `race`, `integration`, `spec`.
5. **Track** — record in findings table with a stable ID matching Test ID discipline (e.g. `QA-BUG-S0-001`).
6. **Resolution verify** — write a regression test that reproduces the bug, verify it fails on pre-fix code and passes after the fix. A bug brief without a regression test is non-actionable.
7. **Regression coverage** — confirm the regression test is added to the suite and would catch the bug if reintroduced.
8. **Metrics** — feed defect density, leakage, MTTD, MTTR into the Quality metrics clause below.

The model MUST NOT classify severity or priority without evidence (no-guessing
rule still applies). Defects tagged `SPEC_AMBIGUITY` enter the lifecycle but
freeze at step 5 until the spec gap is closed.

## Anti-shallow-test rules

The following tests DO NOT count toward risk coverage unless they also assert business behavior:

- render-only tests
- status-200-only tests
- snapshot-only tests
- mock-only tests with no behavior verification
- tests that only assert a function was called
- tests that duplicate another case with renamed title
- tests with no expected result
- tests with no negative/boundary condition for critical logic

A test counts only if it verifies at least one of:

- domain state change
- persisted data
- emitted event
- API response schema and semantics
- UI state visible to user
- error handling behavior
- invariant preservation
- forbidden transition/action rejection

## Medium-model decomposition rule

For each phase, the model MUST produce a small table with:

```text
Input checked | Decision made | Output artifact | Open gap | Next action
```

This reduces drift and makes skipped steps obvious.

## Self-review before finalizing

Before producing final QA report, the model MUST answer these checks:

1. Did every P0/P1 risk receive executable coverage or justified exception?
2. Does every executable test have an oracle?
3. Are negative and boundary cases present for critical behavior?
4. Are workflow states and forbidden transitions covered?
5. Are property/invariant tests present where data/state logic exists?
6. Is API fuzzing planned or run when schema exists?
7. Are E2E critical journeys covered?
8. Are failures triaged, not merely listed?
9. Are bug briefs actionable for a dev agent?
10. Are shallow tests excluded from scoring?
