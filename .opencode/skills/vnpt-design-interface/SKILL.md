---
name: vnpt-design-interface
description: Design API/module/interface boundaries by comparing alternatives and trade-offs before implementation.
---

# vnpt-design-interface

Use this skill before implementing important APIs, service interfaces, module contracts, adapters, or integration boundaries.

## Workflow
1. Read relevant PRD, architecture, story, ADR, and existing code from 0-EOF.
2. Identify consumers, providers, data ownership, failure modes, and lifecycle constraints.
3. Generate at least two viable interface designs when the decision is non-trivial.
4. Compare trade-offs: simplicity, coupling, extensibility, testability, versioning, security, observability, and migration cost.
5. Recommend one option with rationale and implementation notes.

## Output contract
Prefer writing `docs/architecture/interface-design.md`. For local decisions, include the design in the relevant story/ADR instead.

## Guardrails
- Do not design abstractions without a real consumer.
- Do not hide business rules behind vague generic interfaces.
- Do not create premature framework layers.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

