---
name: vnpt-qa-review
description: Perform QA review, risk-based test analysis, and quality gate checks without replacing VNPT test orchestrators.
---

# vnpt-qa-review

Use this skill for focused QA review, risk-based test strategy, acceptance criteria review, and quality gate assessment.

## Position in VNPT framework
This skill supports QA thinking. It does not replace VNPT test orchestrator, VNPT test hardening loop, Playwright automation generation workflow, or BMAD story acceptance criteria generation.

## Workflow
1. Read PRD, architecture, epics, stories, acceptance criteria, existing test reports, and relevant source/tests from 0-EOF.
2. Identify risk areas by business criticality, complexity, integration points, security, data integrity, and regression likelihood.
3. Review existing tests against acceptance criteria and likely edge cases.
4. Find gaps, weak assertions, flaky areas, missing negative cases, and missing integration boundaries.
5. Recommend targeted test improvements and quality gates.

## Output contract
Prefer writing `docs/testing/qa-review-report.md`.

## Guardrails
- Do not inflate test count with trivial variants.
- Do not claim coverage without evidence.
- Do not duplicate test orchestrator output; focus on reasoning, gaps, and risk.

## VNPT operating rules
- Treat BMAD documents under `docs/` as primary project context when present: PRD, architecture, epics, stories, ADRs, test reports, domain notes, and LikeC4 files.
- Before making conclusions from any markdown/source file, read the needed file from 0-EOF. For long files, first check total line count, then read complete chunks until EOF.
- Prefer small, reviewable, repository-aware changes. Do not invent broad scope that is not supported by local docs or source evidence.
- Preserve existing framework conventions: `.opencode/skills/*`, `.opencode/commands/*`, `docs/`, `docs/stories/`, `docs/epics/`, `docs/adr/`, `docs/domain/`, and `docs/testing/`.
- When outputting artifacts, write clear markdown that another AI agent can execute without guessing.

