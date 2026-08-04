# QA Tester Orchestrator Checkpoints

Checkpoints enforce quality gates at key phases to prevent shortcuts and ensure
complete QA workflow execution.

## Checkpoint Definitions

```yaml
checkpoints:
  - id: CP-01
    name: Phase 1 Context Completion
    phase: 01-context-reading
    trigger: After 01-context-map.md written
    blocking: true
    description: |
      Ensures all relevant BMAD documentation has been recursively discovered
      and read from 0-EOF before risk modeling begins.
    checks:
      - check: bmads_scanned_recursively
        description: BMAD docs were scanned recursively under docs/**
        evidence: "Discovery path column in 01-context-map.md"
      - check: eof_reading_proof_exists
        description: 0-EOF reading proof exists for relevant docs
        evidence: "BMAD Docs Inventory table with READ_0_EOF status"
      - check: discovery_path_column_exists
        description: Each doc has discovery path recorded
        evidence: "Discovery path column values: recursive-docs-glob, recursive-docs-fallback, project-context"
      - check: scope_relevance_annotated
        description: All relevant docs are annotated with scope relevance
        evidence: "Scope relevance column filled for all PRD, epic, story, architecture docs"
    on_pass:
      action: allow_progress
      message: "Context reading checkpoint passed"
    on_fail:
      action: block_progress
      message: "Context reading incomplete. Fix 01-context-map.md before proceeding."
      escalation: notify_orchestrator

  - id: CP-02
    name: Risk Map Completeness
    phase: 02-risk-modeling
    trigger: After 02-risk-map.md written
    blocking: false
    description: |
      Ensures all identified risks have test strategies and P0/P1 risks
      are properly prioritized.
    checks:
      - check: p0_risks_have_test_strategy
        description: Every P0 risk maps to at least one test strategy
        evidence: "Test strategy column in 02-risk-map.md"
      - check: p1_risks_have_test_strategy
        description: Every P1 risk maps to at least one test strategy
        evidence: "Test strategy column in 02-risk-map.md"
      - check: risk_id_format_valid
        description: All risk IDs follow RISK-NNN format
        evidence: "Regex pattern RISK-\\d{3} matches all IDs"
      - check: priority_classification_present
        description: All risks have P0/P1/P2/P3 priority
        evidence: "Priority column in risk map"
    on_pass:
      action: allow_progress
      message: "Risk map checkpoint passed"
    on_fail:
      action: warn
      message: "Risk map has gaps. Review 02-risk-map.md"

  - id: CP-03
    name: Oracle Before Automation
    phase: 05-test-oracle-design
    trigger: Before 06-automation-map.md generated
    blocking: true
    description: |
      Ensures every test has an oracle (expected result, source of truth)
      before automation code is generated. This prevents shallow tests.
    checks:
      - check: oracle_exists_for_all_tests
        description: Every test ID has an oracle_id mapping
        evidence: "05-test-oracle.md contains ORACLE-NNN for each QA-* test"
      - check: oracle_source_documented
        description: Each oracle has source (PRD/story/code/API spec)
        evidence: "Source column in oracle table"
      - check: expected_result_specified
        description: Every oracle specifies expected result
        evidence: "Expected result field in oracle entries"
      - check: forbidden_result_specified
        description: Every oracle specifies forbidden result
        evidence: "Forbidden result field in oracle entries"
    on_pass:
      action: allow_progress
      message: "Oracle checkpoint passed - automation may begin"
    on_fail:
      action: block_progress
      message: "Oracle design incomplete. Fix 05-test-oracle.md before generating automation."
      escalation: notify_orchestrator

  - id: CP-04
    name: Quality Gate Before Final Report
    phase: 10-quality-gate
    trigger: Before 11-final-qa-report.md generated
    blocking: false
    description: |
      Validates quality gate results before final QA report is generated.
      Ensures hard fail conditions are addressed.
    checks:
      - check: hard_fails_passed
        description: No hard fail conditions triggered
        evidence: "10-quality-gate-report.md status = pass"
      - check: p0_risk_coverage_100_percent
        description: All P0 risks have executable coverage or JUSTIFIED_EXCEPTION
        evidence: "P0 coverage section in quality gate report"
      - check: p1_risk_coverage_adequate
        description: All P1 risks have coverage or exception
        evidence: "P1 coverage section in quality gate report"
      - check: triage_complete
        description: All failures are triaged
        evidence: "08-failure-triage.md has no untriaged items"
    on_pass:
      action: allow_progress
      message: "Quality gate passed"
    on_fail:
      action: warn
      message: "Quality gate has failures. Final report will include conditional status."

  - id: CP-05
    name: Fix Briefs Validation
    phase: 09-fix-brief-generation
    trigger: After bug-batches.json and 09-fix-briefs/ created
    blocking: false
    description: |
      Ensures every PRODUCT_BUG has a corresponding fix brief with
      actionable implementation hints.
    checks:
      - check: fix_briefs_exist
        description: Number of fix briefs matches PRODUCT_BUG count
        evidence: "09-fix-briefs/*.md files"
      - check: fix_brief_has_required_sections
        description: Each fix brief has summary, severity, reproduction, expected, actual
        evidence: "Required sections in each fix brief file"
      - check: fix_brief_is_actionable
        description: Fix briefs contain implementation hints
        evidence: "Implementation hints section present"
    on_pass:
      action: allow_progress
      message: "Fix briefs validated"
    on_fail:
      action: warn
      message: "Some fix briefs are incomplete or missing"
```

## Checkpoint Execution

### Run single checkpoint:
```bash
python scripts/run_checkpoints.py CP-01 docs/qa/warehouse
```

### Run all checkpoints:
```bash
python scripts/run_checkpoints.py all docs/qa/warehouse
```

### Run blocking checkpoints only:
```bash
python scripts/run_checkpoints.py --blocking docs/qa/warehouse
```

## Integration with Runtime Harness

Checkpoints can be integrated with the external runtime harness:

```bash
# In runtime harness workflow:
runtime checkpoint  # Export checkpoint
runtime continue     # Continue with next action
```

The checkpoint system ensures:
1. No phase is skipped without documented exception
2. Quality gates are enforced before progress
3. Evidence is captured for audit trail

## Version

Version: 1.0.0
Related: runtime/decision_requests/, runtime/governance/