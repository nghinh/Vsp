# Step 07: Test Execution

**Goal:** Run feasible tests. Capture command, exit code, output, and text-based evidence. Every execution run MUST record enough evidence for step-08 to triage failures and step-10 to score coverage.

## Prerequisites

- `06-automation-map.md` exists with executable commands.
- Detected stack and runnable commands from `00-qa-mission.md` and step-06.
- `qa-state.json` `phase_status = "test_automation_generation"`.

## Sequence

### Step 7.1 — Apply the test-runner availability decision tree

From `config/medium-model-guardrails.yaml` Section 11:

- IF a test runner is available → run the exact command from the explicit_commands_required section.
- IF a test runner is NOT available → write `TOOL_GAP`, write the exact command as the fallback artifact, and do NOT silently skip.
- IF a test fails → capture the full stderr (text only, no screenshots), classify as `PRODUCT_BUG` or `TEST_BUG` in step-08, and proceed.

### Step 7.2 — Run feasible tests

Use the canonical commands from step-06 as starting points. Capture for each run:

- command (verbatim)
- exit code
- stdout summary (text only — NO screenshots or image captures)
- stderr summary (text only)
- coverage output (text report)
- log snippets for failures
- skipped reasons

Common commands:

```bash
npm test
npm run test:coverage
npx playwright test
schemathesis run openapi.yaml --base-url http://localhost:3000
npx stryker run
pytest
pytest --cov
mutmut run
```

### Step 7.3 — Capture evidence per run

For each test run, persist:

- run id
- command line
- exit code
- duration
- tests passed / failed / skipped counts
- coverage delta if available
- raw output snippets for any failure
- tool version (e.g. `pytest --version`, `npx playwright --version`)

### Step 7.4 — Handle blockers and gaps

For any test that cannot run, record the blocker with the canonical uncertainty label:

- `ENV_GAP` — service, port, or environment missing.
- `DATA_GAP` — fixture or seed missing.
- `TOOL_GAP` — optional tool unavailable.
- `JUSTIFIED_EXCEPTION` — coverage not feasible for documented reason.

Each blocker entry MUST include the exact planned command so step-10 can score it as `planned but not runnable`.

### Step 7.5 — Write `docs/qa/<scope>/07-test-execution-report.md`

The file MUST contain:

- per-run record with command, exit code, output, evidence
- aggregate counts (passed / failed / skipped / blocked)
- the failure evidence queue (forward pointer to step-08)
- the gap queue (forward pointer to step-10)

## Required inputs

- outputs from earlier phases — `06-automation-map.md` and the runnable commands.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — oracle is the assertion contract.

## Required work (deliverables for this step)

- command
- exit code
- stdout / stderr summary (text only — NO screenshots or image captures)
- coverage output (text report)
- log snippets for failures
- skipped reasons

## Required output

`docs/qa/<scope>/07-test-execution-report.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved — every failed test references its oracle
- P0/P1 risks are not silently skipped — every P0/P1 risk has a recorded execution attempt or `JUSTIFIED_EXCEPTION`
- assumptions and ambiguities are explicitly recorded
- every run records command and result
- failures have raw evidence
- skipped tests have reason

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`
- do not use `page.screenshot()` or any image-based evidence (M2.7 constraint)

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
  "current_step": "step-07-test-execution",
  "phase_status": "test_execution",
  "scope_artifacts": {
    "07-test-execution-report.md": "written"
  },
  "execution_summary": {
    "runs_total": <int>,
    "tests_passed": <int>,
    "tests_failed": <int>,
    "tests_skipped": <int>,
    "tests_blocked_env_gap": <int>,
    "tests_blocked_data_gap": <int>,
    "tests_blocked_tool_gap": <int>,
    "tests_blocked_justified_exception": <int>,
    "coverage_percent": <number | null>,
    "failure_evidence_count": <int>
  }
}
```

## Hard stops

- Never silently skip a runnable test; every skipped test MUST have a reason and a queued remediation.
- Never use `page.screenshot()` or any image-based evidence — use `page.textContent()` / `page.innerText()` for DOM snapshots.
- Never claim a run without recording the exact command, exit code, and at least one line of output.
- Never promote a flaky failure to a fixed status without re-running and observing stable pass.
- Never accept text-only output that does not name the failing test ID.

## Next step

Proceed to `step-08-failure-triage.md`. Only load that file when the execution report exit criteria above are satisfied. Never load multiple step files simultaneously.
