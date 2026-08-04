# VNPT OpenCode review/fix orchestrator

This bundle adds:
- `.opencode/agents/vnpt-review-orchestrator.md`
- `.opencode/agents/vnpt-review-auditor.md`
- `.opencode/agents/vnpt-fix-worker.md`
- `.opencode/commands/vnpt-review-loop.md`
- `docs/vnpt-review-orchestrator.README.md`
- `docs/vnpt-review-orchestrator/STRICT_REVIEW_RULES_FOR_MEDIUM_MODELS.md`
- `docs/vnpt-review-orchestrator/MODEL_BEHAVIOR_CONTRACT.md`
- `docs/vnpt-review-orchestrator/REVIEW_CONTEXT_READING_CONTRACT.md`
- `docs/vnpt-review-orchestrator/REVIEW_ARTIFACT_SCHEMA.md`
- `docs/vnpt-review-orchestrator/REVIEW_HANDOFF_CONTRACT.md`
- `docs/vnpt-review-orchestrator/schemas/review-state.schema.json`
- `docs/vnpt-review-orchestrator/schemas/review-current-pass-findings.schema.json`
- `docs/vnpt-review-orchestrator/schemas/review-live-backlog.schema.json`
- `docs/vnpt-review-orchestrator/schemas/review-handoff.schema.json`
- `docs/vnpt-review-orchestrator/config/medium-model-guardrails.yaml`
- `docs/vnpt-review-orchestrator/config/review-scope-policy.yaml`
- `docs/vnpt-review-orchestrator/config/review-lane-routing.yaml`
- `docs/vnpt-review-orchestrator/tools/validate_review_artifacts.py`

## Installation: `VNPT_BUNDLE_ROOT`

Before running this orchestrator, export `VNPT_BUNDLE_ROOT` in your shell
and point it at the directory that contains this orchestrator's
`tools/`, `schemas/`, and `config/` subdirs. The agent + command
prompts invoke the validator as:

```bash
python3 "${VNPT_BUNDLE_ROOT}/tools/validate_review_artifacts.py" docs/vnpt-flow/<scope-id>/review/
```

Examples:

```bash
# monorepo (this repo) — install root is the monorepo root
export VNPT_BUNDLE_ROOT=/path/to/vnpt-ai-driven-platform

# downstream consumer via install_vnpt_bmad_custom_all.py — install
# root is the consumer repo (the meta-installer copies tools/,
# schemas/, config/ under docs/vnpt-review-orchestrator/ inside the
# consumer repo)
export VNPT_BUNDLE_ROOT=/path/to/consumer-repo

# manual drop-in to a custom location — point at that custom root
export VNPT_BUNDLE_ROOT=/path/to/docs/vnpt-review-orchestrator
```

As a safety net, the validator's `locate_bundle_root()` also probes
these layouts under `cwd` if `VNPT_BUNDLE_ROOT` is not set:

- `cwd/vnpt-bmad-custom/vnpt-review-orchestrator/` (monorepo)
- `cwd/docs/vnpt-review-orchestrator/` (meta-installer)
- `cwd/custom/orchestrators/vnpt-review-orchestrator/` (qa-tester convention)
- `cwd/.opencode/skills/vnpt-review-orchestrator/` (bmad-vnpt-* convention)

This means manual invocations (`cd <repo> && python3 .../validate_review_artifacts.py ...`)
work even when the env var is unset, as long as you `cd` to a directory
from which one of the candidate roots is reachable.

## Recommended layout
Copy the `.opencode` folder into your project root.

## How to run
In OpenCode, run:

```text
/vnpt-review-loop src/
```

or for changed files only:

```text
/vnpt-review-loop
```

## What it does
1. Discover scope from command arguments or git diff.
2. Materialize enterprise review artifacts under `docs/vnpt-flow/<scope-id>/review/`:
   - `review-state.json`
   - `review-current-pass-findings.json`
   - `review-live-backlog.json`
   - `review-handoff.json` when handoff data exists
   - `review-context-map.md`
   - `review-risk-map.md`
   - `review-fix-plan.md`
   - `review-validation-report.md`
   - `review-summary.md`
   - `forensics.md` (on stall/failure)
3. Run preflight gate and initialize deterministic findings/backlog schema.
4. Fan out parallel review subagents.
5. Merge only the latest current-pass findings into the live backlog with deterministic dedupe.
6. Build fix waves from ownership scopes (parallel when safe, sequential on overlap).
7. Fan out fix subagents according to `review-fix-plan.md`.
8. Run stack-aware validation policy and record evidence.
9. Fan out review subagents again as a fully fresh review.
10. Repeat until no actionable issues remain.
11. Run one extra fresh confirmation review before stopping.
12. Support resume from `review-state.json`; generate `forensics.md` on stall.

## Important notes
- Re-review is intentionally defined as a brand-new review from the current workspace, not a replay of old findings.
- Old issues that are not reproduced in the latest fresh review must be closed.
- Review workers are read-only; fix workers can edit.
- If your environment asks for permission on `edit`, `bash`, or `task`, approve them for smoother execution.
- For frontend work, the prompts force loading `ui-ux-pro-max`.
- `review-handoff.md` from dev-story orchestrator is supported as primary scope input.
- `review-handoff.json` is the canonical structured handoff artifact when available.
