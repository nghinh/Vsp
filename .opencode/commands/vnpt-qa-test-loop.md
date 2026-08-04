---
description: Run the VNPT QA tester orchestrator — 12-step BMAD-aligned QA pipeline (mission → context → risk → strategy → design → oracle → automation → execution → triage → briefs → gate → final report)
agent: vnpt-qa-tester-orchestrator
---
Target QA scope from user arguments:
$ARGUMENTS

Current git status:
!`git status --short || true`

Currently changed files:
!`(git diff --name-only --cached; git diff --name-only; git diff --name-only HEAD~1..HEAD) 2>/dev/null | sort -u || true`

Top-level project files:
!`(ls -la; echo; find . -maxdepth 3 -type f | sed 's#^./##' | sort | head -500) 2>/dev/null || true`

BMAD docs candidate files under docs/ recursively:
!`(find docs -type f \( -name '*.md' -o -name '*.mdx' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) -print 2>/dev/null | sort | sed 's#^./##'; true) | head -500`

BMAD docs priority summary:
!`python3 custom/orchestrators/vnpt-qa-tester-orchestrator/scripts/collect_project_context.py . 2>/dev/null || python custom/orchestrators/vnpt-qa-tester-orchestrator/scripts/collect_project_context.py . 2>/dev/null || python3 vnpt-bmad-custom/vnpt-qa-tester-orchestrator/scripts/collect_project_context.py . 2>/dev/null || python vnpt-bmad-custom/vnpt-qa-tester-orchestrator/scripts/collect_project_context.py . 2>/dev/null || true`

Execute `vnpt-qa-tester-orchestrator` now.

# BMAD step dispatch

This command routes into the BMAD-conformant skill at `vnpt-bmad-custom/vnpt-qa-tester-orchestrator/SKILL.md` (or its installed mirror at `.opencode/skills/vnpt-qa-tester-orchestrator/SKILL.md`). The skill dispatches into the 12-step pipeline under `steps/`:

```text
step-00-qa-mission           → docs/qa/<scope>/00-qa-mission.md
step-01-context-reading      → docs/qa/<scope>/01-context-map.md
step-02-risk-modeling        → docs/qa/<scope>/02-risk-map.md
step-03-test-strategy        → docs/qa/<scope>/03-test-strategy.md
step-04-test-case-design     → docs/qa/<scope>/04a-04k
step-05-test-oracle-design   → docs/qa/<scope>/05-test-oracle.md
step-06-test-automation      → docs/qa/<scope>/06-automation-map.md
step-07-test-execution       → docs/qa/<scope>/07-test-execution-report.md
step-08-failure-triage       → docs/qa/<scope>/08-failure-triage.md + bug-batches.json
step-09-fix-briefs           → docs/qa/<scope>/09-fix-briefs/QA-BUG-XXX.md
step-10-quality-gate         → docs/qa/<scope>/10-quality-gate-report.md + .json
step-11-final-qa-report      → docs/qa/<scope>/11-final-qa-report.md
```

Resume detection: if `docs/qa/<scope>/qa-state.json` exists with `qa_run_status != "done"` and a non-empty `current_step`, jump directly to that step. Otherwise start at step 00.

Mandatory behavior:
- Interpret `$ARGUMENTS` as the target feature/module/release scope.
- If scope is unclear, infer the most likely QA scope from changed files and BMAD/project docs; do not stop just to ask unless absolutely blocked.
- Use `docs/qa/<feature-or-release-name>/` as the output root.
- FIRST recursively scan the BMAD `docs/**` tree and identify PRD, architecture, epics, stories, UX/frontend spec, API schema, DB/data docs, and acceptance criteria.
- Read all relevant BMAD docs from `docs/**` from 0-EOF before risk modeling or test design. For every selected doc, check line count first and then read from line 1 to EOF, chunking large files when needed.
- Record `BMAD Docs Inventory and 0-EOF Proof` inside `docs/qa/<feature>/01-context-map.md`.
- Read all relevant source code, existing tests, fixtures, known bugs, package files, and setup docs from 0-EOF before test design.
- Produce a todo list before action and update it at every step.
- Execute steps in order:
  00 QA mission setup
  01 context reading
  02 risk modeling
  03 test strategy planning
  04 test case design
  05 test oracle design
  06 test automation generation
  07 test execution
  08 failure triage
  09 fix brief generation
  10 quality gate
  11 final QA report
  12 QA self-review if strict package resources are available
- Do not generate risk map, test cases, test oracle, or executable tests until recursive BMAD docs scan/read proof exists, unless `SPEC_AMBIGUITY`/`JUSTIFIED_EXCEPTION` is documented.
- Do not generate executable tests before test oracle exists.
- Generate deep test cases using risk-based, boundary, negative, combinatorial, state-machine, property-based, API schema fuzz, E2E, regression, exploratory, and mutation-gap strategies as applicable.
- Prefer executable tests, but if a tool is unavailable, write exact planned command, reason, and fallback artifact.
- Do not fix production code unless explicitly instructed.
- Final answer must summarize:
  - QA output folder
  - BMAD docs recursively scanned/read and any gaps
  - artifacts created
  - tests generated/executed
  - bugs found and classification
  - quality gate result
  - residual risks
  - exact next command for dev/fix agent if bugs exist
