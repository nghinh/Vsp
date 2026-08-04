# Step 06: Execute Epic Loop

**Goal:** For each epic in `execution-order.md` (sequential), execute story waves. For each story, run the planning → implement → quality gate sequence.

## Sequence

For each epic in `execution-order.md` (sequential):

1. **Update `epic-state.json`:** `current_epic_index`, `phase: executing`.

2. **For each wave in the epic's story waves:**

   a. **Phase A (Plan)** — for each story in the wave with `routing_decision == planning`:
      - If wave size > 1 (independent stories), spawn one `vnpt-epic-story-runner` per story **in parallel** in PLANNING mode with REQUIRED CONTEXT READING paths.
      - If wave size == 1, spawn a single `vnpt-epic-story-runner`.
      - Wait for all planning outputs in the wave before proceeding.
      - Update BMAD story source status `ready-for-dev` → `in-progress` for each story.
      - Stories with `routing_decision == quality` SKIP Phase A entirely (they arrived at Phase C directly from Step 0).

   b. **Phase B (Implement)** — for each story in the wave with `routing_decision == planning`:
      - Build slice waves: independent slices (no dependency, no shared write-scope) → group in a parallel wave.
      - If a slice wave size > 1, spawn one `vnpt-epic-story-implementer` per slice **in parallel**.
      - If a slice wave size == 1, spawn a single `vnpt-epic-story-implementer`.
      - Each implementer runs the post-write duplicate-detection loop.
      - **MUST** wait for all implementers in the same slice wave to finish before starting the next slice wave (synchronize barrier).
      - Check `duplicate_detection_outcome` in `slice-matrix.md`. If `duplicate_detection_status: failed`, record in `failure-backlog.md` and continue.
      - Update BMAD story source status `in-progress` → `review` for each story.
      - Stories with `routing_decision == quality` SKIP Phase B entirely.

   c. **Phase C (Quality)** — for each story in the wave (both `planning` and `quality` routing decisions):
      - Spawn `vnpt-epic-story-runner` in QUALITY-GATE mode (one per story; quality gate is per-story).
      - Validate + review + fix loop orchestration.
      - On clean pass: update status `review` → `done`.
      - On failure: record in `failure-backlog.md` with retry hints.

3. **After each story** update `epic-state.json` and `epic-progress.md`. Track evidence per §Per-story evidence below.

## Sub-agent invocation pattern

- `vnpt-epic-story-runner` is used in PLANNING mode and QUALITY-GATE mode. Never dispatches implementers.
- `vnpt-epic-story-implementer` is used for slice implementation. Owns the dedup gate.
- Both are **AGENTS**, not skills. Do not bulk-load skills at the epic layer.

## Slice dedup inspection (M6)

After each `vnpt-epic-story-implementer` returns from a slice, the orchestrator MUST inspect `slice-matrix.md` for that story to verify the duplicate-detection chain ran clean. The implementer's agent prompt defines the chain; the orchestrator's enforcement gate is:

1. **Locate the slice row** in `docs/vnpt-flow/<story-id>/slice-matrix.md` for the slice_id that just completed.
2. **Read the `duplicate_detection_outcome` field** in that row. It must contain:
   - the gate chain (`Cy → CC → Emb → AI → Pre → Done`)
   - the candidate list
   - the LLM verdict verbatim (or the chain's final decision)
3. **Verify the final decision is clean** — `REUSE`, `RENAME`, `EXTRACT`, or `SKIP_SEMANTIC` with `_block: false` in `dedup_report.json`.
4. **If `duplicate_detection_outcome` is missing or shows a failure:**
   - Mark the slice failed with `failure_reason_class = "duplicate_detection_failed"`.
   - Persist the failure in `phase-state.json.duplicate_detection_status = "failed"`.
   - Append to `failure-backlog.md` with the report path.
   - **Do not** mark the story done.
   - Continue with the next slice / story / epic (do not abort the global run).

This inspection is the orchestrator's only enforcement point for the dedup chain — the implementer is bound by its own agent prompt, but the orchestrator MUST independently verify the artifact.

## REQUIRED CONTEXT READING

Every dispatch prompt MUST contain a populated `REQUIRED CONTEXT READING` file list (PRD / architecture / UX / epic-story / mockups). A dispatch is invalid if `REQUIRED CONTEXT READING` is omitted or contains only generic directory names.

## Per-story evidence

After each story run, persist:
- `implementer_worker_count`, `implementer_worker_ids`, `slice_dispatch_map`
- `required_skills`, `loaded_skills`, `skill_loading_evidence`, `skill_gap`
- `prd_sources_read`, `project_context_sources_read`, `story_sources_read`, `mockup_sources_read`, `context_alignment_notes`
- `debt_policy_ack`, `shortcut_signals_detected`, `technical_debt_items`, `scope_downgrade_requests`
- `story_status_before`, `story_status_after`, `story_status_file`, `story_status_transition`

## Failure handling

- If `prd_sources_read` is empty for a story run, mark story failed with reason `missing_prd_context_evidence`.
- If `project_context_sources_read` or `story_sources_read` is empty, mark failed with reason `missing_context_evidence`.
- If UX/UI required and `mockup_sources_read` is empty, mark failed with reason `missing_ux_context_evidence`.
- If anti-shortcut evidence indicates downgrade, mark failed with reason `technical_debt_policy_violation`.
- If completed story still in `ready-for-dev` / `draft` / `in-progress`, mark failed with reason `story_status_not_progressed`.
- If story marked done but failed validation/review, mark failed with reason `story_status_invalid_done`.

## Hard stops

- **Never** spawn multiple sub-agents simultaneously for a single story or slice when dependency or overlap evidence exists. Independent items MAY be parallelized.
- **Never** execute a story wave of size > 1 with only one `vnpt-epic-story-runner`.
- **Never** execute a slice wave of size > 1 with only one `vnpt-epic-story-implementer`.
- **Never** skip the slice-wave synchronize barrier.
- **Never** dispatch sub-agents without `REQUIRED CONTEXT READING`.
- **Never** abort the global run on a single story failure.

## Next step

After all epics are processed (or all epics are `done` / `stalled_partial`), proceed to `step-07-review-gate.md`.
