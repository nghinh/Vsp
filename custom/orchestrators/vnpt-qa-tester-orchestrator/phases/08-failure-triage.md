# Phase: 08-failure-triage

## Purpose

Classify failures into appropriate categories. Use the extended bug type taxonomy (v2.0) for nuanced classification.

## Required Bug Types

### Core Types
- **PRODUCT_BUG**: Confirmed defect in product code
- **TEST_BUG**: Test itself is incorrect
- **FLAKY_TEST**: Test is non-deterministic
- **ENVIRONMENT_ISSUE**: Test environment problem
- **SPEC_AMBIGUITY**: Requirement is unclear
- **DATA_SETUP_ISSUE**: Test data problem

### Extended Types (v2.0)
- **RACE_CONDITION**: Concurrent operations produce wrong result due to timing
- **SECURITY_ISSUE**: Security vulnerability or permission boundary violation
- **DEADLOCK_OR_LIVELOCK**: Process stuck in deadlock or livelock
- **MEMORY_LEAK**: Memory or resource not properly released
- **TIMING_ISSUE**: Race between operations causing inconsistent state
- **DATA_RACE**: Simultaneous access to shared data without synchronization
- **ATOMICITY_VIOLATION**: Operation that should be atomic is not
- **ORDERING_VIOLATION**: Operations executed in wrong order
- **CONSISTENCY_ISSUE**: Data or state inconsistent between operations
- **IDEMPOTENCY_VIOLATION**: Repeated operation produces different result
- **AUTHORIZATION_BYPASS**: User can perform actions without authorization
- **INPUT_VALIDATION_BYPASS**: Invalid input not validated before processing
- **STATE_CORRUPTION**: System reaches invalid or corrupt state

## Required inputs

- outputs from all earlier phases
- relevant project files read from 0-EOF
- current risk map and oracle where applicable
- bug-batches.schema.json (v2.0 extended types)

## Required work

- failed test
- failure type (use extended types when applicable)
- evidence
- root cause hypothesis
- reproduction
- severity
- next action

## Required output

`docs/qa/<feature>/08-failure-triage.md`

## Bug Classification Matrix

| Bug Type | Requires Fix? | Requires Fix Brief? | Priority |
|----------|--------------|-------------------|----------|
| PRODUCT_BUG | Yes | Yes | Based on severity |
| RACE_CONDITION | Yes | Yes | P0/P1 |
| SECURITY_ISSUE | Yes | Yes | P0 |
| DEADLOCK_OR_LIVELOCK | Yes | Yes | P0/P1 |
| MEMORY_LEAK | Yes | Yes | P1/P2 |
| STATE_CORRUPTION | Yes | Yes | P0/P1 |
| TEST_BUG | Fix test | No | P3 |
| FLAKY_TEST | Stabilize test | No | P2 |
| ENVIRONMENT_ISSUE | Fix env | No | Depends |
| SPEC_AMBIGUITY | Clarify spec | No | Depends |
| DATA_SETUP_ISSUE | Fix data | No | P2 |

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- bug-batches.json created with all PRODUCT_BUGs and extended types
- 09-fix-briefs/ directory populated for PRODUCT_BUG, RACE_CONDITION, SECURITY_ISSUE, etc.

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark SPEC_AMBIGUITY
- do not classify concurrency bugs as FLAKY_TEST; they are RACE_CONDITION or DATA_RACE
- do not classify security issues as TEST_BUG; they are SECURITY_ISSUE or AUTHORIZATION_BYPASS

## Medium-model strict checklist

Before leaving this phase, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.
- Use extended bug types for concurrency, security, and state corruption bugs.