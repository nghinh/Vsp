---
name: vnpt-dev-epic-orchestrator
description: Epic-first BMAD orchestrator that discovers epics under docs/, builds dependency-aware waves, dispatches story planning and implementation sub-agents, and enforces the per-epic review gate. Use when the user says "run epic loop", "/vnpt-dev-epic-loop", or wants to execute all epics in a project.
version: "2.0.0"
configPath: '{project-root}/_bmad/bmm/config.yaml'
outputFolder: '{output_folder}/epic-orchestrator'
---

# vnpt-dev-epic-orchestrator

This skill helps you deliver an entire project epic by epic. Act as the epic-first orchestrator, guiding the run through context intake, epic discovery, dependency-aware wave planning, sequential epic execution, and a mandatory per-epic review gate. The output is a populated `docs/vnpt-flow/epic-run-<run-id>/` tree plus a clean review-verified epic summary.

## Identity contract (HARD)

The orchestrator name `vnpt-dev-epic-orchestrator` is a **hard runtime contract** with `vnpt-go-runtime`:
- The runtime stamps this value into `producer`/`Producer` fields on checkpoints, handoffs, and continuation capsules.

Do **not** rename, alias, or override this value. Any change here is a cross-repo contract change requiring a coordinated migration.

## Runtime non-coupling

This skill does **not** import, spawn, or HTTP-call `vnpt-go-runtime`. The two layers are intentionally decoupled:

- `vnpt-go-runtime` owns the batch epic execution state machine (`docs/flow-contract-run-epics.md`).
- `vnpt-dev-epic-orchestrator` owns the epic inventory, story dispatch waves, and the BMAD-aligned review gate.

If a future migration needs the orchestrator to drive runtime execution, the bridge must be added explicitly. **This migration does not introduce such a bridge.**

## Resolution rules

- Bare paths and `{skill-root}` resolve from this skill's installed directory (`.opencode/skills/vnpt-dev-epic-orchestrator/` in consumer repos; `vnpt-bmad-custom/vnpt-dev-epic-orchestrator/` in the monorepo).
- `{project-root}` → the project working directory.
- `{skill-name}` → `vnpt-dev-epic-orchestrator`.

## On Activation

1. **Load config** from `{project-root}/_bmad/config.yaml` and `{project-root}/_bmad/bmm/config.yaml`. Resolve `user_name`, `communication_language`, `document_output_language`, `output_folder`, `planning_artifacts`, `implementation_artifacts`. Communicate in `{communication_language}`; generate documents in `{document_output_language}`.

2. **Resolve customization** (optional). Run `python3 {project-root}/_bmad/scripts/resolve_customization.py --skill {skill-root} --key workflow`. If unavailable, read `{skill-root}/customize.toml` directly and apply defaults. Honor `{workflow.persistent_facts}` as standing context and execute `{workflow.activation_steps_prepend}` / `{workflow.activation_steps_append}`.

3. **Detect intent** from invocation keywords:
   - `Create`: user says "run epic loop", "/vnpt-dev-epic-loop", or no intent cue → load `steps-c/step-01-intake.md`.
   - `Resume`: user says "resume", "continue", "pick up where we left off" → check `{epic_run_folder}/epic-state.json`; if status not `done`, route to `steps-c/step-02-resume.md` (or build it if missing — fall back to step 1 in headless mode).

4. **Route to first step** per intent above. Each step file owns its own read → execute → write-state → next-step loop. Never load multiple step files simultaneously.

## Intents

| Intent | What it does | Load |
| --- | --- | --- |
| Create | New epic run from intake to wrapup | `steps-c/step-01-intake.md` |
| Resume | Continue from `epic-state.json` resume pointer | `steps-c/step-02-resume.md` (or build from `step-01`) |

## Sub-agents (required)

- `vnpt-epic-story-runner` — planning + quality gate per story. Never implements slices.
- `vnpt-epic-story-implementer` — slice implementation with the shared dedup gate enforced.

Both sub-agents are loaded as OpenCode agents from `.opencode/agents/`. They are **not** BMAD skills; do not bulk-load skills at the epic layer.

## Key references

- `references/state-machine.md` — epic and phase state transitions
- `references/epic-artifact-schema.md` — schema for all `epic-run-<run-id>/` artifacts
- `data/orchestrator-policy.json` — status values, severity classes, source order
- `data/orchestrator-rules.md` — hard stops and non-negotiable rules

Wave-planning rules, review-gate contract, and per-step prompts are inlined directly in `steps-c/step-*.md` (the runtime is a separate Go service that owns its own review-gate and state machine; the orchestrator only ships the BMAD-aligned step instructions).

## Runtime policy

State values, severity classes, and source-order preferences are pinned in `data/orchestrator-policy.json`. The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret these values mid-run.

## Hard stops (NON-NEGOTIABLE)

See `data/orchestrator-rules.md` for the full list. Top-level summary:

- Never run epics in parallel — sequential only.
- Never run dependent or overlapping stories in the same wave.
- Never run dependent or overlapping slices in the same slice wave.
- Independent stories/slices MAY run in parallel in the same wave (one sub-agent per item).
- A story wave of size > 1 with independent stories MUST spawn one `vnpt-epic-story-runner` per story.
- A slice wave of size > 1 with independent slices MUST spawn one `vnpt-epic-story-implementer` per slice.
- After each slice wave, MUST wait for all implementers to finish before starting the next slice wave.
- On resume, do not collapse remaining pending stories to sequential execution without explicit dependency/overlap evidence.
- Never dispatch sub-agents without a populated `REQUIRED CONTEXT READING` file list.
- Never mark an epic done while the latest `/vnpt-review-loop` pass has actionable issues.
- Never bypass the missing-epics gate by inferring epics.
- Never allow token/context pressure to downgrade implementation quality.
- Never rename or alias the orchestrator identity `vnpt-dev-epic-orchestrator`.

## Completion

The skill is complete for a project only when:

1. All epics in `execution-order.md` have status `done` or are explicitly marked `stalled_partial` with `forensics.md`.
2. `epic-summary.md` exists for every epic.
3. The latest `/vnpt-review-loop` pass per epic reports zero actionable issues.
4. `failure-backlog.md` either is empty or has actionable retry recommendations.
5. Final `epic-summary.md` (aggregate) is written.
