---
description: Run the epic-first BMAD orchestrator loop across all epics in the project — invokes the vnpt-dev-epic-orchestrator skill
argument-hint: [all-epics-or-optional-scope]
agent: vnpt-dev-epic-orchestrator
---

You are executing the VNPT epic-first delivery loop.

User input: `$ARGUMENTS`

Current git status:
!`git status --short || true`

Currently changed files (staged and unstaged):
!`(git diff --name-only --cached; git diff --name-only; git diff --name-only HEAD~1..HEAD) 2>/dev/null | sort -u || true`

This command loads the `vnpt-dev-epic-orchestrator` BMAD skill and runs intent **Create**:

1. Read `.opencode/skills/vnpt-dev-epic-orchestrator/SKILL.md` for activation and intent routing.
2. Honor the identity contract: orchestrator name `vnpt-dev-epic-orchestrator` is hard-baked in `vnpt-go-runtime` and must not be renamed.
3. Execute the step files in order:
   - `steps-c/step-01-intake.md` — context intake
   - `steps-c/step-03-discover.md` — epic discovery
   - `steps-c/step-04-wave-plan.md` — wave planning
   - `steps-c/step-05-preflight.md` — preflight verification
   - `steps-c/step-06-execute-waves.md` — execute waves
   - `steps-c/step-07-review-gate.md` — per-epic review gate
   - `steps-c/step-08-finalize.md` — finalize epic
   - `steps-c/step-09-wrapup.md` — wrapup
4. Follow `data/orchestrator-policy.json` (pinned state values) and `data/orchestrator-rules.md` (hard stops).

Full execution contract and hard stops are in `.opencode/agents/vnpt-dev-epic-orchestrator.md` and the SKILL.md body.
