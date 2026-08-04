---
name: vnpt-improve-architecture
description: Review codebase architecture and produce safe, incremental architecture improvement/refactor plans.
---

# vnpt-improve-architecture

Use this skill to identify architecture issues and propose safe refactor plans for an existing codebase.

## Scope
Module boundaries, dependency direction, layering violations, interface/adapter seams, coupling/cohesion/locality, testability, observability, and architecture drift against BMAD architecture docs and LikeC4 artifacts.

## Workflow
1. Read `docs/architecture*`, `docs/adr/*`, LikeC4 files, and relevant PRD/story docs from 0-EOF.
2. Inspect repository structure, imports, key modules, and current tests.
3. Identify concrete architecture smells with file-level evidence.
4. Classify each finding by severity, risk, and expected payoff.
5. Propose an incremental refactor plan in small safe steps.
6. Include validation strategy and rollback/safety checks.

## Output contract
Prefer writing `docs/architecture/architecture-improvement-plan.md`; if that folder does not exist, use `docs/architecture-improvement-plan.md`.

## Guardrails
- Do not propose a big-bang rewrite.
- Do not move files only for aesthetics.
- Do not break existing conventions unless the benefit is explicit and validated.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

