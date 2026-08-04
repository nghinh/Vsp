# Step 04: Execute Waves

**Goal:** Execute slice waves using `vnpt-story-implementer` agents.

## Prerequisites

- Step 03 (Planning) completed
- `slice-matrix.md` and `wave plan` exist in `docs/vnpt-flow/<story-id>/`
- `phase-state.json` has `wave_count` and `waves` array

## Sequence

### Step 4.1 — Execute Wave N

For each wave in order:

1. **Determine parallelization:**
   - If wave has `parallel: true` → spawn multiple implementers simultaneously
   - If wave has `parallel: false` → spawn implementers sequentially

2. **Spawn `vnpt-story-implementer` agents:**
   ```
   Required context reading:
   - docs/vnpt-flow/<story-id>/story-source-read.md
   - docs/vnpt-flow/<story-id>/contract-read.md
   - docs/vnpt-flow/<story-id>/slice-matrix.md
   - docs/vnpt-flow/<story-id>/story-context-packet.md

   Agent must receive:
   - slice_id
   - owned_paths
   - blocked_paths
   - validation_commands
   - dependency_list
   ```

3. **Each implementer:**
   - Reads implementation context
   - Implements bounded slice
   - Runs dedup protocol (pre-write gate → write → post-write gate → reindex)
   - Returns structured output with changed files, validation results

4. **Wait for all agents in wave to complete**

### Step 4.2 — Merge and Validate

1. **Collect outputs from all implementers in wave**
2. **Merge into `validation-report.md`:**
   ```markdown
   ## Wave <N> Results

   | Slice | Status | Files | Validation |
   |-------|--------|-------|------------|
   | <id>  | pass/fail | <files> | <results> |
   ```
3. **Update `phase-state.json`:**
   ```json
{
  "phase": "executing_wave_<N>",
  "completed_waves": [<completed wave numbers>],
  "current_wave": "<N>"
}
```

### Step 4.3 — Loop to Next Wave

- If more waves remain → repeat Step 4.1
- If all waves complete → proceed to Step 5 (Quality Gate)

## Validation Policy by Stack

- **Frontend:** lint + typecheck + unit + build/smoke
- **Backend:** lint + tests + compile/build
- **Mobile:** lint + static analysis + tests + compile
- **Infra/DevOps:** linter/validator + dry-run/syntax checks

## Outputs

- `docs/vnpt-flow/<story-id>/validation-report.md` (incremental updates)
- Updated `docs/vnpt-flow/<story-id>/phase-state.json`

## Hard Stops

- Never start next wave before current wave completes
- Never parallelize non-independent slices
- Never mark wave complete if any slice failed validation
- Never skip dedup protocol for any write

## Next Step

After all waves complete → Step 05 (Quality Gate)
