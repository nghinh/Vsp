# Quality Gate Report: <feature>

| Gate | Weight | Score | Evidence | Result |
|---|---:|---:|---|---|
| Risk coverage | 20 |  |  |  |
| Requirement coverage | 15 |  |  |  |
| Negative/boundary coverage | 15 |  |  |  |
| State-transition coverage | 15 |  |  |  |
| Property/invariant coverage | 10 |  |  |  |
| API contract/fuzz coverage | 10 |  |  |  |
| E2E critical path coverage | 10 |  |  |  |
| Mutation quality | 5 |  |  |  |

## Hard fails

| Condition | Triggered? | Evidence |
|---|---|---|
| P0 risk without executable test |  |  |
| Missing test oracle |  |  |
| Failed tests untriaged |  |  |
| Only shallow tests |  |  |

## Result

PASS / CONDITIONAL PASS / FAIL

## Mandatory self-review for medium models

| Check | Pass/Fail | Evidence | Gap / Action |
|---|---|---|---|
| P0/P1 risks have executable tests or justified exceptions |  |  |  |
| Every executable test has ORACLE-* traceability |  |  |  |
| Negative and boundary tests exist for critical areas |  |  |  |
| State model covers forbidden transitions when applicable |  |  |  |
| Property/invariant tests exist for data/state logic |  |  |  |
| API fuzzing planned/run when schema exists |  |  |  |
| E2E tests assert business-visible state |  |  |  |
| Shallow tests excluded from score |  |  |  |
| Failures triaged |  |  |  |
