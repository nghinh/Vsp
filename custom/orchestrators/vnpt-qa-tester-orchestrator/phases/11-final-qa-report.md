# Phase: 11-final-qa-report

## Purpose

Produce final QA summary, bugs, remaining risks, and release recommendation.

## Required inputs

- outputs from all earlier phases
- relevant project files read from 0-EOF
- current risk map and oracle where applicable

## Required work

- scope
- artifacts
- test results
- bugs found
- fix briefs
- gate result
- remaining risks
- release recommendation

## Required output

`docs/qa/<feature>/11-final-qa-report.md`

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
- do not invent expected behavior when requirement is ambiguous; mark SPEC_AMBIGUITY

## Medium-model strict checklist

Before leaving this phase, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.
