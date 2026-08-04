# Step 10: Quality Gate

**Goal:** Score QA quality, apply hard-fail rules, and emit the machine-readable JSON report the runtime parses to decide whether a fix loop is needed. The quality gate is risk-sensitive: any uncovered P0 risk fails the gate even when aggregate score is high.

## Prerequisites

- All earlier artifacts (`00-09`) exist with stable IDs.
- `bug-batches.json` updated with `fix_brief_ref` per required bug.
- `qa-state.json` `phase_status = "fix_briefs"`.

## Sequence

### Step 10.1 — Apply the scoring rubric

Score the test suite using the canonical weights from `config/quality-gates.yaml`:

| Dimension | Weight |
|---|---:|
| risk_coverage | 20 |
| requirement_coverage | 15 |
| negative_boundary_coverage | 15 |
| state_transition_coverage | 15 |
| property_invariant_coverage | 10 |
| api_contract_fuzz_coverage | 10 |
| e2e_critical_path_coverage | 10 |
| mutation_quality | 5 |

Apply the threshold table:

| Result | Score |
|---|---:|
| pass | ≥ 85 |
| conditional_pass | 70–84 |
| fail | < 70 |

### Step 10.2 — Apply the hard-fail rules

A run is hard-failed when ANY of the following is true:

- A P0 risk has no executable test or justified exception.
- A P1 business-critical state transition has no executable test.
- Test oracle is missing or incomplete for any executable test.
- Failed tests are not triaged.
- A critical module has only shallow smoke/render/status-200 tests.
- No negative or boundary tests exist for a critical area.
- Mutation score is below threshold for a critical module when mutation testing is feasible.
- Any P0/P1 risk lacks risk_id → test_id → oracle_id traceability.

In addition, the strict medium-model hard fails from `config/quality-gates.yaml` apply:

- Any P0/P1 risk lacks risk_id → test_id → oracle_id traceability.
- Any executable test lacks expected_result or assertions.
- Any critical workflow lacks forbidden-transition coverage.
- Any validation-heavy feature lacks boundary/invalid/null-empty tests.
- API schema exists but no API fuzz plan or justified exception exists.
- UI critical path exists but no E2E plan or justified exception exists.
- Test suite contains only mocks/snapshots/render/status-200 checks for critical behavior.
- Final report does not include the self-review checklist.

### Step 10.3 — Apply the anti-gaming penalty surface

Score deductions when the following patterns are detected:

| Pattern | Penalty | Notes |
|---|---:|---|
| Shallow test detected | -15 each | Floor of 50 |
| Duplicate test pair | -5 each | similarity ≥ 0.85 |
| Invalid JUSTIFIED_EXCEPTION | -10 each | Missing concrete_reason / fallback / approval |
| Tests_per_risk > 30 | flag for review | Not deducted unless duplicates confirmed |
| assertions_per_test < 2 | flag for review | Not deducted unless unique_assertions_ratio < 0.3 |

### Step 10.4 — Compute final score and gate result

```text
score = max(floor, sum_of_dimension_scores − penalties)
gate_result = "pass" if score ≥ 85 and no_hard_fails
            = "conditional_pass" if 70 ≤ score < 85 and no_hard_fails
            = "fail" otherwise
```

### Step 10.5 — Write `docs/qa/<scope>/10-quality-gate-report.md` (human-readable)

The file MUST contain:

- dimension-by-dimension scoring with evidence references
- hard-fail checklist with pass/fail per item
- penalty ledger
- final gate result with reasoning
- forward pointer to step-11

### Step 10.6 — Write `docs/qa/<scope>/10-quality-gate-report.json` (machine-readable)

The JSON file MUST conform to the schema in `config/medium-model-guardrails.yaml` Section 11:

```json
{
  "gate_result": "pass|conditional_pass|fail",
  "score": 85,
  "critical_bugs": [
    {
      "bug_id": "QA-BUG-001",
      "title": "...",
      "severity": "critical",
      "signature": "unique-short-id",
      "fix_brief_ref": "docs/qa/<scope>/09-fix-briefs/QA-BUG-001.md"
    }
  ],
  "p0_uncovered_risks": [],
  "fix_brief_paths": ["docs/qa/<scope>/09-fix-briefs/QA-BUG-001.md"]
}
```

The runtime parses this JSON to determine if a fix loop is needed. Missing or invalid JSON = gate treated as `fail`.

## Required inputs

- outputs from earlier phases — all `00-09` artifacts.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map drives coverage scoring.

## Required work (deliverables for this step)

- risk coverage
- requirement coverage
- negative / boundary coverage
- state coverage
- property / invariant coverage
- API fuzz coverage
- E2E critical coverage
- mutation quality
- hard-fail enumeration

## Required output

- `docs/qa/<scope>/10-quality-gate-report.md`
- `docs/qa/<scope>/10-quality-gate-report.json`

## Exit criteria

- the named output artifacts exist (both .md and .json)
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
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
  "current_step": "step-10-quality-gate",
  "phase_status": "quality_gate",
  "scope_artifacts": {
    "10-quality-gate-report.md": "written",
    "10-quality-gate-report.json": "written"
  },
  "gate_summary": {
    "score": <int>,
    "gate_result": "pass | conditional_pass | fail",
    "hard_fails": ["<rule>"],
    "penalties": [{"pattern": "<name>", "count": <int>, "deduction": <int>}],
    "p0_uncovered_risks": []
  }
}
```

## Hard stops

- Never accept a `pass` result when any hard fail fires.
- Never accept a `pass` result when a P0 risk has no executable test or justified exception.
- Never ship a JSON gate report that does not validate against `gate_report_json_schema` in `config/medium-model-guardrails.yaml` Section 11.
- Never mark a risk as covered when its only test is a render-only / status-200 / snapshot / mock-only test.

## Next step

Proceed to `step-11-final-qa-report.md`. Only load that file when both gate report files are written and the JSON validates. Never load multiple step files simultaneously.
