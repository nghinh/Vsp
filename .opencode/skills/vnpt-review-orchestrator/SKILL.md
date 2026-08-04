---
name: vnpt-review-orchestrator
description: Review-first BMAD orchestrator that discovers scope, fans out parallel auditors, aggregates findings, dispatches fix waves, runs validation gates, and enforces the mandatory confirmation review. Use when the user says "/vnpt-review-loop", "run review", "review my code", or wants a full review-fix-validate loop.
version: "2.0.0"
configPath: '{project-root}/_bmad/bmm/config.yaml'
outputFolder: '{output_folder}/review-orchestrator'
---

# vnpt-review-orchestrator

This skill helps you deliver a comprehensive code review by discovering scope, running parallel review passes, fixing issues in waves, validating fixes, and confirming zero outstanding issues. The output is a populated `docs/vnpt-flow/<scope-id>/review/` tree plus a clean review-verified summary.

## Identity contract (HARD)

The orchestrator name `vnpt-review-orchestrator` is a **hard runtime contract**:
- The runtime stamps this value into `producer`/`Producer` fields on checkpoints, handoffs, and continuation capsules.
- Do **not** rename, alias, or override this value.

## Resolution rules

- Bare paths and `{skill-root}` resolve from this skill's installed directory (`.opencode/skills/vnpt-review-orchestrator/` in consumer repos; `vnpt-bmad-custom/vnpt-review-orchestrator/` in the monorepo).
- `{project-root}` → the project working directory.
- `{skill-name}` → `vnpt-review-orchestrator`.

## On Activation

1. **Load config** from `{project-root}/_bmad/config.yaml` and `{project-root}/_bmad/bmm/config.yaml`. Resolve `user_name`, `communication_language`, `document_output_language`, `output_folder`.

2. **Resolve customization** (optional). Read `{skill-root}/customize.toml` if present and apply.

3. **Detect intent** from invocation keywords:
   - `Create`: user says "run review", "/vnpt-review-loop", "review my code", or no intent cue → load `steps/step-01-scope-and-mode.md`.
   - `Resume`: user says "resume", "continue", "pick up where we left off" → check `{review_folder}/review-state.json`; if status is `in_progress` or `stalled`, route to `steps/step-02-resume-check.md`.

4. **Route to first step** per intent above. Each step file owns its own read → execute → write-state → next-step loop. Never load multiple step files simultaneously.

## Intents

| Intent | What it does | Load |
|--------|-------------|------|
| Create | New review run from scope detection to confirmation | `steps/step-01-scope-and-mode.md` |
| Resume | Continue from `review-state.json` resume pointer | `steps/step-02-resume-check.md` |

## Sub-agents (required)

- `vnpt-review-auditor` — read-only review worker. Performs normal review + edge case hunter. Never edits files.
- `vnpt-fix-worker` — fix implementation worker. Fixes assigned backlog items respecting wave ownership.

Both sub-agents are loaded as OpenCode agents from `.opencode/agents/`. They are **not** BMAD skills; do not bulk-load skills at the review layer (sub-agents load their own required skills).

## Key references

- `references/state-machine.md` — run states, phase states, finding lifecycle
- `references/review-artifact-schema.md` — schema for all `review/` artifacts
- `data/orchestrator-policy.json` — status values, severity classes, tech lanes, validation routes
- `data/orchestrator-rules.md` — hard stops and non-negotiable rules

## Runtime policy

State values, severity classes, and validation routes are pinned in `data/orchestrator-policy.json`. The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret these values mid-run.

## Hard stops (NON-NEGOTIABLE)

See `data/orchestrator-rules.md` for the full list. Top-level summary:

- Never run review passes in parallel for the same scope.
- Never skip parallel fan-out when scope can be partitioned.
- Never replay old findings — each pass must be a fresh first-pass style review.
- Never close an issue without `evidence_after`.
- Never mark `status: complete` without `fresh_confirmation_pass_done: true`.
- Never mark `status: complete` while any issue is `open`.
- Never skip the confirmation review after a zero-issue pass.
- Never skip phase order — all 11 phases execute in sequence.
- Never skip validation after fix waves.
- Never skip the artifact validator gate after every pass.
- Never skip the synchronize barrier between fix waves.
- On resume, never restart from scratch if state is valid.

## Completion

The skill is complete for a review run only when:

1. `review-state.json` `status == "complete"`.
2. `fresh_confirmation_pass_done == true`.
3. All backlog items are in `fixed` / `closed` / `waived` / `deferred` (zero `open`).
4. `review-summary.md` exists.
5. At least 2 passes have been executed (`pass_count >= 2`).
