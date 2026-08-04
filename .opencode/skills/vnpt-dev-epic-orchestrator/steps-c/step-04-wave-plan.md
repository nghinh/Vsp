# Step 04: Build Execution Order and Waves

**Goal:** Parse story dependencies, build the dependency graph per epic, and freeze deterministic wave assignments (parallel-allowed canonical flow).

> **Prerequisite:** `step-03.5-story-discovery.md` has run. Only stories with `routing_decision` = `planning` or `quality` are included in waves. Stories with `routing_decision` = `skip` (already `done`) are excluded.

## Sequence

1. **Parse story dependencies** from epic/story metadata using the rules in §Wave building rules below.

2. **Build dependency graph** for each epic.

3. **Create dependency-aware waves** for the epic:
   - Independent stories (no explicit dependency, no write-scope overlap) → group in a single parallel wave.
   - Dependent or overlapping stories → placed in later waves, never parallel with their dependencies.
   - For each parallel story wave of size > 1, **MUST** spawn one `vnpt-epic-story-runner` per story.

4. **Freeze deterministic epic order** (alphabetical by `epic_id`).

5. **Freeze deterministic story order** within each wave — alphabetical by `story_id`, with dependent stories placed in later waves.

6. **Materialize `execution-order.md`** — frozen epic order + story order + wave assignments.

7. **Materialize `epic-state.json`** with `epic_count`, `epics[]`, `resume_pointer`, `status: pending`.

## Wave building rules (canonical — parallel allowed when independent)

- **Story-level (Phase A)**: Inside each epic, execute stories with dependency-aware waves — parallel for independent stories.
  - Execute independent stories in the same wave in parallel; execute dependent or overlapping stories in later sequential waves.
  - For any story wave containing 2 or more independent stories, **MUST** spawn multiple `vnpt-epic-story-runner` sub-agents in parallel (one per story).
  - A story wave of size > 1 with only one runner is invalid.

- **Slice-level (Phase B)**: Inside each story, execute slices with dependency-aware waves — parallel for independent slices.
  - For any story phase with 2 or more independent slices, **MUST** spawn multiple `vnpt-epic-story-implementer` sub-agents in parallel (one per slice).
  - **MUST** wait for all implementers in the same slice wave before starting the next slice wave (synchronize barrier).

- **Dependency / overlap detection** decides parallel vs. sequential placement:
  - Explicit dependency metadata (`depends_on` / `blocked_by` / `parent`) → items go into later waves, never parallel.
  - Write-scope overlap (same DB table, API endpoint, UI component, feature flag) → items go into later waves, never parallel.
  - No dependency metadata **and** no overlap evidence → items are independent and may share a parallel wave.

- **Overlap risk categories** (HIGH / MEDIUM / LOW) drive wave placement:
  - HIGH → must serialize.
  - MEDIUM → must serialize.
  - LOW → may be parallelized if dependency metadata is also absent.

- **Resume behavior**: When rebuilding waves for a resumed epic, do not collapse remaining pending stories to sequential execution without explicit dependency/overlap evidence. Pending stories with no dependency and no overlap belong in the same parallel wave.

## Hard stops

- **Never** run epics in parallel — sequential only.
- **Never** run dependent or overlapping stories in the same wave.
- **Never** run dependent or overlapping slices in the same wave.
- **Never** execute a story wave of size > 1 with only one `vnpt-epic-story-runner`.
- **Never** execute a slice wave of size > 1 with only one `vnpt-epic-story-implementer`.
- **Never** skip the slice-wave synchronize barrier (must wait for all implementers before the next slice wave).
- **Never** collapse remaining pending stories to sequential without explicit dependency/overlap evidence.

## Outputs

- `{epic_run_folder}/execution-order.md`
- `{epic_run_folder}/epic-state.json` (initial)

## Next step

Proceed to `step-05-preflight.md`.
