# Model Behavior Contract

> **Deprecation Notice**: This document is maintained for reference only.
> The authoritative source is now `config/medium-model-guardrails.yaml` (v2.0.0).
> See Section 2 (Response Style) for the content previously in this file.

This contract is optimized for mid-tier coding models. The orchestrator must obey it exactly.

## Response style inside an agent run

Use deterministic sections. Do not free-form brainstorm unless a phase explicitly asks for ideation.

Required section order for each phase:

1. `Inputs Read`
2. `Decisions`
3. `Artifacts Written`
4. `Gaps / Ambiguities`
5. `Exit Criteria Check`
6. `Next Phase`

## Forbidden behavior

- Do not skip phases because the task feels simple.
- Do not write executable tests from memory or partial file snippets.
- Do not use generic placeholder test cases as final output.
- Do not mark a risk covered by a test that has no assertion tied to the risk.
- Do not silently drop a test strategy because a tool is unavailable.
- Do not treat generated mocks as proof of product correctness.
- Do not fix product code unless explicitly instructed by the user.

## Required traceability format

Each test case must include:

```yaml
test_id:
title:
test_type: example | combinatorial | state-machine | property | api-fuzz | e2e | regression | exploratory
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
priority: P0 | P1 | P2 | P3
generated_from: requirement | risk | state | invariant | api-contract | regression | exploratory
```

## Required evidence for bug reports

Every bug must include:

```yaml
bug_id:
severity: P0 | P1 | P2 | P3
type: PRODUCT_BUG | TEST_BUG | FLAKY_TEST | ENVIRONMENT_ISSUE | SPEC_AMBIGUITY | DATA_SETUP_ISSUE
failed_test_ids: []
reproduction_steps: []
expected:
actual:
evidence:
suspected_files: []
fix_hint:
regression_tests_to_keep: []
```

## Extended Bug Types (v2.0)

The following bug types are also supported:

- RACE_CONDITION, DEADLOCK_OR_LIVELOCK, DATA_RACE
- SECURITY_ISSUE, AUTHORIZATION_BYPASS, INPUT_VALIDATION_BYPASS
- MEMORY_LEAK, TIMING_ISSUE, STATE_CORRUPTION
- ATOMICITY_VIOLATION, ORDERING_VIOLATION, CONSISTENCY_ISSUE

## Reference to consolidated config

For machine-readable configuration and complete rules, see:
- `config/medium-model-guardrails.yaml` (v2.0.0) - authoritative configuration
- `STRICT_QA_RULES_FOR_MEDIUM_MODELS.md` - QA rules reference
- `config/quality-gates.yaml` - scoring and thresholds
