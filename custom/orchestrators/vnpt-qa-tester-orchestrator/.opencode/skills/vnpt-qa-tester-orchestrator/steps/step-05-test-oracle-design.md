# Step 05: Test Oracle Design

**Goal:** Define expected/forbidden behavior and assertion strategy for every test. The oracle is the single source of truth that makes every later test assertion defensible. No automation may reference an oracle ID that does not exist in this step's artifact.

## Prerequisites

- All `04a-04k` artifacts exist with stable test IDs and `risk_ids`.
- `qa-state.json` `phase_status = "test_case_design"`.

## Sequence

### Step 5.1 — Build the oracle catalog

For every test ID in the test inventory, define exactly one oracle (or one explicit `JUSTIFIED_EXCEPTION`). Each oracle gets a stable `ORACLE-*` ID.

Each `ORACLE-*` MUST include:

- source of truth: requirement/story/code contract/API spec/domain rule
- exact expected result
- exact forbidden result
- observable assertion
- state / database / event / UI / API side effect when relevant
- ambiguity label when the expected result cannot be proven

### Step 5.2 — Apply oracle strictness rules

Re-read every oracle and verify:

- the source of truth is concrete (file path + line, or requirement ID).
- the expected result is binary or measurable, never `should probably`.
- the forbidden result is symmetric to the expected result.
- the assertion is observable (text output, JSON field, HTTP status, exit code).
- the side effect is real (DB row, emitted event, persisted file, log line).
- the ambiguity label exists when expected behavior cannot be proven.

### Step 5.3 — Cross-reference tests and oracles

Build the cross-reference matrix:

| Test ID | Oracle IDs | Risk IDs | Source-of-truth path | Side effect paths | Ambiguity label |
|---|---|---|---|---|---|

If a test ID has no oracle, mark the test as `BLOCKED_ORACLE_GAP` and queue it for step-06 only after the gap is closed (or mark `JUSTIFIED_EXCEPTION`).

### Step 5.4 — Verify the oracle-first gate

Confirm:

- Every executable test in `04a-04k` has at least one oracle ID.
- No oracle ID appears in step-04 (oracles are introduced in this step).
- No oracle ID is referenced before it exists in `05-test-oracle.md`.
- The set of oracle IDs is finite and stable for the rest of the run.

### Step 5.5 — Write `docs/qa/<scope>/05-test-oracle.md`

The file MUST contain:

- the oracle catalog with `ORACLE-* | source of truth | expected | forbidden | side effects | assertions | ambiguity label`
- the cross-reference matrix
- a `BLOCKED_ORACLE_GAP` list with concrete remediation
- a forward pointer to step-06-test-automation-generation

## Required inputs

- outputs from earlier phases — all `04a-04k` artifacts.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — the oracle map produced here becomes the current.

## Required work (deliverables for this step)

- oracle source per test
- preconditions
- input / events
- expected output
- forbidden output
- state / DB side effects
- UI / API assertions
- ambiguity notes

## Required output

`docs/qa/<scope>/05-test-oracle.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped — every P0/P1 risk has oracles
- assumptions and ambiguities are explicitly recorded

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
  "current_step": "step-05-test-oracle-design",
  "phase_status": "test_oracle_design",
  "scope_artifacts": {
    "05-test-oracle.md": "written"
  },
  "oracle_summary": {
    "total_oracles": <int>,
    "tests_with_oracle": <int>,
    "tests_with_oracle_gap": <int>,
    "justified_exceptions": <int>
  }
}
```

## Hard stops

- Never proceed to step 06 when any executable test lacks an oracle.
- Never reference an oracle ID that does not exist in `05-test-oracle.md` from step-06 or later.
- Never accept an oracle whose expected result is "should probably" or "should usually" — it MUST be binary or measurable.
- Never accept a forbidden result that is not symmetric to the expected result.
- Never accept a `BLOCKED_ORACLE_GAP` silently; it MUST be visible in `05-test-oracle.md` and propagate to step-08 triage.

## Next step

Proceed to `step-06-test-automation-generation.md`. Only load that file when the oracle exit criteria above are satisfied. Never load multiple step files simultaneously.
