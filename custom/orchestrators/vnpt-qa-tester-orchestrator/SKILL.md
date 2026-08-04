---
name: vnpt-qa-tester-orchestrator
description: BMAD-aligned QA/Test Lead orchestrator that runs a 12-step pipeline (mission → context → risk → strategy → design → oracle → automation → execution → triage → briefs → gate → final report) and emits a machine-readable JSON gate report. Use when the user says "run QA loop", "/vnpt-qa-test-loop", or wants deep QA-grade test cases, automation, execution, fix briefs, and a release recommendation.
version: "2.0.0"
configPath: '{project-root}/_bmad/bmm/config.yaml'
outputFolder: '{output_folder}/qa-orchestrator'
---

# vnpt-qa-tester-orchestrator

This skill runs a complete QA/Test Lead cycle for a single feature, module, or release scope. Act as the QA orchestrator, guiding the run through BMAD-aware context reading, risk modeling, strategy routing, test case design, oracle design, automation generation, test execution, failure triage, fix-brief generation, the quality gate, and a final QA report with a release recommendation. The output is a populated `docs/qa/<scope>/` tree plus a validated `10-quality-gate-report.json`.

## Identity contract (HARD)

The skill name `vnpt-qa-tester-orchestrator` is the BMAD skill identity.

- The skill MUST NOT be renamed, aliased, or wrapped under a different name.
- The run id, scope name, and QA output root MUST all reference this identity.

If a future migration needs the orchestrator to drive runtime execution, that bridge MUST be added explicitly. **This skill does not import, spawn, or HTTP-call any runtime service.**

## Resolution rules

- Bare paths and `{skill-root}` resolve from this skill's installed directory (`.opencode/skills/vnpt-qa-tester-orchestrator/` in consumer repos; `vnpt-bmad-custom/vnpt-qa-tester-orchestrator/` in the monorepo).
- `{project-root}` → the project working directory.
- `{skill-name}` → `vnpt-qa-tester-orchestrator`.
- `{scope}` → the feature, module, or release name passed in by the user or inferred from `$ARGUMENTS` / git diff.

## On Activation

1. **Load config** from `{project-root}/_bmad/config.yaml` and `{project-root}/_bmad/bmm/config.yaml`. Resolve `user_name`, `communication_language`, `document_output_language`, `output_folder`, `planning_artifacts`, `implementation_artifacts`. Communicate in `{communication_language}`; generate documents in `{document_output_language}`.

2. **Resolve customization** (optional). If a customization resolver exists, apply `workflow.persistent_facts` as standing context and execute `workflow.activation_steps_prepend` / `workflow.activation_steps_append`. If unavailable, proceed with the embedded contract below.

3. **Detect intent** from invocation keywords and resume state:
   - **Create** (default): user says "run QA loop", "/vnpt-qa-test-loop", or no resume state → load `steps/step-00-qa-mission.md`.
   - **Resume**: `qa-state.json` exists with `qa_run_status != "done"` and a non-empty `current_step` → jump directly to `steps/step-<current_step>.md`. If `qa-state.json` is missing but `docs/qa/<scope>/` exists, scan `scope_artifacts` for the last `written` artifact and route to the next step.

4. **Route to first step** per intent above. Each step file owns its own read → execute → write-state → next-step loop. Never load multiple step files simultaneously.

## Intents

| Intent | What it does | Load |
|---|---|---|
| Create | New QA run from mission to final report | `steps/step-00-qa-mission.md` |
| Resume | Continue from `qa-state.json` resume pointer | `steps/step-<current_step>.md` |

## Sub-agents

This skill does not spawn sub-agents. It is a single-agent pipeline that walks the user through 12 deterministic steps in order. State is tracked in `qa-state.json` for full resumability.

## Key references

- `references/qa-state-machine.md` — phase lifecycle, QA-run lifecycle, gate lifecycle, failure reason classes
- `references/qa-artifact-schema.md` — schemas for `qa-state.json`, `bug-batches.json`, `10-quality-gate-report.json`, and the recommended artifact tree
- `data/qa-orchestrator-policy.json` — pinned values (phase states, gate results, score weights, priority, taxonomy, uncertainty labels, M2.7 constraints)
- `data/qa-orchestrator-rules.md` — hard stops and non-negotiable rules
- `steps/step-00-qa-mission.md` … `steps/step-11-final-qa-report.md` — 12 step files for the linear QA pipeline

