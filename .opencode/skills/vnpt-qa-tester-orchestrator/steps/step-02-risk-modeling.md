# Step 02: Risk Modeling

**Goal:** Build a risk map with impact, likelihood, priority, test strategy, and required test level. The risk map is the input every later step references — strategies, test cases, oracle, automation, and the quality gate all derive from this single document.

## Prerequisites

- `00-qa-mission.md` exists with the scope and required test levels.
- `01-context-map.md` exists with BMAD hard-gate `true` or documented `JUSTIFIED_EXCEPTION`.

## Sequence

### Step 2.1 — Enumerate risks using the canonical 12-family taxonomy

Apply the risk taxonomy from `config/risk-taxonomy.yaml`:

- R1 Business-critical flow — checkout, packing, replenishment, assignment, payment, approval, mission dispatch.
- R2 Data corruption / data loss — duplicate records, lost update, wrong quantity, stale state, broken idempotency.
- R3 State-transition / lifecycle bug — cancelled to completed, completed to pending, retry loops, invalid terminal transition.
- R4 Permission / security boundary — unauthorized action, missing tenant isolation, data exposure.
- R5 Invalid input / boundary value — null, empty, negative, zero, huge, decimal, malformed, unicode, timezone.
- R6 Offline / online / network failure — timeout, retry, reconnect, partial failure, duplicate sync.
- R7 Concurrency / duplicate event / race condition — double click, parallel request, duplicate assignment, lost update.
- R8 Integration / API contract failure — wrong status code, response schema mismatch, missing field, nullable mismatch.
- R9 UI misoperation / UX state error — wrong disabled state, stale display, confusing error, loading stuck.
- R10 Regression-prone / recently changed area — recently changed file, previous bug, TODO, fragile logic.
- R11 Performance / timeout risk — slow query, debounce failure, background job delay, large data set.
- R12 Observability / diagnosability gap — missing log, no error ID, no trace, silent failure.

For each risk that touches the scope, derive concrete risk instances from the BMAD context, the source code, and the existing tests. Assign each risk a stable `RISK-*` ID.

### Step 2.2 — Score and prioritize each risk

For every risk instance:

- impact: `critical | high | medium | low`
- likelihood: `high | medium | low`
- priority: `P0 | P1 | P2 | P3`
- required test level: `unit | component | integration | API | E2E | property | fuzz | mutation | exploratory | regression`
- candidate strategies (the strategy picker lives in step-03, but record rough hints here)

### Step 2.3 — Apply the required-bug-class sweep

For every feature, explicitly mark `Applicable`, `Not applicable`, or `Gap` for:

- state transition
- validation
- boundary / off-by-one
- null / empty / missing field
- duplicate action / event / request
- timeout / retry / cancel
- concurrency / rapid repeat
- persistence mismatch
- stale / wrong UI state
- API contract mismatch
- error handling
- regression around changed files
- security / permission when relevant
- offline / online / network when relevant
- performance / large data when relevant

### Step 2.4 — Apply the extended bug-class sweep (v2.0)

Mark `Applicable`, `Not applicable`, or `Gap` for each of:

- race condition
- deadlock / livelock
- data race
- atomicity violation
- ordering violation
- memory leak
- authorization bypass
- input validation bypass
- state corruption
- idempotency violation

### Step 2.5 — Capture ambiguity and gap labels

For each risk where impact cannot be proven, attach one of the uncertainty labels: `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, `JUSTIFIED_EXCEPTION`. Never invent impact.

### Step 2.6 — Write `docs/qa/<scope>/02-risk-map.md`

The file MUST contain:

- per-risk table with `id | family | description | impact | likelihood | priority | required test levels | applicable bug classes | ambiguity labels | source references`
- summary count of `P0 / P1 / P2 / P3` risks
- list of `P0/P1` risks that have no obvious source-doc backing (these get a `SOURCE_DERIVED_RISK` label)
- explicit forward-pointer to step-03-test-strategy

## Required inputs

- outputs from earlier phases — `00-qa-mission.md` (scope, test levels) and `01-context-map.md` (BMAD proof).
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — the risk map from this step is the new current.

## Required work (deliverables for this step)

- business-critical flows
- data corruption
- state transitions
- permission boundaries
- invalid / boundary input
- offline / network failure
- concurrency / duplicate events
- API / integration failure
- UI misoperation
- regression-prone areas
- performance / timeout risks
- observability gaps

## Required output

`docs/qa/<scope>/02-risk-map.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
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
  "current_step": "step-02-risk-modeling",
  "phase_status": "risk_modeling",
  "scope_artifacts": {
    "02-risk-map.md": "written"
  },
  "risk_summary": {
    "p0_count": <int>,
    "p1_count": <int>,
    "p2_count": <int>,
    "p3_count": <int>,
    "uncovered_p0_risks": []
  }
}
```

## Hard stops

- Never claim `coverage` for a P0/P1 risk without an executable test or `JUSTIFIED_EXCEPTION` (deferred to step 10, but the rule is enforced from this step forward).
- Never invent a risk priority; priorities MUST come from impact × likelihood.
- Never accept a risk map that only contains the 12 family names; it MUST contain concrete `RISK-*` instances.
- Never mark this step complete when the risk map is generic.
- Never silently merge two distinct risk IDs into one; each risk gets its own `RISK-*`.

## Next step

Proceed to `step-03-test-strategy-planning.md`. Only load that file when the risk map exit criteria above are satisfied. Never load multiple step files simultaneously.
