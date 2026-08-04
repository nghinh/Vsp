# Step 08: Confirmation Review — Final Gate Before Completion

**Goal:** Run one extra fresh confirmation review after the first zero-issue pass; run bundled validator; write final summary.

## Sequence

### 1. Confirmation review (HARD — must run)

Spawn one final fresh `vnpt-sec-review-auditor` pass on the current workspace:
- Same rules as `step-07-fresh-review.md`
- This is MANDATORY even though the previous pass was clean
- Hard rule: never stop after the first zero-issue pass without this confirmation

### 2. Update confirmation flag

If confirmation review also returns 0 actionable issues:
- Set `security-review-state.json` `fresh_confirmation_pass_done: true`

### 3. Run bundled validator

Before final completion, run:
```
python docs/vnpt-sec-review-orchestrator/tools/validate_security_artifacts.py docs/vnpt-flow/<scope-id>/security-review/
```

If validator fails:
- Report validation failures
- Do not mark as complete
- Return to `step-07-fresh-review.md`

### 4. Write security-summary.md

```
# Security Review Summary

## Run Identity
- scope_id: <from state>
- scope_source: <from state>
- mode: <from state>

## Pass Counts
- Total passes: <N>
- Pass history: <open_issue_count_history>

## Issues Summary
- Total found: <M>
- Closed: <X>
- Waived: <Y>
- Open: <Z>

## Closed Issues (with evidence_after)
| Issue ID | Title | Evidence After |
|----------|-------|----------------|

## Remaining Risks
[any residual risks not fully closed]

## Confirmation Review Outcome
[result of the mandatory confirmation pass]

## Validator Result
[output of validate_security_artifacts.py]

## Phase Trace
| Input checked | Decision made | Output artifact | Open gap | Next action |
|---------------|---------------|-----------------|----------|-------------|
```

### 5. Mark complete

If all of the following hold:
- `fresh_confirmation_pass_done: true`
- Zero open actionable issues
- Validator passed
- `security-summary.md` written

Then update `security-review-state.json`:
- `status: complete`

### 6. Failure handling

If confirmation review finds issues (or validator fails):
- Reset `fresh_confirmation_pass_done: false`
- Return to `step-05-fix-waves.md`

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-summary.md`
- `docs/vnpt-flow/<scope-id>/security-review/security-review-state.json` (status: complete OR back to fix loop)

## Next step

If `status: complete` → orchestrator run is done.
If confirmation failed → back to `step-05-fix-waves.md`.
