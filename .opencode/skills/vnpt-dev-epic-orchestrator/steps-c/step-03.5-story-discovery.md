# Step 03.5: Story Discovery and Status Routing (Step 0)

**Goal:** For each epic, check the status of all discovered stories. Filter out already-done stories. Read story source files for remaining stories to understand implementation context. Route each non-done story to the correct next step based on its current status.

## Prerequisites

- `epic-inventory.md` exists from `step-03-discover.md`
- Stories have been discovered and mapped to their epics

## Sequence

### Step 0.1 — Check Story Statuses

1. **For each epic in `epic-inventory.md`:**
   - List all stories belonging to that epic
   - Read each story's source file to extract its BMAD status
   - BMAD story status lives in:
     - YAML frontmatter field `status:`, OR
     - A `Status` section in the story markdown body
   - Classify each story into one of:
     - `done` → exclude from execution
     - `ready-for-dev` → route to Step 1 (Planning)
     - `in-progress` → route to Step 1 (Planning, resuming)
     - `review` → route to Step 3 (Quality)

2. **Produce `story-status-list.md`** — per-epic table with columns:
   ```
   | epic_id | story_id | story_title | bmad_status | routing_decision | reason |
   ```
   - `routing_decision`: `skip` (done), `planning` (ready-for-dev/in-progress), `quality` (review)
   - `reason`: brief note (e.g. "already done", "status=review, skip to quality")

3. **Produce summary:**
   ```
   Epic: <epic_id>
     Done stories (skipped): <count> — <story_id list>
     Planning stories: <count> — <story_id list>
     Quality stories: <count> — <story_id list>
   ```

### Step 0.2 — Pre-read Story Source Files and Source-Root Contract

For each story with `routing_decision` = `planning` or `quality`:

1. **Read the story source file** (`docs/**/implementation-artifacts/**/*.md`):
   - Parse: Story description, Acceptance Criteria, Tasks/Subtasks, Dev Notes, File List
   - Extract: implementation context, constraints, linked references

2. **Read the source-root contract** (if it exists for this story):
   - Contract file paths typically: `docs/**/*contract*.md`, `docs/**/*source-root*.md`, or the story's own `source_root` / `contract` frontmatter field
   - If no explicit contract is referenced, use the story's own frontmatter and the epic's `epic-summary.md` as the implicit contract
   - For `planning` stories: inform the slice-planning context
   - For `quality` stories: inform the review context

3. **Store pre-read outputs** in `{epic_run_folder}/story-context/<story-id>/`:
   - `story-source-read.md` — extracted story content (Story, AC, Tasks, Dev Notes)
   - `contract-read.md` — extracted contract content (or `contract-read.md` noting "no explicit contract; epic summary used as implicit contract")

### Routing Rules

| BMAD Status | Routing | Orchestrator Action |
|---|---|---|
| `done` | Skip | Do not spawn runner/implementer; mark as `skipped` in `story-status-list.md` |
| `ready-for-dev` | Step 1 (Planning) | Spawn `vnpt-epic-story-runner` in PLANNING mode |
| `in-progress` | Step 1 (Planning, resume) | Spawn `vnpt-epic-story-runner` in PLANNING mode; runner must resume from checkpoint |
| `review` | Step 3 (Quality) | Spawn `vnpt-epic-story-runner` in QUALITY-GATE mode directly; skip planning and implementation |

### Update `epic-state.json`

Add per-story routing to `epic-state.json`:

```json
{
  "stories": [
    {
      "story_id": "<id>",
      "bmad_status": "<status>",
      "routing_decision": "<planning|quality|skip>",
      "context_read": true,
      "contract_read": true
    }
  ]
}
```

Update `epic-state.json` `phase: preflight` → `phase: story_discovery_complete`.

## Outputs

- `{epic_run_folder}/story-status-list.md` — per-epic story status table
- `{epic_run_folder}/story-context/<story-id>/story-source-read.md` — per non-done story
- `{epic_run_folder}/story-context/<story-id>/contract-read.md` — per non-done story
- Updated `{epic_run_folder}/epic-state.json` with story routing

## Hard Stops

- **Never** proceed to Step 1 (Planning) for a story that is already `done`.
- **Never** spawn `vnpt-epic-story-implementer` for a story in `review` status — route to Step 3 (Quality) instead.
- **Never** skip reading the story source file and contract before dispatching a `planning` or `quality` story.
- **Never** dispatch a sub-agent without `REQUIRED CONTEXT READING` including the story source and contract paths.

## Next step

Proceed to `step-04-wave-plan.md` (build wave plan only for `planning` + `quality` stories; `skip` stories are excluded from waves entirely).
