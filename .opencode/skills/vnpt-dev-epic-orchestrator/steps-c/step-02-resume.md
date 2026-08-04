# Step 02: Resume Check

**Goal:** Detect an in-progress run and rebuild wave plan on the pending-story set. Only load this step when the user invoked with `resume` / `continue` / "pick up where we left off", or when a previous run left `epic-state.json` in a non-`done` state.

## Sequence

1. **Check `{epic_run_folder}/epic-state.json`:**
   - If absent → no resume. Proceed to `step-03-discover.md` for a fresh run.
   - If present and `status == "done"` → user likely wants a new run; proceed to `step-03-discover.md` after a confirmation menu.

2. **If `status != "done"`:**
   - Read `epic-state.json` to identify `current_epic_index` and `resume_pointer`.
   - Load all pending stories for the current epic (not just the next index).
   - Rebuild the wave plan on the pending-story set per `step-04-wave-plan.md` §Wave building rules.

3. **Re-execute preflight** (`step-05-preflight.md`) on the rebuilt state.

## Hard stops

- **Never** re-run already completed stories unless the user explicitly requests.
- **Never** collapse remaining pending stories into sequential execution without explicit dependency/overlap evidence. If pending stories have no `depends_on` / `blocked_by` / `parent` and no write-scope overlap, place them in the same parallel wave (one `vnpt-epic-story-runner` per independent story).

## Output

- Updated `{epic_run_folder}/execution-order.md` (rebuilt waves).
- Updated `{epic_run_folder}/epic-state.json` (`resume_pointer` cleared or moved forward).

## Next step

Proceed to `step-06-execute-waves.md` (skip steps 3-5 since the run was already past them).
