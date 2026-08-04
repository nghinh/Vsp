# Step 11: Final QA Report

**Goal:** Produce the final QA summary: scope tested, artifacts generated, test execution results, bugs found, fix briefs, gate result, remaining risks, release recommendation. This step closes the run and is the document the user / release manager reads to make a ship decision.

## Prerequisites

- All `00-10` artifacts exist with stable IDs.
- `10-quality-gate-report.json` is valid and reflects the actual run.
- `bug-batches.json` is finalized.
- `qa-state.json` `phase_status = "quality_gate"`.

## Sequence

### Step 11.1 — Compose the final report

Mirror the structure of `templates/final-qa-report.template.md`:

- scope tested
- artifacts generated
- test execution results
- bugs found
- fix briefs
- gate result
- remaining risks
- release recommendation

### Step 11.2 — Apply the self-review checklist (mandatory)

Before finalizing, the model MUST answer these checks:

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

Embed the answers inline in the final report. Never skip this block.

### Step 11.3 — State the release recommendation

Apply the gate-result → release-recendation mapping:

| Gate result | Release recommendation |
|---|---|
| pass | GO — shippable. Residual risks listed in `remaining-risks` section. |
| conditional_pass | CONDITIONAL GO — shippable only with explicit acceptance of the listed residual risks and unresolved items. |
| fail | NO-GO — fix briefs must close the hard-fail items before the next gate run. |

### Step 11.4 — Write the residual-risk register

For every risk that is partially covered, deferred, or `JUSTIFIED_EXCEPTION`, emit:

- risk id
- current coverage
- residual likelihood × impact
- explicit accept-by owner (if known)
- follow-up date (if known)

### Step 11.5 — Write `docs/qa/<scope>/11-final-qa-report.md`

The file MUST contain all of step 11.1–11.4 above plus the forward closing block:

```text
**QA Run Complete**

Scope: <scope>
Gate: <pass | conditional_pass | fail>
Bugs: <count>
Fix briefs: <count>
Residual risks: <count>
Artifacts: docs/qa/<scope>/

Next command for dev/fix agent: <command or "no bugs — proceed with release">
```

### Step 11.6 — Mark run complete

Update `qa-state.json` `phase_status = "done"`. The orchestrator run is complete only when the **Completion definition** in `ORCHESTRATOR.md` is satisfied:

1. all required artifacts exist;
2. P0/P1 risks have executable coverage or justified exception;
3. every test has oracle;
4. runnable tests have been executed when environment allows;
5. failures have been triaged;
6. product bugs have fix briefs;
7. quality gate is pass or explicit conditional/fail with reasons;
8. final QA report exists.

## Required inputs

- outputs from earlier phases — all `00-10` artifacts.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map drives the residual-risk register.

## Required work (deliverables for this step)

- scope
- artifacts
- test results
- bugs found
- fix briefs
- gate result
- remaining risks
- release recommendation

## Required output

`docs/qa/<scope>/11-final-qa-report.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- the self-review checklist is answered inline
- the release recommendation is explicit (GO / CONDITIONAL GO / NO-GO)
- the residual-risk register is non-empty when the gate is not `pass`

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
  "current_step": "step-11-final-qa-report",
  "phase_status": "done",
  "scope_artifacts": {
    "11-final-qa-report.md": "written"
  },
  "completion": {
    "all_artifacts_present": true,
    "p0_p1_risks_covered_or_justified": true,
    "every_test_has_oracle": true,
    "tests_executed_when_feasible": true,
    "failures_triaged": true,
    "product_bugs_have_fix_briefs": true,
    "gate_pass_or_explicit": true,
    "final_report_exists": true,
    "release_recommendation": "GO | CONDITIONAL_GO | NO_GO"
  },
  "residual_risks_count": <int>
}
```

## Hard stops

- Never claim run completion when any item in the **Completion definition** is false.
- Never ship a final report without the self-review checklist answered inline.
- Never ship a final report without an explicit release recommendation (GO / CONDITIONAL GO / NO-GO).
- Never hide residual risks; the residual-risk register MUST be populated when the gate is not `pass`.
- Never mark `phase_status = "done"` when the gate is `fail` and the user has not authorized an exception.

## Next step

This is the terminal step. The orchestrator run is complete. Return the closing summary from step 11.5 to the user.