## Runtime policy

State values, gate results, score weights, priority values, taxonomy, uncertainty labels, and MiniMax M2.7 constraints are pinned in `data/qa-orchestrator-policy.json`. The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret these values mid-run.

## Hard stops (NON-NEGOTIABLE — summary)

See `data/qa-orchestrator-rules.md` for the full list. Top-level summary:

- Never generate risk map, test cases, test oracle, or automation before `00-qa-mission.md` exists.
- Never generate risk map, test cases, test oracle, or automation before the BMAD docs hard gate is satisfied.
- Never write executable tests before `05-test-oracle.md` exists.
- Never classify a concurrency failure as `FLAKY_TEST`.
- Never classify a security failure as `TEST_BUG`.
- Never accept an oracle whose expected result is not binary or measurable.
- Never use `page.screenshot()` or any image-based evidence (M2.7 constraint).
- Never silently skip a strategy because a tool is unavailable — write `TOOL_GAP` with the exact planned command.
- Never accept a property-based test that is random-only — it MUST encode invariants.
- Never accept a state model without forbidden transitions when the feature has states.
- Never ship a fix brief that lacks `risk_ids`, `failed_test_ids`, or `oracle_ids`.
- Never accept a `pass` gate result when any hard-fail rule fires.
- Never claim run completion when any item in the **Completion definition** is false.

## Completion

The skill is complete for a scope only when:

1. all required artifacts exist;
2. P0/P1 risks have executable coverage or justified exception;
3. every test has oracle;
4. runnable tests have been executed when environment allows;
5. failures have been triaged;
6. product bugs have fix briefs;
7. quality gate is pass or explicit conditional/fail with reasons;
8. final QA report exists.

The mapping from gate result to release recommendation is pinned in `data/qa-orchestrator-policy.json` → `releaseRecommendations`:

| Gate result | Release recommendation |
|---|---|
| `pass` | GO |
| `conditional_pass` | CONDITIONAL_GO |
| `fail` | NO_GO |

## Companion documents (preserved)

The package retains the legacy contract documents that earlier agents and scripts reference. They are not the BMAD manifest — `SKILL.md` (this file), `workflow.md`, and the `steps/` files are. The legacy documents remain authoritative for their subject matter:

- `ORCHESTRATOR.md` — full inline workflow spec (preserved verbatim for reference; the BMAD-conformant equivalent is `workflow.md`).
- `STRICT_QA_RULES_FOR_MEDIUM_MODELS.md` — strict QA rules for medium models (reference summary; authoritative config: `config/medium-model-guardrails.yaml`).
- `MODEL_BEHAVIOR_CONTRACT.md` — response style contract (reference summary; authoritative config: `config/medium-model-guardrails.yaml`).
- `BMAD_DOCS_CONTEXT_READING_CONTRACT.md` — BMAD docs recursive discovery contract (authoritative for step 01).
- `INSTALL_IN_PLATFORM.md` — manual install instructions for VNPT platform.
- `README.md` — package overview and recommended usage.
- `phases/` — legacy per-phase files (preserved for backward compatibility; canonical per-step instructions are in `steps/`).
- `config/` — YAML configuration (authoritative for stack templates, gate weights, M2.7 constraints, risk taxonomy).
- `schemas/` — JSON schemas (authoritative for `bug-batches.json`, `qa-artifacts-manifest`, `test-data-fixtures`).
- `scripts/` — Python scripts (collect context, detect stack, run PICT, run Schemathesis, run quality gate, run mutation gate, validate artifacts, generate scaffolds).
- `templates/` — Markdown / JSON templates for every artifact.
- `runtime/` — runtime harness integration (checkpoints, decision requests, governance).
- `skills/` — supporting per-strategy skill folders (preserved as the legacy per-strategy decomposition).
- `tests/` — Python tests for guardrails.
- `examples/` — example QA outputs (warehouse packing station).
- `.opencode/agents/vnpt-qa-tester-orchestrator.md` — OpenCode agent entrypoint.
- `.opencode/commands/vnpt-qa-test-loop.md` — `/vnpt-qa-test-loop` command entrypoint.
