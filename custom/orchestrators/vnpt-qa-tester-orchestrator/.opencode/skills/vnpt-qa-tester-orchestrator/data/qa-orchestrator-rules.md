# QA Orchestrator Rules (Hard Stops and Non-negotiables)

## Hard Stops (NEVER violate)

1. **Never generate risk map, test cases, test oracle, or automation before `00-qa-mission.md` exists.**
2. **Never generate risk map, test cases, test oracle, or automation before the BMAD docs hard gate is satisfied** (`BMAD_DOCS_RECURSIVE_SCAN_DONE = true`, `BMAD_DOCS_SCAN_DONE = true`, `BMAD_RELEVANT_DOCS_READ_0_EOF = true` OR documented `JUSTIFIED_EXCEPTION`).
3. **Never write executable tests before `05-test-oracle.md` exists.**
4. **Never classify a concurrency failure as `FLAKY_TEST`.** It is `RACE_CONDITION` or `DATA_RACE`.
5. **Never classify a security failure as `TEST_BUG`.** It is `SECURITY_ISSUE` or `AUTHORIZATION_BYPASS`.
6. **Never accept an oracle whose expected result is "should probably" or "should usually".** It MUST be binary or measurable.
7. **Never accept a forbidden result that is not symmetric to the expected result.**
8. **Never use `page.screenshot()` or any image-based evidence.** The model is text-only; all visual evidence MUST use `page.textContent()` / `page.innerText()` or `TOOL_GAP`.
9. **Never silently skip a strategy because a tool is unavailable.** Write `TOOL_GAP` with the exact planned command.
10. **Never silently skip a runnable test.** Every skipped test MUST have a reason and a queued remediation.
11. **Never accept a shallow test as coverage.** Render-only, status-200-only, snapshot-only, mock-only-without-behavior-verification, and renamed-duplicate tests do not count.
12. **Never accept a property-based test that is random-only.** It MUST encode invariants.
13. **Never accept a state model without forbidden transitions when the feature has states.**
14. **Never accept a combinatorial matrix row that is not turned into an executable test or an explicit manual test intent.**
15. **Never ship a fix brief that lacks `risk_ids`, `failed_test_ids`, or `oracle_ids`.**
16. **Never ship a fix brief without forbidden-shortcuts.**
17. **Never ship a fix brief that depends on reading the rest of the QA report — each brief MUST be self-contained.**
18. **Never accept a `pass` gate result when any hard-fail rule fires.**
19. **Never accept a `pass` gate result when any P0 risk has no executable test or `JUSTIFIED_EXCEPTION`.**
20. **Never ship a JSON gate report that does not validate against `gate_report_json_schema` in `config/medium-model-guardrails.yaml` Section 11.**
21. **Never claim run completion when any item in the **Completion definition** is false.**
22. **Never ship a final report without the self-review checklist answered inline.**
23. **Never ship a final report without an explicit release recommendation (GO / CONDITIONAL GO / NO-GO).**
24. **Never hide residual risks.** The residual-risk register MUST be populated when the gate is not `pass`.
25. **Never mark `phase_status = "done"` when the gate is `fail` and the user has not authorized an exception.**

## Phase ordering (NON-NEGOTIABLE)

```text
0.  mission_setup
1.  context_reading
2.  risk_modeling
3.  test_strategy_planning
4.  test_case_design
5.  test_oracle_design
6.  test_automation_generation
7.  test_execution
8.  failure_triage
9.  fix_briefs
10. quality_gate
11. final_qa_report
```

The orchestrator MUST NOT skip, reorder, or merge phases. The model MUST NOT generate executable tests before phases 0–5 are completed for the target feature.

## No-guessing rule

When behavior is unclear, the model MUST NOT invent expected behavior. It MUST record one of these labels (the canonical uncertainty vocabulary):

- `SPEC_AMBIGUITY` — requirement is unclear.
- `ORACLE_GAP` — expected result cannot be proven from docs/code/API spec.
- `ENV_GAP` — test cannot run because environment command/data/service is missing.
- `DATA_GAP` — fixture or seed data is missing.
- `TOOL_GAP` — optional tool is unavailable.
- `JUSTIFIED_EXCEPTION` — required coverage cannot be automated or is outside the agreed scope.

For each gap, the model MUST still propose a safe fallback test or manual exploratory check.

## Identity contract

- The skill name `vnpt-qa-tester-orchestrator` is the BMAD skill identity.
- It MUST NOT be renamed, aliased, or wrapped under a different name.
- The run id, scope name, and QA output root MUST all reference this identity.
- The skill does **not** import, spawn, or HTTP-call any runtime service. If a future migration needs such a bridge, it MUST be added explicitly and is out of scope for the current migration.

## Failure handling policy

- Never stop the entire QA run because one strategy is blocked by `TOOL_GAP` / `ENV_GAP` / `DATA_GAP`; record the gap and continue.
- Never stop the entire QA run because a single test fails; classify and continue.
- Never mark a run `done` while `bug-batches.json` contains un-triaged entries.
- Never mark a run `done` while `failure-backlog.md` (or its successor in `08-failure-triage.md`) contains unresolved `PRODUCT_BUG` entries without a `fix_brief_ref`.

## Stall protocol

- Track `non_progress_streak` in `qa-state.json` if the run has a long-running mode that spans multiple invocations.
- If 2 consecutive phases fail to advance (status remains unchanged across two calls into the same step), mark `qaRunStatus = "stalled_partial"` and continue where possible.
- For `missing_bmad_docs_recursive_scan` or `missing_bmad_docs_zero_eof_reading` failures, include the exact missing-file list in the residual-risk register.

## Medium-model decomposition rule (REQUIRED per phase)

For each step in `steps/`, the model MUST produce a small table:

```text
| Input checked | Decision made | Output artifact | Open gap | Next action |
```

This reduces drift and makes skipped steps obvious. The rule applies to steps 00–11.

## Self-review before finalizing

Before producing `11-final-qa-report.md`, the model MUST answer these checks (mirrored in step 11):

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

## Forbidden shortcuts (apply to fix briefs)

A fix brief is invalid if it permits the dev agent to:

- ship placeholder/mock/TODO-only code
- downgrade the scope of the failing test (e.g. "skip the failing case")
- silently change the spec without an explicit `SPEC_AMBIGUITY` trace
- remove assertions to make the test pass
- add catch-all exception swallowers
- raise a timeout without addressing the underlying cause
- rely on a flaky-test stabilization that masks a real race

## Reference

- Pin values for state, gate, priority, taxonomy: `data/qa-orchestrator-policy.json`.
- Phase transition diagrams: `references/qa-state-machine.md`.
- Artifact schemas: `references/qa-artifact-schema.md`.
- Step-by-step instructions: `steps/step-00-qa-mission.md` … `steps/step-11-final-qa-report.md`.
- Run-level workflow spec: `workflow.md`.
- BMAD manifest: `SKILL.md`.
