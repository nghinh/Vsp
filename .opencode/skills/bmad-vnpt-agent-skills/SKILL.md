---
name: bmad-vnpt-agent-skills
description: VNPT BMAD agent skills umbrella skill for selecting focused engineering skills without replacing existing orchestrators.
---

# bmad-vnpt-agent-skills

Use this umbrella skill only to choose the right focused skill from this package.

## Available focused skills
- `vnpt-generate-prd`: create or refine PRD/spec input for BMAD.
- `vnpt-tdd`: isolated red-green-refactor implementation for core logic, bug fix, or refactor.
- `vnpt-triage-bug`: investigate bug/root cause and fix with regression-test-first flow.
- `vnpt-improve-architecture`: review codebase architecture and create safe refactor plan.
- `vnpt-design-interface`: design interface/API/module boundary alternatives.
- `vnpt-domain-model`: analyze domain entities, rules, state transitions, and invariants.
- `vnpt-qa-review`: QA review, risk-based test strategy, and quality gate check.

Do not use as a replacement for BMAD Epic/Story generation, `bmad-dev-story`, VNPT review/test orchestrators, or long-running autonomous loops.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

