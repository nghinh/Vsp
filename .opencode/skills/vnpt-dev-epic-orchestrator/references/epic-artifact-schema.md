> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by `vnpt-go-runtime`.
> 
> The schemas below (`epic-state.json`, `phase-state.json`, etc.) describe artifacts written by the orchestrator skill under `docs/vnpt-flow/epic-run-<run_id>/`. They are read by step files and by the LLM agent.
> 
> `vnpt-go-runtime` has its own state schema (`RuntimeState` in `internal/contracts/runtime-state.go`) and reads `.runtime/current/state.json`. The runtime does NOT read `epic-state.json` from this skill. The two state files are intentionally decoupled per `SKILL.md` §Runtime non-coupling.

# Epic Artifact Schemas

## epic-state.json

```json
{
  "run_id": "string",
  "epic_count": "number",
  "current_epic_index": "number",
  "status": "pending | in_progress | review_gate | done | failed | stalled_partial",
  "created_at": "ISO8601",
  "updated_at": "ISO8601",
  "epics": [
    {
      "epic_id": "string",
      "epic_name": "string",
      "status": "string",
      "story_count": "number",
      "completed_stories": "number",
      "failed_stories": "number"
    }
  ],
  "review_pass_count": "number",
  "last_review_actionable_issues": "number",
  "non_progress_streak": "number",
  "resume_pointer": "string"
}
```

## phase-state.json

```json
{
  "story_id": "string",
  "phase": "preflight | planning | executing | validating | review_gate | done | failed",
  "status": "string",
  "failure_reason_class": "string | null",
  "started_at": "ISO8601",
  "updated_at": "ISO8601",
  "evidence": {
    "prd_sources_read": "string[]",
    "project_context_sources_read": "string[]",
    "story_sources_read": "string[]",
    "mockup_sources_read": "string[]",
    "context_alignment_notes": "string"
  },
  "implementer_worker_count": "number",
  "implementer_worker_ids": "string[]",
  "slice_dispatch_map": "object",
  "required_skills": "string[]",
  "loaded_skills": "string[]",
  "skill_loading_evidence": "object",
  "skill_gap": "string[]",
  "debt_policy_ack": "boolean",
  "shortcut_signals_detected": "boolean",
  "technical_debt_items": "string[]",
  "scope_downgrade_requests": "string[]",
  "story_status_before": "string",
  "story_status_after": "string",
  "story_status_file": "string",
  "story_status_transition": "string",
  "duplicate_detection_status": "string | null"
}
```

## epic-inventory.md Format

```markdown
# Epic Inventory

## Epic 1: {epic_name}

**Epic ID:** {epic_id}
**Stories:**
| Story ID | Title | Status | Evidence Path |
|----------|-------|--------|---------------|
| 1-1 | {title} | {status} | {path} |
| 1-2 | {title} | {status} | {path} |

## Epic 2: {epic_name}
...
```

## epic-story-manifest.json (RUNTIME-OWNED — do not rename keys)

This file is **not** an orchestrator artifact. It is written by `vnpt-go-runtime`'s `EpicCompletionVerifier.WriteManifest` into `.runtime/current/epic-story-manifest.json` and re-read on every verifier pass. The orchestrator MUST NOT overwrite or rename its JSON keys — only the exact keys below survive Go's `json.Unmarshal` into `core_models.StoryInput`.

Required keys (exact, case-sensitive — these are the `json:"..."` tags on the Go `StoryInput` struct):

```json
{
  "runId": "string",
  "epicId": "string",
  "epicTitle": "string",
  "manifestHash": "string",
  "stories": [
    {
      "storyId": "string",
      "storyTitle": "string",
      "sourcePath": "string"
    }
  ],
  "createdAt": "ISO8601"
}
```

Forbidden aliases — using any of these breaks the SHA256 hash check in `readManifest()` and causes the runtime to loop on `bounded_continue` forever instead of firing the checkpoint prompt:

- `"title"` (must not use as story field — only `"storyTitle"` is accepted)
- `"file"` (must not use as story field — only `"sourcePath"` is accepted)
- `"status"` (must not use as story field — runtime tracks completion elsewhere; do not embed it in the manifest)

If you must mirror a human-readable story view, write it to a separate orchestrator artifact (e.g. `epic-inventory.md`); never mutate `.runtime/current/epic-story-manifest.json` with non-canonical keys.

## execution-order.md Format

```markdown
# Execution Order

**Generated:** {timestamp}
**Run ID:** {run_id}

## Epic Order

1. Epic 1: {epic_name}
2. Epic 2: {epic_name}
...

## Story Waves (per epic)

### Epic 1

**Wave 1 (parallel — independent):**
- Story 1-1
- Story 1-2
- Story 1-4
- Story 1-5

**Wave 2 (sequential — depends on 1-1, 1-2):**
- Story 1-3
```
