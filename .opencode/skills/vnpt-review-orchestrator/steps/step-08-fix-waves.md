# Step 08: Fix Waves

**Goal:** Build the fix wave plan, then fan out parallel `vnpt-fix-worker` sub-agents to fix all open backlog items. Each fix wave avoids write-scope overlap.

## Prerequisites

- `step-07-findings-aggregation.md` has completed
- `review-live-backlog.json` exists with `open` items
- `review-context-map.md` and `review-risk-map.md` are complete

## Sequence

1. **Check open issues:**
   - Count `open` items in `review-live-backlog.json`
   - If `open_count == 0` → skip to `step-10-fresh-rereview.md` (zero-issue pass achieved)
   - If `open_count > 0` → proceed with fix waves

2. **Build `review-fix-plan.md`:**
   - Create fix waves using the same dependency-aware wave building rules as dev-epic-orchestrator:
     - **Parallel-allowed**: items with no write-scope overlap may share a wave
     - **Sequential-required**: items with overlapping write-scope (same file, same API, same DB table) go in separate waves
   - Wave plan table format:
     ```
     | Wave | Issues | Owned Paths | Overlap Risk |
     |------|--------|-------------|--------------|
     | 1 | A, B | path/A, path/B | LOW |
     | 2 | C | path/C | LOW |
     ```
   - Each issue gets: `issue_id`, `owned_paths[]`, `wave`
   - Owned paths = the files the fix worker is allowed to edit for this issue

3. **Wave assignment rules:**
   - Group issues by write-scope overlap
   - HIGH overlap (same file) → separate sequential waves
   - MEDIUM overlap (same module) → separate sequential waves
   - LOW overlap (independent files) → same parallel wave
   - Never put overlapping write scopes in the same wave

4. **Spawn parallel `vnpt-fix-worker` sub-agents:**
   - For each parallel wave, spawn one worker per issue (in parallel)
   - Each worker receives:
     - Assigned `issue_id` list
     - Owned paths (from fix-plan)
     - Tech lane context
     - Relevant VNPT implementation skills
   - Workers are allowed to edit (edit: allow)
   - Loading requirements per worker:
     - MUST load stack-appropriate implementation skill
     - MUST load `ui-ux-pro-max` for frontend work
     - See `vnpt-fix-worker.md` for full skill mapping

5. **Await all fix workers:**
   - Wait for ALL workers in the wave to return before proceeding
   - Collect: `fixed_issue_ids`, `files_changed`, `validation_commands_run`, `evidence_after_by_issue`

6. **Update `review-live-backlog.json`:**
   - For each `fixed_issue_id`:
     - Set `status: fixed`
     - Set `evidence_after` from worker output
     - Set `fixed_by: worker_id`
     - Set `updated_pass: <current_pass_count>`

7. **Update `review-state.json`:**
   - Set `current_phase: fix_waves`
   - Record `fix_wave_completed: <wave_number>`

## Synchronize barrier (HARD)

- **MUST** wait for ALL workers in the current wave to finish before starting the next wave
- Never interleave fix waves

## Hard stops

- **Never** spawn multiple workers for the same issue
- **Never** allow a worker to edit outside its owned paths
- **Never** close an issue without `evidence_after_by_issue`
- **Never** claim all fixed if any validation command failed
- **Never** skip the synchronize barrier between waves

## Outputs

- `{review_folder}/review-fix-plan.md` (wave assignments)
- Updated `{review_folder}/review-live-backlog.json`
- Updated `{review_folder}/review-state.json`

## Next step

Proceed to `step-09-validation.md`.
