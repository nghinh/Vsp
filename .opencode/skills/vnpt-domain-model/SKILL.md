---
name: vnpt-domain-model
description: Analyze domain entities, business rules, invariants, state transitions, and naming consistency for a project.
---

# vnpt-domain-model

Use this skill when a project has business concepts that must be modeled consistently across PRD, architecture, code, tests, and UI.

## Workflow
1. Read relevant PRD, architecture, stories, ADRs, tests, API contracts, database schema, and code from 0-EOF.
2. Extract core business concepts and relationships.
3. Identify ambiguous naming, overloaded terms, duplicated concepts, and missing invariants.
4. Propose a practical domain model for the current codebase.
5. Map domain rules to tests and validation points.

## Output contract
Prefer writing `docs/domain/domain-model.md`.

## Required sections
Domain overview, entities/value objects/aggregates if applicable, relationships, business rules, invariants, state transitions, naming decisions, open questions, and test implications.

## Guardrails
- Do not over-apply DDD terminology when the project is simple.
- Do not rename core concepts without a migration plan.
- Do not invent domain rules not supported by docs or code evidence.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

