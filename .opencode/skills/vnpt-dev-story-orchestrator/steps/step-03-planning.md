# Step 03: Planning + Implementation Dispatch

**Goal:** Build slice plan, wave plan, coverage matrix, then dispatch implementers.

## Prerequisites

- Step 01 (Discovery) completed with `routing_decision: planning`
- `story-source-read.md` and `contract-read.md` exist
- Story status is `ready-for-dev` or `in-progress`

## Sequence

### Step 3.1 — Spawn Runner (Planning Mode)

1. **Spawn `vnpt-story-runner` in PLANNING mode:**
   ```
   Required context reading:
   - docs/vnpt-flow/<story-id>/story-source-read.md
   - docs/vnpt-flow/<story-id>/contract-read.md
   - Project PRD docs
   - Architecture docs
   - UX/UI docs (if applicable)
   ```

2. **Runner produces:**
   - `story-context-packet.md` — story intent, constraints, ACs
   - `execution-plan.md` — slice objectives, dependencies, wave assignment
   - `slice-matrix.md` — owner, allowed write scope, blocked paths, validation commands per slice
   - `requirements-coverage.md` — acceptance criteria to slice mapping

### Step 3.2 — Coverage Gate

1. **Verify every acceptance criterion maps to at least one slice**
2. **If unmapped criteria exist:**
   - STOP
   - Update `phase-state.json` with `coverage_incomplete: true`
   - Request runner to revise plan

### Step 3.3 — Preflight Gate

1. **Verify:**
   - All required context docs are readable
   - Slice write scopes do NOT overlap (unless explicitly sequential)
   - Validation commands are runnable

2. **If preflight fails:**
   - STOP and fix before execution

### Step 3.4 — Wave Plan

1. **Build waves:**
   - Wave N: independent slices (no write-path overlap)
   - Sequential: dependent or overlapping slices
   - Record in `phase-state.json`

2. **Update `phase-state.json`:**
   ```json
   {
     "phase": "planning_artifacts_ready",
     "status": "pending",
     "wave_count": <n>,
     "waves": [
       {"wave": 1, "slices": ["<id>", ...], "parallel": true},
       {"wave": 2, "slices": ["<id>", ...], "parallel": false}
     ]
   }
   ```

### Step 3.5 — Dispatch to Step 04

Proceed to `step-04-execute-waves.md`

## Outputs

- `docs/vnpt-flow/<story-id>/story-context-packet.md`
- `docs/vnpt-flow/<story-id>/execution-plan.md`
- `docs/vnpt-flow/<story-id>/slice-matrix.md`
- `docs/vnpt-flow/<story-id>/requirements-coverage.md`
- Updated `docs/vnpt-flow/<story-id>/phase-state.json`

## Hard Stops

- Never dispatch implementation without coverage complete
- Never dispatch implementation without preflight passing
- Never parallelize overlapping write scopes
- Never skip writing required artifacts

## Next Step

Step 04 (Execute Waves)
