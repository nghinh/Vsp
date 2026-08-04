---
name: vnpt-sec-review-orchestrator
description: Security-first review/fix loop orchestrator for VNPT. Use when the user says "/vnpt-sec-review-loop", "run security review", or wants to execute a security review/fix cycle.
version: "1.0.0"
configPath: '{project-root}/_bmad/bmm/config.yaml'
outputFolder: '{output_folder}/sec-review-orchestrator'
---

# vnpt-sec-review-orchestrator

This skill drives a security-first review/fix loop for VNPT projects. Act as the security orchestrator, guiding the run through preflight scope validation, recursive BMAD docs discovery, security risk mapping, parallel auditor passes, non-overlapping fix waves, targeted stack validation, and a mandatory confirmation review gate.

## Identity contract (HARD)

The orchestrator name `vnpt-sec-review-orchestrator` is a **hard runtime contract**:
- Do **not** rename, alias, or override this value.

## Resolution rules

- Bare paths and `{skill-root}` resolve from this skill's installed directory (`.opencode/skills/vnpt-sec-review-orchestrator/`).
- `{project-root}` → the project working directory.
- `{skill-name}` → `vnpt-sec-review-orchestrator`.

## On Activation

1. **Load config** from `{project-root}/_bmad/bmm/config.yaml`. Resolve `user_name`, `communication_language`, `document_output_language`, `output_folder`, `planning_artifacts`, `implementation_artifacts`. Communicate in `{communication_language}`; generate documents in `{document_output_language}`.

2. **Resolve customization** (optional). Read `{skill-root}/customize.toml` and apply defaults. Honor `{workflow.persistent_facts}` as standing context and execute `{workflow.activation_steps_prepend}` / `{workflow.activation_steps_append}`.

3. **Detect intent** from invocation keywords:
   - `/vnpt-sec-review-loop`, "run security review", or no intent cue → load `steps/step-01-preflight.md`.
   - "resume", "continue", "pick up where we left off" → check `security-review-state.json`; if status not `complete`, route to the step matching the current `status` field.

4. **Route to first step** per intent above. Each step file owns its own read → execute → write-state → next-step loop. Never load multiple step files simultaneously.

## Workflow architecture

Uses **step-file architecture** under `steps/`:
- `step-01-preflight.md` — scope resolution, tooling validation, schema init
- `step-02-context-discovery.md` — recursive BMAD docs inventory, 0-EOF proof
- `step-03-security-map.md` — stack detection, lane routing
- `step-04-review-pass.md` — parallel auditor dispatch, merge/dedup findings
- `step-05-fix-waves.md` — non-overlapping fix workers by wave
- `step-06-validate.md` — targeted stack validation
- `step-07-fresh-review.md` — fresh re-review loop until clean
- `step-08-confirmation.md` — mandatory confirmation pass and final gate

## Sub-agents (required)

- `vnpt-sec-review-auditor` — parallel security review worker per lane/family. Never edits files.
- `vnpt-sec-fix-worker` — parallel security fix worker per non-overlapping write wave.

Both sub-agents are loaded as OpenCode agents from `.opencode/agents/`. They are **not** BMAD skills.

## Key references

- `references/state-machine.md` — workflow state transitions
- `data/orchestrator-rules.md` — hard stops and non-negotiable rules
- `data/orchestrator-policy.json` — status values, severity classes, source order

Wave-planning rules, evidence standards, and per-step prompts are inlined directly in `steps/step-*.md`.

## Runtime policy

Status values, severity classes, and source-order preferences are pinned in `data/orchestrator-policy.json`. The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret these values mid-run.

## Completion

The skill is complete only when:
1. All review passes have completed and zero actionable issues remain.
2. The mandatory confirmation review has run with zero issues (`fresh_confirmation_pass_done: true`).
3. The bundled `validate_security_artifacts.py` passes.
4. `security-summary.md` is written under `docs/vnpt-flow/<scope-id>/security-review/`.
