# Phase: 00-qa-mission-setup

## Purpose

Establish QA scope, product/module under test, available artifacts, tool constraints, target test levels, and output folder.

## Required inputs

- outputs from all earlier phases
- relevant project files read from 0-EOF
- current risk map and oracle where applicable

## Required work

- feature/release name
- business objective
- in scope/out of scope
- docs/source/API/DB locations
- test stack and package manager
- runnable commands
- environment constraints
- definition of done

## Required output

`docs/qa/<feature>/00-qa-mission.md`

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
