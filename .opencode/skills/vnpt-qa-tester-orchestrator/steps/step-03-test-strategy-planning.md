# Step 03: Test Strategy Planning

**Goal:** Route every risk to one or more executable strategies: example, combinatorial, state-machine, property, API fuzz, E2E, exploratory, mutation, regression. The strategy map is the contract between the risk model and the test case design — every `RISK-*` MUST have at least one strategy before step-04 begins.

## Prerequisites

- `02-risk-map.md` exists with prioritized risks.
- `qa-state.json` `phase_status = "risk_modeling"`.

## Sequence

### Step 3.1 — Apply routing rules

For every `RISK-*`, pick one or more strategies using the canonical routing rules:

| Signal | Strategy |
|---|---|
| Many interacting parameters | Combinatorial (PICT/ACTS-style) |
| Lifecycle / workflow / state machine | State-machine |
| Input domain / validation / data transforms | Property-based |
| OpenAPI/GraphQL schema exists | API schema fuzzing (Schemathesis) |
| User-critical path / UI state | Playwright E2E |
| Known-bug area or recently changed code | Regression |
| High coverage but low confidence | Mutation testing |
| Ambiguous / manual-experience area | Exploratory charter |

For each routing, also pick the tool, the artifact (which file under `04*-`), and the execution feasibility. If a strategy is infeasible, write a `JUSTIFIED_EXCEPTION` with concrete reason and a fallback artifact.

### Step 3.2 — Verify minimum coverage per risk

For every P0 risk, at least:

- 1 happy-path test (if a happy path exists)
- 2 negative tests
- 2 boundary / edge tests
- 1 recovery / error-path test (when failures are possible)
- 1 state-machine test (when the feature has states)
- 1 property / invariant test (when validation, transformation, quantity, ordering, money, inventory, status, or idempotency exists)
- 1 E2E / API test (for externally visible behavior)

For every P1 risk, at least:

- 1 happy or main-path test
- 1 negative test
- 1 boundary / edge test
- state / property / API / E2E coverage when applicable

If any of the above is not feasible, attach `JUSTIFIED_EXCEPTION` with concrete reason and fallback.

### Step 3.3 — Verify the strategy set is executable

For every strategy:

- tool: known installed OR `TOOL_GAP` with the exact planned command.
- artifact path: known file under `04a-04k`.
- runnable command: from `config/medium-model-guardrails.yaml` Section 11 stack-specific templates.

### Step 3.4 — Order strategies by priority

Produce the strategy execution order — which strategies run in step-04, which run in step-06, which run only in step-07. The order is deterministic given the risk map and is recorded in `03-test-strategy.md`.

### Step 3.5 — Write `docs/qa/<scope>/03-test-strategy.md`

The file MUST contain:

- per-risk strategy table: `RISK-* | strategies | tool | artifact | feasibility | JUSTIFIED_EXCEPTION | source references`
- a summary of executable vs infeasible strategies
- the canonical strategy execution order for downstream steps
- forward pointers to step-04 (test case design) and step-05 (oracle design)

## Required inputs

- outputs from earlier phases — `02-risk-map.md`.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — risk map is the current input.

## Required work (deliverables for this step)

- risk to strategy mapping
- tool choice
- artifact output path per strategy
- automation feasibility + fallback
- priority order

## Required output

`docs/qa/<scope>/03-test-strategy.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped — every P0/P1 risk has at least one strategy
- assumptions and ambiguities are explicitly recorded

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## State writes

Update `qa-state.json`:

```json
{
  "current_step": "step-03-test-strategy-planning",
  "phase_status": "test_strategy_planning",
  "scope_artifacts": {
    "03-test-strategy.md": "written"
  },
  "strategy_summary": {
    "executable_strategies": ["example", "combinatorial", "state-machine", "property", "api-fuzz", "e2e", "exploratory", "regression", "mutation"],
    "infeasible_strategies": [{"strategy": "<name>", "reason": "<JUSTIFIED_EXCEPTION>", "fallback": "<artifact>"}],
    "execution_order": ["step-04-test-case-design", "step-05-test-oracle-design", "step-06-test-automation-generation", "step-07-test-execution"]
  }
}
```

## Hard stops

- Never proceed to step-04 when any P0 risk has zero strategies.
- Never silently drop a strategy because a tool is missing — write `TOOL_GAP` and the exact planned command.
- Never accept a strategy map that is generic; it MUST reference concrete `RISK-*` IDs.
- Never collapse a multi-strategy routing into a single strategy without justification.

## Next step

Proceed to `step-04-test-case-design.md`. Only load that file when the strategy exit criteria above are satisfied. Never load multiple step files simultaneously.
