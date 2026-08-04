# Step 09: Wrapup

**Goal:** Aggregate across all epics, produce the final completion summary, and return control to the user.

## Sequence

1. **After each epic completes**, check if more epics remain in `execution-order.md`.

2. **If more epics remain**, loop back to `step-06-execute-waves.md` for the next epic.

3. **When all epics are done:**
   - Aggregate final `failure-backlog.md` across all epics.
   - Produce the final aggregate `epic-summary.md` (overwrite per-epic version with the cross-epic rollup).
   - Return a concise completion summary with artifact paths.

## Final output

```text
**Epic Orchestration Complete**

Epics: {epic_count}
Completed: {completed_count}
Failed: {failed_count}

Artifacts: docs/vnpt-flow/epic-run-{run_id}/

Recommendations for failed stories: {failure_backlog_summary}
```

## Hard stops

- **Never** abort the global run because a single story failed.
- **Never** claim full success when `failure-backlog.md` is non-empty.
- **Never** declare the run done if any epic is still `in_progress` or `review_gate`.

## Completion

The skill is complete only when:

1. All epics in `execution-order.md` are `done` or explicitly `stalled_partial` with `forensics.md`.
2. The latest `/vnpt-review-loop` pass per epic reports zero actionable issues.
3. `failure-backlog.md` is either empty or has actionable retry recommendations.
4. Final aggregate `epic-summary.md` is written.
