# Step 00: QA Mission Setup

**Goal:** Establish QA scope, product/module under test, available artifacts, tool constraints, target test levels, and output folder. The mission is the contract every later step honors — no risk modeling, test design, oracle design, automation, or execution is allowed before this step is complete and the artifact `00-qa-mission.md` is written.

## Identity contract (HARD)

The orchestrator name `vnpt-qa-tester-orchestrator` is the BMAD skill identity and a platform-wide contract.

- The skill MUST NOT be renamed, aliased, or wrapped under a different name.
- The run id, scope name, and QA output root MUST all reference this identity.

If a future migration needs a bridge to runtime services, that bridge MUST be added explicitly. **This skill does not import, spawn, or HTTP-call any runtime service.**

## Resolution rules

- Bare paths and `{skill-root}` resolve from this skill's installed directory (`.opencode/skills/vnpt-qa-tester-orchestrator/` in consumer repos; `vnpt-bmad-custom/vnpt-qa-tester-orchestrator/` in the monorepo).
- `{project-root}` → the project working directory.
- `{skill-name}` → `vnpt-qa-tester-orchestrator`.
- `{scope}` → the feature, module, or release name passed in by the user or inferred from `$ARGUMENTS` / git diff.

## Sequence

1. **Resolve scope and arguments.** Read `$ARGUMENTS` from `.opencode/commands/vnpt-qa-test-loop.md` if present; otherwise infer scope from `git diff --name-only HEAD~1..HEAD` and the BMAD/project docs structure. If scope remains ambiguous, record `SPEC_AMBIGUITY` and continue with the most likely scope inferred from the diff.

2. **Determine the QA output root.** All project-specific QA outputs MUST go under `docs/qa/<scope>/`. Record the absolute path in `00-qa-mission.md` and use it as the canonical artifact folder for every later step.

3. **Identify the feature/release/module under test.** Capture the name, the product objective, and explicit non-goals.

4. **Identify test levels required.** Mark each of: unit, component, integration, API, E2E, property-based, fuzzing, mutation — as `required`, `optional`, `out-of-scope`, or `infeasible`. Justify every `out-of-scope` / `infeasible` choice with `JUSTIFIED_EXCEPTION`.

5. **Identify available requirement docs.** PRD, epic, story, acceptance criteria, UX, architecture, API spec, DB schema, source files, existing tests/fixtures, README, scripts, package files, known bugs/TODOs. Each item gets an `available`, `partial`, or `missing` flag.

6. **Identify available API schema.** OpenAPI, GraphQL, gRPC proto, internal IDL. If none exists, write `ORACLE_GAP` and mark API fuzz strategy as `infeasible` with reason.

7. **Identify DB / schema / migration files.** Path, format, and whether seeds exist.

8. **Identify supported platforms / browsers / devices.** If unspecified, record `SPEC_AMBIGUITY`.

9. **Identify stack and package manager.** Use `scripts/detect_stack.py` when available, otherwise inspect `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `pom.xml`, `build.gradle`, `go.mod`, `composer.json`, etc.

10. **Identify runnable commands.** For each detected stack, capture the exact test, lint, type-check, build, E2E, mutation, and coverage commands using `config/medium-model-guardrails.yaml` Section 11 as the authoritative source.

11. **Identify known environmental limits.** Timeouts, network access, sandbox restrictions, missing services, missing data fixtures. Each becomes an `ENV_GAP`, `DATA_GAP`, or `TOOL_GAP`.

12. **Define the definition of done.** Reuse the **Completion definition** at the bottom of `ORCHESTRATOR.md`: all required artifacts exist; P0/P1 risks have executable coverage or justified exception; every test has oracle; runnable tests have been executed when environment allows; failures triaged; product bugs have fix briefs; quality gate passes (or explicit conditional/fail with reasons); final QA report exists.

13. **Materialize `docs/qa/<scope>/00-qa-mission.md`** with all the above.

## Required inputs

- outputs from all earlier phases — there are none for step-00; this is the first step.
- the user-supplied scope (or its inferred equivalent).
- the project's top-level layout (`ls -la`, `find . -maxdepth 3 -type f`).
- git status / changed files when available.

## Required work (deliverables for this step)

- feature/release name
- business objective
- in scope / out of scope
- docs / source / API / DB locations
- test stack and package manager
- runnable commands per stack
- environment constraints
- definition of done (mirror of the package-level Completion definition)

## Required output

`docs/qa/<scope>/00-qa-mission.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved for any forward reference
- P0/P1 risks are not silently skipped (no P0/P1 risk claims made yet, but the gate is preserved)
- assumptions and ambiguities are explicitly recorded using the uncertainty label vocabulary

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason (`TOOL_GAP`, `ENV_GAP`, `DATA_GAP`)
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability (introduce `SCOPE-*` prefix in this step if needed).
- Do not count shallow tests as coverage.

## State writes

After this step completes, write `docs/qa/<scope>/qa-state.json`:

```json
{
  "scope": "<scope>",
  "run_id": "<ISO8601 timestamp>",
  "current_step": "step-00-qa-mission",
  "phase_status": "mission_setup",
  "status": "in_progress",
  "qa_mission_path": "docs/qa/<scope>/00-qa-mission.md",
  "scope_artifacts": {
    "00-qa-mission.md": "written",
    "01-context-map.md": "pending",
    "02-risk-map.md": "pending",
    "03-test-strategy.md": "pending",
    "04a-example-test-cases.md": "pending",
    "04b-combinatorial-dimensions.md": "pending",
    "04c-pict-model.pict": "pending",
    "04d-combinatorial-test-matrix.md": "pending",
    "04e-state-model.md": "pending",
    "04f-state-sequence-tests.md": "pending",
    "04g-property-invariants.md": "pending",
    "04h-api-fuzz-plan.md": "pending",
    "04i-exploratory-charter.md": "pending",
    "04j-regression-test-plan.md": "pending",
    "04k-test-data-fixtures.md": "pending",
    "05-test-oracle.md": "pending",
    "06-automation-map.md": "pending",
    "07-test-execution-report.md": "pending",
    "08-failure-triage.md": "pending",
    "09-fix-briefs/": "pending",
    "bug-batches.json": "pending",
    "10-quality-gate-report.md": "pending",
    "10-quality-gate-report.json": "pending",
    "11-final-qa-report.md": "pending"
  },
  "uncertainty_labels_used": [],
  "review_pass_count": 0,
  "last_review_actionable_issues": null
}
```

## Hard stops

- Never generate risk map, test cases, test oracle, or automation until `00-qa-mission.md` exists.
- Never invent scope; if scope is genuinely unclear, record `SPEC_AMBIGUITY` and pick the most defensible inference from `git diff` and BMAD layout.
- Never mark this step complete when the artifact is a generic template; it MUST be project-specific.
- Never silently drop a test level that is `required` from `00-qa-mission.md`.

## Next step

Proceed to `step-01-context-reading.md`. Only load that file when the `00-qa-mission.md` exit criteria above are satisfied. Never load multiple step files simultaneously.
