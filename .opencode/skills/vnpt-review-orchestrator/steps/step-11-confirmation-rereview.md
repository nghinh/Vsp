# Step 11: Confirmation Re-Review

**Goal:** Run one final fresh confirmation review after a zero-issue pass. Require zero actionable issues for completion. Produce `review-summary.md`.

## Prerequisites

- `step-10-fresh-rereview.md` reported zero actionable issues (first zero-issue pass achieved)
- `review-live-backlog.json` has no `open` items

## Sequence

1. **Update `review-state.json`:**
   - Set `current_phase: confirmation_rereview`
   - Increment `pass_count`

2. **Spawn parallel `vnpt-review-auditor` sub-agents** (confirmation pass):
   - Same procedure as `step-06-review-pass.md`
   - Each auditor performs a completely fresh review of the current workspace
   - Confirmation pass is identical to a regular fresh pass — no special shortcuts

3. **Await all auditor results:**

4. **Check for actionable issues:**
   - If any auditor returns actionable findings:
     - These are genuine remaining issues
     - Set `fresh_confirmation_pass_done: false`
     - Loop back to `step-08-fix-waves.md`
   - If all auditors return `NO_ACTIONABLE_ISSUES`:
     - Confirmed: workspace is clean
     - Set `fresh_confirmation_pass_done: true`

5. **Build `review-summary.md`** with the following sections:

   ### Remaining Risks
   - Any risks that were waived, deferred, or accepted with rationale
   - Note any validation commands that could not be run

   ### Confirmation Review Outcome
   - Pass count: `<N>`
   - Actionable issues found: `<count>`
   - Confirmation pass: `CLEAN` or `DIRTY`

   ### Phase Trace Table
   ```
   | Phase | Step | Status | Timestamp |
   |-------|------|--------|----------|
   | scope_and_mode | step-01 | complete | ISO8601 |
   | docs_inventory | step-03 | complete | ISO8601 |
   | context_map | step-04 | complete | ISO8601 |
   | risk_map | step-05 | complete | ISO8601 |
   | review_pass | step-06 | complete | ISO8601 |
   | findings_aggregation | step-07 | complete | ISO8601 |
   | fix_waves | step-08 | complete | ISO8601 |
   | validation | step-09 | complete | ISO8601 |
   | fresh_rereview | step-10 | complete | ISO8601 |
   | confirmation_rereview | step-11 | complete | ISO8601 |
   ```

   ### Final Issue Counts
   - Total found: `<count>`
   - Fixed: `<count>`
   - Closed: `<count>`
   - Waived: `<count>`
   - Deferred: `<count>`
   - Still open: `<count>` (must be 0 for completion)

6. **Final update `review-state.json`:**
   - Set `status: complete`
   - Set `fresh_confirmation_pass_done: true`
   - Record `completed_at: ISO8601`

## Hard stops

- **Never** mark `status: complete` without `fresh_confirmation_pass_done: true`.
- **Never** mark `status: complete` while any issue is `open`.
- **Never** skip the confirmation review after a zero-issue pass — it is mandatory.
- **Never** accept "close enough" — confirmation pass must report zero actionable issues.

## Completion Criteria

The review run is complete when:
1. `review-state.json` `status == "complete"`
2. `fresh_confirmation_pass_done == true`
3. All backlog items are in `fixed`, `closed`, `waived`, or `deferred` (zero `open`)
4. `review-summary.md` is written

## Outputs

- `{review_folder}/review-summary.md`
- Final `{review_folder}/review-state.json` (`status: complete`)
- `{review_folder}/forensics.md` (only if stall/failure occurred)
