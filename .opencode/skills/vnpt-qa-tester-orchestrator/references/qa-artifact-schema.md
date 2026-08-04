# QA Artifact Schemas

The schemas below describe artifacts written by the orchestrator skill under `docs/qa/<scope>/`. They are read by step files and by the LLM agent. They are independent of any runtime state file.

## qa-state.json

```json
{
  "scope": "string",
  "run_id": "ISO8601",
  "qa_run_status": "pending | in_progress | blocked | done | failed | stalled_partial",
  "current_step": "string",
  "phase_status": "mission_setup | context_reading | risk_modeling | test_strategy_planning | test_case_design | test_oracle_design | test_automation_generation | test_execution | failure_triage | fix_briefs | quality_gate | done | failed",
  "scope_artifacts": {
    "00-qa-mission.md": "pending | written",
    "01-context-map.md": "pending | written",
    "02-risk-map.md": "pending | written",
    "03-test-strategy.md": "pending | written",
    "04a-example-test-cases.md": "pending | written",
    "04b-combinatorial-dimensions.md": "pending | written",
    "04c-pict-model.pict": "pending | written",
    "04d-combinatorial-test-matrix.md": "pending | written",
    "04e-state-model.md": "pending | written",
    "04f-state-sequence-tests.md": "pending | written",
    "04g-property-invariants.md": "pending | written",
    "04h-api-fuzz-plan.md": "pending | written",
    "04i-exploratory-charter.md": "pending | written",
    "04j-regression-test-plan.md": "pending | written",
    "04k-test-data-fixtures.md": "pending | written",
    "05-test-oracle.md": "pending | written",
    "06-automation-map.md": "pending | written",
    "07-test-execution-report.md": "pending | written",
    "08-failure-triage.md": "pending | written",
    "09-fix-briefs/": "pending | written",
    "bug-batches.json": "pending | written | updated",
    "10-quality-gate-report.md": "pending | written",
    "10-quality-gate-report.json": "pending | written",
    "11-final-qa-report.md": "pending | written"
  },
  "evidence": {
    "prd_sources_read": ["string"],
    "project_context_sources_read": ["string"],
    "story_sources_read": ["string"],
    "mockup_sources_read": ["string"],
    "context_alignment_notes": "string"
  },
  "uncertainty_labels_used": ["SPEC_AMBIGUITY | ORACLE_GAP | ENV_GAP | DATA_GAP | TOOL_GAP | JUSTIFIED_EXCEPTION"],
  "bmad_hard_gate": {
    "recursive_scan_done": "boolean",
    "scan_done": "boolean",
    "relevant_docs_read_0_eof": "boolean",
    "justified_exception": "string | null"
  },
  "risk_summary": {
    "p0_count": "number",
    "p1_count": "number",
    "p2_count": "number",
    "p3_count": "number",
    "uncovered_p0_risks": ["string"]
  },
  "strategy_summary": {
    "executable_strategies": ["string"],
    "infeasible_strategies": [{"strategy": "string", "reason": "string", "fallback": "string"}],
    "execution_order": ["string"]
  },
  "test_inventory": {
    "by_prefix": {
      "QA-EX-": "number",
      "QA-COMB-": "number",
      "QA-SM-": "number",
      "QA-PROP-": "number",
      "QA-API-": "number",
      "QA-E2E-": "number",
      "QA-REG-": "number",
      "QA-EXP-": "number"
    },
    "total": "number",
    "p0_risks_with_tests": ["string"],
    "p1_risks_with_tests": ["string"]
  },
  "oracle_summary": {
    "total_oracles": "number",
    "tests_with_oracle": "number",
    "tests_with_oracle_gap": "number",
    "justified_exceptions": "number"
  },
  "automation_summary": {
    "executable_tests": "number",
    "manual_only_tests": "number",
    "tests_with_business_assertion": "number",
    "tests_with_shallow_assertion_only": "number",
    "mocks_used_with_justification": "number"
  },
  "execution_summary": {
    "runs_total": "number",
    "tests_passed": "number",
    "tests_failed": "number",
    "tests_skipped": "number",
    "tests_blocked_env_gap": "number",
    "tests_blocked_data_gap": "number",
    "tests_blocked_tool_gap": "number",
    "tests_blocked_justified_exception": "number",
    "coverage_percent": "number | null",
    "failure_evidence_count": "number"
  },
  "triage_summary": {
    "failures_total": "number",
    "product_bug_count": "number",
    "test_bug_count": "number",
    "flaky_test_count": "number",
    "environment_issue_count": "number",
    "spec_ambiguity_count": "number",
    "data_setup_issue_count": "number",
    "extended_type_counts": {
      "race_condition": "number",
      "deadlock_or_livelock": "number",
      "data_race": "number",
      "atomicity_violation": "number",
      "ordering_violation": "number",
      "memory_leak": "number",
      "authorization_bypass": "number",
      "input_validation_bypass": "number",
      "state_corruption": "number",
      "idempotency_violation": "number",
      "security_issue": "number",
      "timing_issue": "number",
      "consistency_issue": "number"
    }
  },
  "fix_brief_summary": {
    "briefs_required": "number",
    "briefs_written": "number",
    "bugs_without_brief": ["string"]
  },
  "gate_summary": {
    "score": "number",
    "gate_result": "pass | conditional_pass | fail",
    "hard_fails": ["string"],
    "penalties": [{"pattern": "string", "count": "number", "deduction": "number"}],
    "p0_uncovered_risks": ["string"]
  },
  "completion": {
    "all_artifacts_present": "boolean",
    "p0_p1_risks_covered_or_justified": "boolean",
    "every_test_has_oracle": "boolean",
    "tests_executed_when_feasible": "boolean",
    "failures_triaged": "boolean",
    "product_bugs_have_fix_briefs": "boolean",
    "gate_pass_or_explicit": "boolean",
    "final_report_exists": "boolean",
    "release_recommendation": "GO | CONDITIONAL_GO | NO_GO"
  },
  "non_progress_streak": "number",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

## bug-batches.json

Schema mirrors `schemas/bug-batches.schema.json` (v2.0 extended types). Each entry MUST include:

```json
{
  "bug_id": "QA-BUG-XXX",
  "severity": "P0 | P1 | P2 | P3",
  "type": "PRODUCT_BUG | TEST_BUG | FLAKY_TEST | ENVIRONMENT_ISSUE | SPEC_AMBIGUITY | DATA_SETUP_ISSUE | RACE_CONDITION | SECURITY_ISSUE | DEADLOCK_OR_LIVELOCK | MEMORY_LEAK | TIMING_ISSUE | DATA_RACE | ATOMICITY_VIOLATION | ORDERING_VIOLATION | CONSISTENCY_ISSUE | IDEMPOTENCY_VIOLATION | AUTHORIZATION_BYPASS | INPUT_VALIDATION_BYPASS | STATE_CORRUPTION",
  "failed_test_ids": ["string"],
  "risk_ids": ["string"],
  "oracle_ids": ["string"],
  "reproduction_steps": ["string"],
  "expected": "string",
  "actual": "string",
  "evidence": "string",
  "suspected_files": ["string"],
  "fix_hint": "string",
  "forbidden_shortcuts": ["string"],
  "acceptance_criteria": ["string"],
  "regression_tests_to_keep": ["string"],
  "fix_brief_ref": "string | null"
}
```

## 10-quality-gate-report.json

Schema mirrors `gate_report_json_schema` in `config/medium-model-guardrails.yaml` Section 11:

```json
{
  "gate_result": "pass | conditional_pass | fail",
  "score": "integer 0-100",
  "critical_bugs": [
    {
      "bug_id": "QA-BUG-001",
      "title": "string",
      "severity": "critical | high | medium | low",
      "signature": "string",
      "fix_brief_ref": "path"
    }
  ],
  "p0_uncovered_risks": ["string"],
  "fix_brief_paths": ["string"]
}
```

Missing or invalid JSON = gate treated as `fail`.

## Recommended artifact tree

```text
docs/qa/<scope>/
├── 00-qa-mission.md
├── 01-context-map.md
├── 02-risk-map.md
├── 03-test-strategy.md
├── 04a-example-test-cases.md
├── 04b-combinatorial-dimensions.md
├── 04c-pict-model.pict
├── 04d-combinatorial-test-matrix.md
├── 04e-state-model.md
├── 04f-state-sequence-tests.md
├── 04g-property-invariants.md
├── 04h-api-fuzz-plan.md
├── 04i-exploratory-charter.md
├── 04j-regression-test-plan.md
├── 04k-test-data-fixtures.md
├── 05-test-oracle.md
├── 06-automation-map.md
├── 07-test-execution-report.md
├── 08-failure-triage.md
├── 09-fix-briefs/
│   └── QA-BUG-XXX.md
├── bug-batches.json
├── 10-quality-gate-report.md
├── 10-quality-gate-report.json
├── 11-final-qa-report.md
└── qa-state.json
```

## BMAD proof table (mandatory inside `01-context-map.md`)

| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Extracted requirement IDs | Open gaps |
|---|---|---:|---|---|---|---|---|---|

Allowed `0-EOF status` values (pinned in `data/qa-orchestrator-policy.json` → `evidenceAllowedStatuses`):

- `READ_0_EOF`
- `NOT_FOUND`
- `NOT_RELEVANT_WITH_REASON`
- `TOO_LARGE_READ_IN_CHUNKS`
- `BLOCKED_WITH_REASON`

`BLOCKED_WITH_REASON` is allowed only when the file cannot be read due to tool/runtime limits. It MUST create an `ENV_GAP` or `TOOL_GAP` and cannot be hidden.
