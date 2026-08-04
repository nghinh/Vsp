# vnpt-qa-tester-orchestrator

Independent QA/Test Lead orchestrator for AI-generated software.

This orchestrator is designed to compensate for defects introduced by medium-strength AI coding agents by forcing a structured QA workflow:

1. read full context from 0-EOF;
2. build risk map;
3. design deep test cases;
4. define test oracle;
5. generate automation;
6. run tests;
7. triage failures;
8. generate fix briefs;
9. enforce quality gates.

## Recommended installation path

```text
vnpt-bmad-custom/vnpt-qa-tester-orchestrator/
```

## Core capabilities

- Risk-based QA planning
- Requirement traceability
- Boundary and negative testing
- Combinatorial test design with PICT/ACTS-style models
- State-machine/workflow test design
- Property-based testing with Hypothesis, fast-check, jqwik, FsCheck
- API schema fuzzing with Schemathesis
- Playwright E2E test design
- Test data/fixture design
- Exploratory test charters
- Regression test design
- Mutation gate analysis
- Bug triage and fix brief generation
- Quality gate scoring and release recommendation

## Standard command prompt

```text
Use vnpt-qa-tester-orchestrator for <feature/module>.
Read all relevant PRD/story/architecture/API/source/test files from 0-EOF.
Generate all QA artifacts under docs/qa/<feature>.
Create deep test cases, oracle, automation, execution report, triage, bug batches, quality gate, and final QA report.
Do not fix product code unless explicitly instructed.
```

## Expected project artifacts

```text
docs/qa/<feature>/
├── 00-qa-mission.md
├── 01-context-map.md
├── 02-risk-map.md
├── 03-test-strategy.md
├── 04a-example-test-cases.md
├── 04b-combinatorial-dimensions.md
├── 04c-pict-model.pict
├── 04d-combinatorial-test-matrix.md
├── 04e-state-model.md
├── 04f-state-sequence-tests.md
├── 04g-property-invariants.md
├── 04h-api-fuzz-plan.md
├── 04i-exploratory-charter.md
├── 04j-regression-test-plan.md
├── 04k-test-data-fixtures.md
├── 05-test-oracle.md
├── 06-automation-map.md
├── 07-test-execution-report.md
├── 08-failure-triage.md
├── 09-fix-briefs/
├── bug-batches.json
├── 10-quality-gate-report.md
└── 11-final-qa-report.md
```

## Tooling is optional but preferred

The orchestrator should use installed tools where available. If a tool is missing, it must produce a plan and fallback artifact instead of silently skipping the strategy.

Recommended tools:

- PICT or ACTS for combinatorial testing
- Hypothesis for Python property/stateful tests
- fast-check for JS/TS property tests
- Schemathesis for OpenAPI/GraphQL fuzzing
- Playwright for E2E
- StrykerJS/PIT/Stryker.NET/mutmut/cosmic-ray for mutation testing

## What this orchestrator must not do

- It must not write shallow tests just to increase count.
- It must not use automation before defining oracle.
- It must not confuse smoke tests with QA-grade coverage.
- It must not classify all failures as product bugs without evidence.
- It must not mutate production code unless the user explicitly asks.


## Medium-model strict mode

For Minimax m2.7 or similar models, use the strict profile:

```text
STRICT_QA_RULES_FOR_MEDIUM_MODELS.md
MODEL_BEHAVIOR_CONTRACT.md
config/medium-model-guardrails.yaml
```

Recommended run discipline:

1. Generate `docs/qa/<feature>` scaffold.
2. Fill artifacts in phase order only.
3. Validate with:

```bash
python vnpt-bmad-custom/vnpt-qa-tester-orchestrator/scripts/validate_qa_artifacts.py docs/qa/<feature>
```

4. Do not accept final output if validator fails or if P0/P1 risk traceability is incomplete.

Copy path:

```text
vnpt-bmad-custom/vnpt-qa-tester-orchestrator/
```


## Platform-compatible OpenCode entrypoints

This package includes VNPT/OpenCode-compatible entrypoints:

```text
.opencode/agents/vnpt-qa-tester-orchestrator.md
.opencode/commands/vnpt-qa-test-loop.md
```

After installation, run:

```text
/vnpt-qa-test-loop <feature-or-module-scope>
```

## BMAD docs recursive discovery note

BMAD PRD, architecture, epic, story, UX, API, data, and acceptance-criteria files may be nested anywhere under `docs/`, not only directly under `docs/`. This orchestrator must recursively scan `docs/**`, exclude generated `docs/qa/**` outputs, classify relevant nested files, then read every scope-relevant BMAD doc from 0-EOF before risk modeling, test case design, oracle design, or automation generation.

The required proof is written to `docs/qa/<feature>/01-context-map.md` under `BMAD Docs Inventory and 0-EOF Proof`, including the `Discovery path` column.
