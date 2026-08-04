---
name: vnpt-triage-bug
description: Investigate bugs and regressions, establish root cause, then fix using a regression-test-first TDD flow.
---

# vnpt-triage-bug

Use this skill when debugging errors, failing tests, user-reported issues, regressions, or production-like incidents.

## Core principle
Triage must not jump straight to a patch. Establish evidence, reproduce the issue, add or propose a regression test, then apply a minimal TDD fix.

## Triage + TDD fix workflow
1. Capture observed behavior, expected behavior, reproduction steps, logs, environment, and affected command/test.
2. Read linked story/PRD/architecture/code from 0-EOF as needed.
3. Map the execution path using source reading; use GitNexus/Serena if available, but verify with direct source.
4. Identify root cause candidates and rank them by evidence.
5. Reproduce the bug with the narrowest possible failing test or command.
6. Add or update a regression test that fails on the current bug.
7. Implement the smallest safe production fix.
8. Run the regression test, then relevant broader validation.
9. State blast radius, changed modules, and remaining risks.

## Guardrails
- Do not patch without evidence when reproduction is possible.
- Do not mark fixed without a regression test or a clear reason why one cannot be added.
- Do not make broad refactors during bug triage unless necessary for the minimal fix.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

