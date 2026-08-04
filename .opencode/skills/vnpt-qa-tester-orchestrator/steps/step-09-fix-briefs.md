# Step 09: Fix Brief Generation

**Goal:** Generate `bug-batches.json` and one fix brief per product bug for dev agents. A fix brief is a self-contained, actionable document — a dev agent MUST be able to act on it without re-reading the rest of the QA report.

## Prerequisites

- `08-failure-triage.md` exists with classified bugs and stable `QA-BUG-*` IDs.
- `bug-batches.json` exists and conforms to `schemas/bug-batches.schema.json`.
- `qa-state.json` `phase_status = "failure_triage"`.

## Sequence

### Step 9.1 — Identify briefs required

Apply the bug classification matrix from step-08. The following types require a fix brief:

- `PRODUCT_BUG`
- `RACE_CONDITION`
- `SECURITY_ISSUE`
- `DEADLOCK_OR_LIVELOCK`
- `MEMORY_LEAK`
- `STATE_CORRUPTION`
- `INPUT_VALIDATION_BYPASS`
- `AUTHORIZATION_BYPASS`
- `ATOMICITY_VIOLATION`
- `ORDERING_VIOLATION`
- `CONSISTENCY_ISSUE`
- `IDEMPOTENCY_VIOLATION`
- `DATA_RACE`

The following do NOT require a fix brief (forward to remediation owner instead):

- `TEST_BUG`
- `FLAKY_TEST`
- `ENVIRONMENT_ISSUE`
- `SPEC_AMBIGUITY`
- `DATA_SETUP_ISSUE`

### Step 9.2 — Generate one fix brief per required bug

For each `QA-BUG-*` that requires a brief, write `docs/qa/<scope>/09-fix-briefs/QA-BUG-XXX.md` (mirroring `templates/fix-brief.template.md`) with:

- summary
- severity
- failed test(s)
- risk mapping
- reproduction steps
- expected vs actual
- likely files
- implementation hints
- forbidden shortcuts
- acceptance criteria
- tests to rerun

### Step 9.3 — Apply the forbidden-shortcuts contract

Every fix brief MUST list forbidden shortcuts the dev agent cannot use to close the bug. Reuse the canonical anti-shortcut list:

- placeholder/mock/TODO-only code
- scope downgrade (e.g. "skip the failing case")
- silent spec change without `SPEC_AMBIGUITY` trace
- removal of assertions to make the test pass
- catch-all exception swallowers
- environment-only fixes (e.g. raising a timeout without addressing the cause)

### Step 9.4 — Update `bug-batches.json`

For each bug, add the field:

```json
{
  "fix_brief_ref": "docs/qa/<scope>/09-fix-briefs/QA-BUG-XXX.md"
}
```

Validate the resulting file against `schemas/bug-batches.schema.json`.

### Step 9.5 — Write `docs/qa/<scope>/09-fix-briefs/` index

Produce an `index.md` (or include the index inside `08-failure-triage.md` / `bug-batches.json`) listing every brief and its `QA-BUG-*`.

## Required inputs

- outputs from earlier phases — `08-failure-triage.md`, `bug-batches.json`.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map drives severity; oracle drives the reproduction.

## Required work (deliverables for this step)

- bug summary
- severity
- risk mapping
- failed tests
- expected vs actual
- suspected files
- fix hints
- forbidden shortcuts
- acceptance criteria
- tests to rerun

## Required output

- `docs/qa/<scope>/09-fix-briefs/QA-BUG-XXX.md` (one per required bug)
- `docs/qa/<scope>/bug-batches.json` (updated with `fix_brief_ref` per bug)

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved — every brief references `risk_ids`, `failed_test_ids`, `oracle_ids`
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- every `PRODUCT_BUG` has a fix brief
- each brief is actionable without re-reading the full QA report

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
  "current_step": "step-09-fix-briefs",
  "phase_status": "fix_briefs",
  "scope_artifacts": {
    "09-fix-briefs/": "written",
    "bug-batches.json": "updated"
  },
  "fix_brief_summary": {
    "briefs_required": <int>,
    "briefs_written": <int>,
    "bugs_without_brief": ["<QA-BUG-*>"]
  }
}
```

## Hard stops

- Never ship a fix brief that lacks `risk_ids`, `failed_test_ids`, or `oracle_ids`.
- Never ship a fix brief without forbidden-shortcuts.
- Never silently drop a brief because the bug looks trivial.
- Never produce a brief that depends on reading the rest of the QA report — each brief MUST be self-contained.

## Next step

Proceed to `step-10-quality-gate.md`. Only load that file when every required brief is written. Never load multiple step files simultaneously.
