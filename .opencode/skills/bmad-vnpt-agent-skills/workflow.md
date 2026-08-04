# BMAD VNPT Agent Skills Workflow

This package is a lightweight skill pack, not a long-running orchestrator.

## Selection rules

1. For PRD/spec drafting: use `vnpt-generate-prd`.
2. For isolated logic implementation or bug fix: use `vnpt-tdd`.
3. For bugs/regressions/failing tests: use `vnpt-triage-bug`.
4. For architecture review/refactor plan: use `vnpt-improve-architecture`.
5. For interface/API/module boundary design: use `vnpt-design-interface`.
6. For domain concepts/entities/rules: use `vnpt-domain-model`.
7. For QA quality review and risk-based test strategy: use `vnpt-qa-review`.

## Non-goals

- Do not replace BMAD Epic/Story generation.
- Do not replace `bmad-dev-story` for full story implementation.
- Do not replace VNPT test orchestrator or test hardening loops.
- Do not spawn background or long-running autonomous loops.

## VNPT baseline rule

When the task depends on project context, read relevant BMAD documents from 0-EOF before making conclusions.
