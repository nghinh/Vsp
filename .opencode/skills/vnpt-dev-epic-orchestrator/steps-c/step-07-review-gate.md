# Step 07: Per-Epic Review Gate

**Goal:** After each epic's `epic-summary.md` is generated, run `/vnpt-review-loop` and require the latest pass to report zero actionable issues before declaring the epic done.

## Sequence

1. **Trigger** — `epic-summary.md` is generated for the epic, and all stories in the epic are in `done` status.

2. **Execute:**
   ```bash
   /vnpt-review-loop docs/vnpt-flow/epic-run-<run_id>/epic-summary.md
   ```

3. **Pass conditions** (all must hold):
   - Review loop reports **ZERO actionable issues**.
   - `review_pass_count` (in `epic-state.json`) is incremented.
   - `last_review_actionable_issues = 0`.

4. **Fail conditions:**
   - Review loop reports **1+ actionable issues**.
   - Issues are logged to `failure-backlog.md`.
   - Fix → validate → fresh review loop continues.

5. **Loop until clean:**
   ```text
   while (last_review_actionable_issues > 0) {
     fix issues
     /vnpt-review-loop (fresh pass)
   }
   ```

## State updates

After each review pass, update `epic-state.json`:

```json
{
  "review_pass_count": <incremented>,
  "last_review_actionable_issues": <count>
}
```

## Hard stops

- **Never** mark an epic done while the latest review pass has actionable issues.
- **Never** skip the review gate even if all stories pass.
- **Never** accept "close enough" — zero actionable issues required.
- **Never** infer "pass" from no output — confirm zero issues in the response.

## Next step

After the review gate passes, proceed to `step-08-finalize.md`.
