# Step 08: Finalize Epic

**Goal:** Produce per-epic completion artifacts, detect stalls, and write forensics for stalled epics.

## Sequence

1. **Produce `epic-summary.md`** with completed/failed counts per epic.

2. **Include actionable recommendations** for remaining failed stories in `epic-summary.md`.

3. **Update `failure-backlog.md`** with failed stories + error summary + retry hints.

4. **Stall detection:**
   - If the epic stalled (2+ consecutive failures with same reason class), mark `epic-state.json` `status: stalled_partial`.
   - Write `forensics.md` with root cause analysis.
   - For `technical_debt_policy_violation` reason class, include exact offending phrases/snippets in `forensics.md`.

5. **Stall detection on success:** if the epic passes review gate cleanly, mark `epic-state.json` `status: done`.

## Outputs

- `{epic_run_folder}/epic-summary.md` (per epic)
- `{epic_run_folder}/failure-backlog.md` (updated)
- `{epic_run_folder}/forensics.md` (only on stall/failure)

## Next step

Proceed to `step-09-wrapup.md`.
