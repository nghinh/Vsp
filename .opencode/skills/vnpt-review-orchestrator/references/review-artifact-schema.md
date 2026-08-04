> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by any runtime service.

> The schemas below describe artifacts written by the orchestrator skill under `docs/vnpt-flow/<scope-id>/review/`. They are read by step files and by the LLM agent.

# Review Artifact Schemas

## review-state.json

```json
{
  "run_id": "string",
  "scope_id": "string",
  "mode": "diff | full | path-arg | handoff | manual",
  "scope_source": "workspace-diff | path-arg | review-handoff | manual | agent",
  "status": "pending | in_progress | stalled | complete | failed",
  "current_phase": "scope_and_mode | docs_inventory | context_map | risk_map | review_pass | findings_aggregation | fix_waves | validation | fresh_rereview | confirmation_rereview",
  "pass_count": "number",
  "open_issue_count_history": ["number"],
  "fresh_confirmation_pass_done": "boolean",
  "created_at": "ISO8601",
  "updated_at": "ISO8601",
  "completed_at": "ISO8601 | null",
  "tech_lanes": ["string"],
  "validation_passed": "boolean | null",
  "last_pass_findings_count": "number",
  "last_pass_actionable_count": "number"
}
```

## review-current-pass-findings.json

```json
{
  "pass_count": "number",
  "findings": [
    {
      "issue_id": "string",
      "issue_signature": "string",
      "title": "string",
      "severity": "info | low | medium | high | critical",
      "category": "workflow/review | workflow/fix | code/style | code/logic | code/security | code/performance | config/build | config/ci | docs/missing | test/coverage | test/quality",
      "files": ["string"],
      "evidence_before": "string",
      "fix_recommendation": "string",
      "blocking_validation": "string | null",
      "success_condition": "string"
    }
  ],
  "summary": {
    "total": "number",
    "by_severity": {
      "critical": "number",
      "high": "number",
      "medium": "number",
      "low": "number",
      "info": "number"
    },
    "by_category": {
      "category": "number"
    }
  }
}
```

## review-live-backlog.json

```json
{
  "backlog": [
    {
      "issue_id": "string",
      "issue_signature": "string",
      "title": "string",
      "severity": "info | low | medium | high | critical",
      "category": "string",
      "files": ["string"],
      "status": "open | in_progress | stalled | fixed | closed | waived | deferred",
      "evidence_before": "string",
      "evidence_after": "string | null",
      "fixed_by": "string | null",
      "wave": "number | null",
      "opened_pass": "number",
      "updated_pass": "number"
    }
  ],
  "summary": {
    "total": "number",
    "open": "number",
    "in_progress": "number",
    "stalled": "number",
    "fixed": "number",
    "closed": "number",
    "waived": "number",
    "deferred": "number"
  }
}
```

## review-handoff.json

```json
{
  "handoff_id": "string",
  "source_producer": "string",
  "produced_at": "ISO8601",
  "touched_scope": ["string"],
  "changed_files": ["string"],
  "validations_already_executed": [
    {
      "command": "string",
      "result": "string",
      "exit_code": "number"
    }
  ],
  "known_residual_risks": ["string"],
  "notes": "string"
}
```

## review-context-map.md Format

```markdown
# Review Context Map

## BMAD Docs Inventory
| Path | Type | Title |
|------|------|-------|

## Scope Boundary Notes
**In scope:**
- list

**Out of scope:**
- list

## Source/Config Verification
- Evidence sources per finding category

## Phase Trace Table
| Phase | Step | Status | Timestamp |
|-------|------|--------|----------|
```

## review-risk-map.md Format

```markdown
# Review Risk Map

## Risk Taxonomy
| Category | Preliminary Severity | Notes |
|----------|--------------------|-------|

## Stack/Scope Routing
| File/Module | Tech Lane |
|-------------|-----------|

## Validation Route
| Stack | Commands |
|-------|----------|

## Phase Trace Table
| Phase | Step | Status | Timestamp |
|-------|------|--------|----------|
```

## review-fix-plan.md Format

```markdown
# Fix Wave Plan

## Wave Assignments
| Wave | Issue IDs | Owned Paths | Overlap Risk |
|------|-----------|-------------|--------------|
```

## review-validation-report.md Format

```markdown
# Validation Report

## Validation Commands Executed
| Wave | Issue | Command | Result | Exit Code |
|------|-------|---------|--------|-----------|

## Result Summary
- Passed: N
- Failed: N
- Warnings: N

## Corroboration Evidence
| Issue | Validation | Evidence |
|-------|-----------|----------|
```

## review-summary.md Format

```markdown
# Review Summary

## Remaining Risks
- waived/deferred items with rationale

## Confirmation Review Outcome
- Pass count: N
- Actionable issues found: N
- Confirmation pass: CLEAN | DIRTY

## Final Issue Counts
| Status | Count |
|--------|-------|
| Total found | N |
| Fixed | N |
| Closed | N |
| Waived | N |
| Deferred | N |
| Still open | N |

## Phase Trace Table
| Phase | Step | Status | Timestamp |
|-------|------|--------|----------|
```
