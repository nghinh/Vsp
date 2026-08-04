# Step 10: Fresh Re-Review

**Goal:** Run a completely fresh new review pass after fix waves to verify issues are resolved. This is a brand-new first-pass style review, not a replay.

## Prerequisites

- `step-09-validation.md` has completed
- Validation has passed (or failures have been recorded as stalls)

## Sequence

1. **Update `review-state.json`:**
   - Set `current_phase: fresh_rereview`
   - Increment `pass_count`

2. **Loop decision:**
   - Check `review-live-backlog.json` for `open` issue count
   - If `open_count == 0`:
     - This is the first zero-issue pass
     - Proceed to `step-11-confirmation-rereview.md` for the mandatory confirmation pass
   - If `open_count > 0`:
     - Continue with fresh re-review

3. **Spawn parallel `vnpt-review-auditor` sub-agents** (fresh review):
   - Same procedure as `step-06-review-pass.md`
   - Each auditor performs a **completely fresh review from the current workspace**
   - Do NOT use prior pass findings as context
   - Do NOT replay old findings
   - Only report issues that currently exist in the code NOW

4. **Await all auditor results:**

5. **Merge findings** into `review-current-pass-findings.json`:
   - Deduplicate by `issue_signature`
   - Sort by severity

6. **Reconcile against backlog:**
   - Items found in fresh review that are in backlog as `open` → still open, update evidence
   - Items found in fresh review that are NOT in backlog → new issue, add as `open`
   - Backlog items NOT found in fresh review → verify: is it truly fixed?
     - If truly fixed → set to `fixed`
     - If validation failed but not found → set to `stalled`

7. **Stall detection:**
   - Append to `open_issue_count_history`
   - If non-decreasing for 2+ consecutive entries:
     - Set `status: stalled`
     - Write `forensics.md`
     - Narrow scope and escalate

8. **Update `review-state.json`:**
   - Record `last_pass_findings_count`
   - Record `last_pass_actionable_count`

## Fresh review rule (HARD — repeat)

- Every re-review must be a **brand-new first-pass style review**
- Do NOT replay old findings from previous passes
- Only report an issue if it can currently be observed in the code NOW
- If something was fixed, omit it entirely
- If an old issue is not reproduced in the newest fresh review, close it

## Hard stops

- **Never** stop after only one review pass — the loop must run until zero actionable issues.
- **Never** replay findings — each pass is fresh.
- **Never** skip the confirmation review after a zero-issue pass.

## Outputs

- Updated `{review_folder}/review-current-pass-findings.json` (fresh findings)
- Updated `{review_folder}/review-live-backlog.json`
- Updated `{review_folder}/review-state.json`
- `forensics.md` if stall detected

## Next step

- If zero actionable issues → proceed to `step-11-confirmation-rereview.md`
- If actionable issues remain → loop back to `step-08-fix-waves.md` for another fix wave
