# QA Phase State Machine

> Status values come from `data/qa-orchestrator-policy.json` (pinned at run start). The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret values mid-run.

## Phase lifecycle

```
   mission_setup ──► context_reading ──► risk_modeling ──► test_strategy_planning
                                                          │
                                                          ▼
                                            test_case_design ──► test_oracle_design
                                                                       │
                                                                       ▼
                                                       test_automation_generation
                                                                       │
                                                                       ▼
                                                              test_execution
                                                                       │
                                                                       ▼
                                                              failure_triage
                                                                       │
                                                                       ▼
                                                                 fix_briefs
                                                                       │
                                                                       ▼
                                                              quality_gate ──► done
                                                          │                  ▲
                                                          ▼                  │
                                                       failed ◄─────────────┘
```

Allowed transitions:

| From | To | Trigger |
|---|---|---|
| `mission_setup` | `context_reading` | `00-qa-mission.md` written |
| `context_reading` | `risk_modeling` | BMAD hard gate satisfied (`BMAD_DOCS_RECURSIVE_SCAN_DONE` + `BMAD_DOCS_SCAN_DONE` + `BMAD_RELEVANT_DOCS_READ_0_EOF` OR `JUSTIFIED_EXCEPTION`) |
| `risk_modeling` | `test_strategy_planning` | `02-risk-map.md` written |
| `test_strategy_planning` | `test_case_design` | `03-test-strategy.md` written, every P0 risk has at least one strategy |
| `test_case_design` | `test_oracle_design` | every `04a-04k` artifact written |
| `test_oracle_design` | `test_automation_generation` | `05-test-oracle.md` written, every executable test has at least one oracle |
| `test_automation_generation` | `test_execution` | `06-automation-map.md` written |
| `test_execution` | `failure_triage` | `07-test-execution-report.md` written |
| `failure_triage` | `fix_briefs` | `08-failure-triage.md` + `bug-batches.json` written |
| `fix_briefs` | `quality_gate` | every required `PRODUCT_BUG` has a `fix_brief_ref` |
| `quality_gate` | `done` | both `10-quality-gate-report.md` and `10-quality-gate-report.json` written, JSON validates |
| any phase | `failed` | a hard stop fires and the run cannot recover |

`done` is terminal. `failed` is terminal unless an authorized exception explicitly resets `phase_status` to a prior phase.

## QA-run lifecycle (outer loop)

```
   pending ──► in_progress ──► done
                  │
                  ▼
               blocked ◄── (TOOL_GAP / ENV_GAP / DATA_GAP)
                  │
                  ▼
              stalled_partial ◄── (non_progress_streak ≥ 2)
```

| State | Meaning | Allowed transitions |
|---|---|---|
| `pending` | Run created, no step has been entered | → `in_progress` |
| `in_progress` | At least one step in `steps/` is active | → `done` / `blocked` / `stalled_partial` / `failed` |
| `blocked` | Run halted by an external gap (`TOOL_GAP` / `ENV_GAP` / `DATA_GAP`) | → `in_progress` (gap closed) / `failed` |
| `done` | `phase_status = "done"` and every item in the **Completion definition** is true | (terminal) |
| `stalled_partial` | 2+ consecutive phases did not advance | → `in_progress` (manual reset) / (terminal) |
| `failed` | Hard-stop rule fired with no recovery | → `in_progress` (manual reset) / (terminal) |

## Gate lifecycle

```
   pending ──► computing ──► pass | conditional_pass | fail
                  │                    │                  │
                  ▼                    ▼                  ▼
              blocked           conditional-go       no-go
```

Gate result values are pinned in `data/qa-orchestrator-policy.json` → `gateResultValues`. Mapping to release recommendation is also pinned: `pass → GO`, `conditional_pass → CONDITIONAL_GO`, `fail → NO_GO`.

## Failure reason classes

From `data/qa-orchestrator-policy.json` → `failureReasonClasses`:

| Class | Triggered by | Detection |
|---|---|---|
| `missing_prd_context_evidence` | Empty PRD read evidence | `qa-state.json.evidence.prd_sources_read` |
| `missing_context_evidence` | Empty project/source read evidence | `qa-state.json.evidence` |
| `missing_bmad_docs_recursive_scan` | `BMAD_DOCS_RECURSIVE_SCAN_DONE = false` | `qa-state.json.bmad_hard_gate` |
| `missing_bmad_docs_zero_eof_reading` | `BMAD_RELEVANT_DOCS_READ_0_EOF = false` and no `JUSTIFIED_EXCEPTION` | `qa-state.json.bmad_hard_gate` |
| `missing_risk_coverage` | A P0 risk has no test in `04a-04k` | `qa-state.json.test_inventory.p0_risks_with_tests` |
| `missing_oracle` | An executable test has no oracle in `05-test-oracle.md` | `qa-state.json.oracle_summary.tests_with_oracle_gap` |
| `missing_business_assertion` | A test in `06-automation-map.md` is shallow-only | `qa-state.json.automation_summary.tests_with_shallow_assertion_only` |
| `missing_negative_boundary_for_critical` | A P0 risk lacks negative + boundary tests | depth matrix check |
| `missing_state_transition_test` | A feature with states lacks `QA-SM-*` tests | `qa-state.json.test_inventory` |
| `missing_api_fuzz_plan_or_justification` | OpenAPI/GraphQL schema exists but `04h` empty | per-risk strategy map |
| `missing_e2e_plan_or_justification` | UI critical path exists but no `QA-E2E-*` | per-risk strategy map |
| `untriaged_failures` | `07-test-execution-report.md` failures > `08-failure-triage.md` entries | cross-reference |
| `mutation_score_below_threshold` | Mutation score < configured threshold for a critical module | `07-test-execution-report.md` |
| `shallow_only_test_suite` | Critical module has only render/status-200/snapshot tests | anti-gaming detection |
| `duplicate_detection_failed` | Combinatorial matrix row → no executable test | matrix-to-test cross-reference |
| `gate_json_invalid` | `10-quality-gate-report.json` fails schema | schema validator |

## Stall detection

- Track `non_progress_streak` in `qa-state.json` for long-running mode.
- If 2 consecutive phases fail to advance (status remains unchanged across two calls into the same step):
  - Mark `qaRunStatus = "stalled_partial"`.
  - Write the residual risk and the missing inputs to the residual-risk register in step 11.
  - Continue where possible.

For `missing_bmad_docs_recursive_scan` and `missing_bmad_docs_zero_eof_reading`, include the exact missing-file list in the residual-risk register.
