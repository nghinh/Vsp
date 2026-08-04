# Step 02: Resume Check

**Goal:** Detect an in-progress review run and resume from the recorded state. Only load this step when the user invoked with `resume` / `continue` / "pick up where we left off", or when `review-state.json` exists in a non-`complete` / non-`failed` state.

## Sequence

1. **Check `{review_folder}/review-state.json`:**
   - If absent → no resume. Proceed to `step-01-scope-and-mode.md` for a fresh run.
   - If present and `status == "complete"` → run is done; report completion summary.
   - If present and `status == "failed"` → hard failure; report and halt unless user requests reset.
   - If present and `status == "in_progress"` or `status == "stalled"` → resume.

2. **If resuming:**
   - Read `review-state.json` to extract: `run_id`, `scope_id`, `pass_count`, `open_issue_count_history`, `current_phase`
   - Read `review-live-backlog.json` to restore the current backlog state
   - Read `review-current-pass-findings.json` if it exists from the last pass
   - Do NOT replay old findings — start fresh from the current workspace
   - Determine next phase from `current_phase`

3. **Resume routing:**
   | `current_phase` | Resume to |
   |-----------------|-----------|
   | `scope_and_mode` | `step-01-scope-and-mode.md` |
   | `docs_inventory` | `step-03-docs-inventory.md` |
   | `context_map` | `step-04-context-map.md` |
   | `risk_map` | `step-05-risk-map.md` |
   | `review_pass` | `step-06-review-pass.md` |
   | `findings_aggregation` | `step-07-findings-aggregation.md` |
   | `fix_waves` | `step-08-fix-waves.md` |
   | `validation` | `step-09-validation.md` |
   | `fresh_rereview` | `step-10-fresh-rereview.md` |
   | `confirmation_rereview` | `step-11-confirmation-rereview.md` |

4. **On fresh run (no state):**
   - If no `review-state.json` exists, this is a fresh run with no prior state
   - Proceed to `step-03-docs-inventory.md` to continue the fresh run flow
   - (step-01 has already created the initial state; step-02 is the routing decision point)

## Hard stops

- **Never** restart from scratch if valid `review-state.json` exists with `status == "in_progress"` or `status == "stalled"`.
- **Never** replay old findings as if they are fresh — a resume still begins with a fresh workspace review.
- **Never** clear `pass_count` or `open_issue_count_history` on resume — append to the existing history.

## Output

- Restored state from `review-state.json` and `review-live-backlog.json`
- Determined next step for resume routing

## Next step

Route to the appropriate step based on `current_phase`:
- `in_progress` / `stalled` → resume from the recorded `current_phase` step
- Fresh run → proceed to `step-03-docs-inventory.md` (step-01 already created the initial state)
