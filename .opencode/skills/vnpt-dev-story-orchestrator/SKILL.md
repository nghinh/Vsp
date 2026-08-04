---
name: vnpt-dev-story-orchestrator
description: Story-first BMAD orchestrator that discovers story status, builds slice/wave plans, dispatches implementation sub-agents, and enforces the quality gate via /vnpt-review-loop. Use when the user says "/vnpt-dev-story-loop <story-id>" or wants to execute a single story through discovery, planning, implementation, and review.
version: "2.0.0"
outputFolder: '{output_folder}/story-orchestrator'
---

# vnpt-dev-story-orchestrator

This skill delivers a single story through discovery, planning, implementation, and quality gate. The orchestrator discovers story status, builds dependency-aware slice plans, dispatches bounded-scope implementation, and enforces the per-story review gate using `/vnpt-review-loop`.

## Identity contract (HARD)

The orchestrator name `vnpt-dev-story-orchestrator` is a **hard runtime contract**:
- The orchestrator stamps this value into `producer` fields on checkpoints and handoffs.
- Do **not** rename, alias, or override this value.

## Resolution rules

- `{skill-root}` resolves from skill's installed directory
- `{project-root}` → the project working directory
- `{story-id}` → target story identifier

## On Activation

1. **Load config** from `{project-root}/_bmad/config.yaml`. Resolve `communication_language`, `document_output_language`, `output_folder`.

2. **Detect intent:**
   - `Create`: new story run from discovery to wrapup
   - `Resume`: continue from `phase-state.json` resume pointer

3. **Route to step** per intent.

## Intents

| Intent | What it does | Load |
| --- | --- | --- |
| Create | New story run | `steps/step-01-discovery.md` |
| Resume | Continue from `phase-state.json` | `steps/step-02-resume.md` |

## Sub-agents (required)

- `vnpt-story-runner` — discovery and planning. Never implements slices.
- `vnpt-story-implementer` — slice implementation with the shared dedup gate enforced.

## Story Status Routing

| BMAD Status | Routing | Action |
|---|---|---|
| `done` | Skip | Do not spawn; mark as `skipped` |
| `ready-for-dev` | Planning | Build plan, execute waves, quality gate |
| `in-progress` | Planning | Resume from checkpoint, continue |
| `review` | Quality Gate | Skip to review/fix loop only |

## Wave Execution

- Independent slices with no write-path overlap → same wave, may parallelize
- Dependent or overlapping slices → sequential execution
- After each slice wave, MUST wait for all implementers to finish

## Quality Gate

Uses `/vnpt-review-loop` (same as original and epic pattern):
1. Generate `review-handoff.md`
2. Run `/vnpt-review-loop docs/vnpt-flow/<story-id>/review-handoff.md`
3. If issues found → fix → re-review → loop until clean or stalled

## Hard Stops (NON-NEGOTIABLE)

- Never process more than one story per run.
- Never dispatch implementer without populated `REQUIRED CONTEXT READING`.
- Never mark story done while latest `/vnpt-review-loop` pass has actionable issues.
- Never skip the dedup protocol for any write operation.
- Never parallelize slices with overlapping write scopes.
- Never skip writing required run artifacts.
- Never report done while `validation-report.md` has unresolved failures.

## Completion

The skill is complete only when:
1. Story status is `done`
2. All acceptance criteria are mapped and implemented
3. Validations are clean
4. Latest `/vnpt-review-loop` pass reports zero actionable issues
5. `phase-state.json` status is `done`
