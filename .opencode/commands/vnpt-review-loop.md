---
description: Run VNPT parallel review -> fix -> fresh re-review loop until clean
agent: vnpt-review-orchestrator
---
Target scope from user arguments:
$ARGUMENTS

If `$ARGUMENTS` points to a `review-handoff.md` file, read it completely first.
If `$ARGUMENTS` points to a `review-handoff.json` file, treat it as canonical structured handoff input.
When handoff data is provided, it becomes the primary source for:
- touched scope
- changed files
- validations already executed
- known residual risks

Execute the full VNPT review/fix orchestration loop now using the step-file architecture.

Requirements:
- Follow the step-file execution protocol from SKILL.md
- Route to `step-01-scope-and-mode.md` for fresh runs (or `step-02-resume-check.md` for resume)
- Create a deterministic run folder at `docs/vnpt-flow/<scope-id>/review/`
- Materialize and keep these artifacts updated on every pass:
  - `review-state.json`
  - `review-current-pass-findings.json`
  - `review-live-backlog.json`
  - `review-handoff.json` (when handoff data exists)
  - `review-context-map.md`
  - `review-risk-map.md`
  - `review-fix-plan.md`
  - `review-validation-report.md`
  - `review-summary.md`
  - `forensics.md` (only when stalled/failure)
- Start by discovering scope and creating a todo list for the loop
- Run preflight gate before first pass:
  - scope is non-empty and resolvable
  - required tooling commands are known
  - findings/backlog schema initialized
- If `docs/**` exists, recursively inventory BMAD docs before the first review pass
- Build a review context map and review risk map before spawning reviewers
- MUST spawn multiple `vnpt-review-auditor` subagents in parallel for the first review pass
- MUST merge all findings into one deduplicated CURRENT-PASS findings set and reconcile the live backlog from that latest pass
- Every finding must include deterministic identity and evidence:
  - `issue_id`
  - `issue_signature`
  - `evidence_before`
  - `success_condition`
- If any actionable issues exist in the latest pass, MUST spawn multiple `vnpt-fix-worker` subagents in parallel to fix them
- Before spawning fix workers, create `fix-plan.md` by wave:
  - no overlapping write scopes in same wave
  - sequential fallback for overlapping scopes
- After fixing, MUST run the most relevant validation/build/lint/test/typecheck commands for the touched stack
- Apply stack-aware validation policy:
  - frontend: lint + typecheck + unit + build/smoke where available
  - backend: lint + unit/integration + compile/build
  - mobile: lint + static analysis + tests + compile
  - infra/devops: linter/validator + syntax/dry-run checks
- Run the canonical artifact validator after every review/fix pass:
  ```bash
  python3 "${VNPT_BUNDLE_ROOT}/tools/validate_review_artifacts.py" docs/vnpt-flow/<scope-id>/review/
  ```
  `VNPT_BUNDLE_ROOT` is the install root that contains this orchestrator's
  `tools/`, `schemas/`, and `config/` subdirs (see the agent file for
  fallback layouts). Treat a non-zero exit as a BLOCK.
- Use source/config as primary evidence; use validators and scanner output only as corroboration
- Exclude bundled scaffold source under `.opencode/**` and nested `vnpt-ai-driven-platform/**` copies from review and fix work unless the user explicitly scopes those paths
- MUST then spawn multiple `vnpt-review-auditor` subagents again for a completely fresh review from the current workspace
- Every re-review must be a brand-new first-pass style review, not a replay of previously found issues
- If an old issue is not reproduced in the newest fresh review, it must be closed and must not be reported again
- MUST repeat review -> fix -> validate -> fresh review until the newest fresh review returns zero actionable issues
- After the first zero-issue pass, MUST run one more fresh confirmation review before stopping
- Track stall detection in `review-state.json`:
  - store `pass_count` and `open_issue_count_history`
  - if open issue count is non-decreasing for 2 consecutive loops, set `status=stalled`, write `forensics.md`, and escalate strategy
- Resume protocol:
  - if `review-state.json` exists and status is not complete, resume from recorded state
  - do not restart from scratch unless state is invalid
- MUST NOT stop after only one review pass
- MUST NOT return raw review findings early unless blocked
- Final answer must include:
  - passes executed
  - issues found/closed/waived
  - latest actionable issue count
  - validation results
  - remaining risks
  - concise file summary
  - state path and whether run was resumed
