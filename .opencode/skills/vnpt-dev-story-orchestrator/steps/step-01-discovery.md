# Step 01: Story Discovery

**Goal:** Check story status, read story source files and source-root contract, route to correct next step.

## Prerequisites

- Story ID provided via invocation
- Config loaded from `_bmad/config.yaml`

## Sequence

### Step 1.1 — Read Story Source

1. **Locate story file:**
   - Search `docs/**/implementation-artifacts/**/<story-id>.md`
   - Search `docs/**/planning-artifacts/**/<story-id>.md`
   - If not found, fail with `story_not_found`

2. **Read story source file:**
   - Extract BMAD status from YAML frontmatter (`status:`) or body (`Status:` section)
   - Parse: Story description, Acceptance Criteria, Tasks, Dev Notes, File List

3. **Classify story:**
   ```
   | Status | Routing | Next Step |
   |--------|---------|-----------|
   | done | SKIP | None — mark done |
   | ready-for-dev | PLANNING | Step 03 |
   | in-progress | PLANNING | Step 03 (resume) |
   | review | QUALITY | Step 05 |
   ```

### Step 1.2 — Read Source-Root Contract

1. **Find contract file:**
   - `docs/**/*contract*.md`
   - `docs/**/*source-root*.md`
   - Story's `source_root` / `contract` frontmatter field
   - Fallback: epic summary as implicit contract

2. **Read contract** and extract:
   - File structure expectations
   - API contracts
   - Integration points

### Step 1.3 — Produce Context Files

Create `docs/vnpt-flow/<story-id>/`:
- `story-source-read.md` — extracted story content
- `contract-read.md` — extracted contract content (or note if no explicit contract)
- `phase-state.json` — initial state

```json
{
  "story_id": "<id>",
  "phase": "discovery",
  "status": "pending",
  "bmad_status": "<original status>",
  "routing_decision": "<skip|planning|quality>",
  "context_read": true,
  "contract_read": true
}
```

### Step 1.4 — Route

```
IF routing_decision = "skip":
  → Update phase-state.json to {status: "done", routing_decision: "skip"}
  → Step 06 (Wrapup)

IF routing_decision = "planning":
  → Step 03 (Planning + Implementation)

IF routing_decision = "quality":
  → Step 05 (Quality Gate)
```

## Outputs

- `docs/vnpt-flow/<story-id>/story-source-read.md`
- `docs/vnpt-flow/<story-id>/contract-read.md`
- `docs/vnpt-flow/<story-id>/phase-state.json`

## Hard Stops

- Never proceed if story file not found
- Never skip reading story source and contract before routing
- Never route a `done` story to planning or quality

## Next Step

Based on `routing_decision`:
- `skip` → Step 06 (Wrapup)
- `planning` → Step 03 (Planning + Implementation)
- `quality` → Step 05 (Quality Gate)
