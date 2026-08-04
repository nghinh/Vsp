# Step 06: Wrapup

**Goal:** Finalize run, update state to done, produce summary.

## Prerequisites

- All waves executed (Step 04 complete)
- Quality gate passed (Step 05 complete)
- OR story was `done` or `skip` (from Step 01)

## Sequence

### Step 6.1 — Final Validation

1. **Verify all artifacts exist:**
   - `story-source-read.md`
   - `contract-read.md`
   - `story-context-packet.md`
   - `slice-matrix.md`
   - `requirements-coverage.md`
   - `validation-report.md`

2. **Verify completion criteria:**
   - All acceptance criteria mapped to slices
   - All validations passed
   - Quality gate reported zero actionable issues

### Step 6.2 — Update Phase State

```json
{
  "story_id": "<id>",
  "phase": "done",
  "status": "done",
  "bmad_status": "done",
  "completed_waves": [<all wave numbers>],
  "quality_status": "clean",
  "all_artifacts_produced": true,
  "completed_at": "<ISO timestamp>"
}
```

### Step 6.3 — Produce Summary

Write `docs/vnpt-flow/<story-id>/story-summary.md`:

```markdown
# Story <story-id> Summary

## Story Info
- **Title:** <title>
- **BMAD Status:** done
- **Routing:** <skip|planning|quality>

## Execution
- **Waves Executed:** <count>
- **Slices Implemented:** <count>
- **Quality Loops:** <count>

## Artifacts Produced
- story-source-read.md
- contract-read.md
- story-context-packet.md
- execution-plan.md
- slice-matrix.md
- requirements-coverage.md
- validation-report.md

## Validation Results
| Slice | Status | Files | Validations |
|-------|--------|-------|-------------|
| <id> | pass | <files> | <results> |

## Quality Summary
- Critical Issues: 0
- Major Issues: 0
- Minor Issues: 0

## Changed Files
<list of all changed files>

## Residual Risks
<any remaining risks or open items>
```

### Step 6.4 — Mark Story Done

1. **Update story source file** to mark status as `done`
2. **Clear any stall flags** if present

## Outputs

- `docs/vnpt-flow/<story-id>/phase-state.json` (status: done)
- `docs/vnpt-flow/<story-id>/story-summary.md`

## Completion Criteria Met

✅ Story status is `done`
✅ All acceptance criteria mapped and implemented
✅ Validations clean
✅ Quality gate reports zero actionable issues
✅ All artifacts produced
✅ `phase-state.json` status is `done`

## Next Step

Story execution complete. Return summary to user.
