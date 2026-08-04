---
name: vnpt-generate-prd
description: Generate or refine a BMAD-aligned PRD from requirements, notes, existing docs, and repository evidence.
---

# vnpt-generate-prd

Use this skill when the user asks to create, refine, or normalize a product requirement document for a project.

## Workflow
1. Collect provided requirements and identify missing context.
2. Read relevant existing docs from 0-EOF: `docs/prd*`, `docs/architecture*`, `docs/epics/*`, `docs/stories/*`, `docs/adr/*`, and domain notes when present.
3. Inspect repository structure only when the PRD must reflect an existing codebase.
4. Draft or update the PRD with goals, non-goals, users, scope, functional requirements, non-functional requirements, acceptance criteria, risks, dependencies, and open questions.
5. Avoid decomposing into implementation issues/stories; leave that to BMAD Epic/Story flow.

## Output contract
Prefer writing or updating `docs/prd.md`. If the project already uses versioned PRD files, follow the existing naming convention.

## Guardrails
- Do not invent business decisions that are not supported by the prompt or existing docs.
- Do not silently change scope; state assumptions clearly.
- Do not create GitHub issues or BMAD stories from this skill.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

