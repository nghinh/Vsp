# Step 02: Resume

**Goal:** Continue from existing `phase-state.json` without regenerating artifacts.

## Prerequisites

- `docs/vnpt-flow/<story-id>/phase-state.json` exists
- Status is NOT `done`

## Sequence

### Step 2.1 — Read Phase State

1. **Read `phase-state.json`:**
   ```json
   {
     "story_id": "<id>",
     "phase": "<current phase>",
     "status": "<status>",
     "routing_decision": "<planning|quality>",
     "current_wave": <n>,
     "completed_waves": [...],
     "pending_slices": [...]
   }
   ```

2. **Determine resume point:**
   - `phase: discovery` → resume from Step 01.4 (routing)
   - `phase: planning` → resume from Step 03 (planning)
   - `phase: executing_wave_n` → resume from Step 04 (execute waves)
   - `phase: quality_gate` → resume from Step 05 (quality)
   - `phase: fix_loop` → resume from Step 05 (fix loop)

### Step 2.2 — Validate State

1. **Verify artifacts exist:**
   - `story-source-read.md`
   - `contract-read.md` (or fallback)
   - Previous step outputs

2. **If state invalid or artifacts missing:**
   - Fall back to Step 01 (discovery)
   - Clear corrupted state

### Step 2.3 — Resume

Route to the appropriate step based on current phase.

## Outputs

- Updated `phase-state.json` if resuming from different phase

## Hard Stops

- Never resume if `status: done`
- Never skip artifact validation before resume
- Never restart from scratch unless state is invalid

## Next Step

Based on resumed phase (same as Create flow):
- `discovery` → Step 01.4
- `planning` → Step 03
- `executing_wave_n` → Step 04
- `quality_gate` → Step 05
- `fix_loop` → Step 05 (fix loop)
