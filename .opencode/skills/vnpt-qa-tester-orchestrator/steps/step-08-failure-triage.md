# Step 08: Failure Triage

**Goal:** Classify every failure into the canonical bug-type taxonomy (core + v2.0 extended), assign a stable `QA-BUG-*` ID, and produce evidence-grade entries that step-09 turns into fix briefs.

## Prerequisites

- `07-test-execution-report.md` exists with raw failure evidence.
- `qa-state.json` `phase_status = "test_execution"`.

## Sequence

### Step 8.1 — Apply the core bug-type taxonomy

Use the canonical six core types when classifying:

- `PRODUCT_BUG` — Confirmed defect in product code.
- `TEST_BUG` — Test itself is incorrect.
- `FLAKY_TEST` — Test is non-deterministic.
- `ENVIRONMENT_ISSUE` — Test environment problem.
- `SPEC_AMBIGUITY` — Requirement is unclear.
- `DATA_SETUP_ISSUE` — Test data problem.

### Step 8.2 — Apply the v2.0 extended bug-type taxonomy

When the failure signature matches one of the extended types, prefer the more specific classification:

- `RACE_CONDITION` — Concurrent operations produce wrong result due to timing.
- `SECURITY_ISSUE` — Security vulnerability or permission boundary violation.
- `DEADLOCK_OR_LIVELOCK` — Process stuck in deadlock or livelock.
- `MEMORY_LEAK` — Memory or resource not properly released.
- `TIMING_ISSUE` — Race between operations causing inconsistent state.
- `DATA_RACE` — Simultaneous access to shared data without synchronization.
- `ATOMICITY_VIOLATION` — Operation that should be atomic is not.
- `ORDERING_VIOLATION` — Operations executed in wrong order.
- `CONSISTENCY_ISSUE` — Data or state inconsistent between operations.
- `IDEMPOTENCY_VIOLATION` — Repeated operation produces different result.
- `AUTHORIZATION_BYPASS` — User can perform actions without authorization.
- `INPUT_VALIDATION_BYPASS` — Invalid input not validated before processing.
- `STATE_CORRUPTION` — System reaches invalid or corrupt state.

### Step 8.3 — Apply the bug classification matrix

| Bug Type | Requires Fix? | Requires Fix Brief? | Priority |
|---|---|---|---|
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

### Step 8.4 — Build the bug-class sweep gate

For every classification:

- IF the failure is concurrency-related, never classify as `FLAKY_TEST` — use `RACE_CONDITION` or `DATA_RACE`.
- IF the failure is security-related, never classify as `TEST_BUG` — use `SECURITY_ISSUE` or `AUTHORIZATION_BYPASS`.
- IF the failure involves invalid input reaching production logic, classify as `INPUT_VALIDATION_BYPASS` rather than `PRODUCT_BUG` when the validation gap is the root cause.
- IF the failure is repeated-execution divergence, classify as `IDEMPOTENCY_VIOLATION`.
- IF the failure is timing-based non-determinism not yet pinned to a race, classify as `TIMING_ISSUE`.

### Step 8.5 — Generate `bug-batches.json`

For each product-bug-classified failure, emit a JSON entry that conforms to `schemas/bug-batches.schema.json`:

```yaml
bug_id:
severity: P0 | P1 | P2 | P3
type: PRODUCT_BUG | TEST_BUG | FLAKY_TEST | ENVIRONMENT_ISSUE | SPEC_AMBIGUITY | DATA_SETUP_ISSUE
# OR extended types: RACE_CONDITION | SECURITY_ISSUE | DEADLOCK_OR_LIVELOCK | MEMORY_LEAK | ...
failed_test_ids: []
reproduction_steps: []
expected:
actual:
evidence:
suspected_files: []
fix_hint:
regression_tests_to_keep: []
```

### Step 8.6 — Write `docs/qa/<scope>/08-failure-triage.md`

The file MUST contain:

- per-failure entry with classification, severity, evidence, suspected files, next action
- the bug classification matrix application
- forward pointers to step-09 (fix briefs) and step-10 (quality gate)
- the `bug-batches.json` index (without inline duplication)

## Required inputs

- outputs from earlier phases — `07-test-execution-report.md` raw evidence.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map + oracle together drive severity.
- `bug-batches.schema.json` (v2.0 extended types).

## Required work (deliverables for this step)

- failed test
- failure type (use extended types when applicable)
- evidence
- root cause hypothesis
- reproduction
- severity
- next action

## Required output

- `docs/qa/<scope>/08-failure-triage.md`
- `docs/qa/<scope>/bug-batches.json` (index of `QA-BUG-*` with severity, type, fix-brief path)

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved — every `QA-BUG-*` references `failed_test_ids` and risk IDs
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- bug-batches.json created with all PRODUCT_BUGs and extended types
- `09-fix-briefs/` directory populated for PRODUCT_BUG, RACE_CONDITION, SECURITY_ISSUE, etc.

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`
- do not classify concurrency bugs as `FLAKY_TEST`; they are `RACE_CONDITION` or `DATA_RACE`
- do not classify security issues as `TEST_BUG`; they are `SECURITY_ISSUE` or `AUTHORIZATION_BYPASS`

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.
- Use extended bug types for concurrency, security, and state corruption bugs.

## State writes

Update `qa-state.json`:

```json
{
  "current_step": "step-08-failure-triage",
  "phase_status": "failure_triage",
  "scope_artifacts": {
    "08-failure-triage.md": "written",
    "bug-batches.json": "written"
  },
  "triage_summary": {
    "failures_total": <int>,
    "product_bug_count": <int>,
    "test_bug_count": <int>,
    "flaky_test_count": <int>,
    "environment_issue_count": <int>,
    "spec_ambiguity_count": <int>,
    "data_setup_issue_count": <int>,
    "extended_type_counts": {
      "race_condition": <int>,
      "deadlock_or_livelock": <int>,
      "data_race": <int>,
      "atomicity_violation": <int>,
      "ordering_violation": <int>,
      "memory_leak": <int>,
      "authorization_bypass": <int>,
      "input_validation_bypass": <int>,
      "state_corruption": <int>,
      "idempotency_violation": <int>,
      "security_issue": <int>,
      "timing_issue": <int>,
      "consistency_issue": <int>
    }
  }
}
```

## Hard stops

- Never classify a concurrency failure as `FLAKY_TEST`.
- Never classify a security failure as `TEST_BUG`.
- Never accept a `PRODUCT_BUG` without a stable `QA-BUG-*` ID and a forward reference to a fix brief.
- Never merge two distinct bugs into one entry; each gets its own `QA-BUG-*`.
- Never claim a failure is untriaged; every failure MUST have one classification and one next action.

## Next step

Proceed to `step-09-fix-brief-generation.md`. Only load that file when every `PRODUCT_BUG` (and extended types that require fix briefs) is queued for a fix brief. Never load multiple step files simultaneously.
