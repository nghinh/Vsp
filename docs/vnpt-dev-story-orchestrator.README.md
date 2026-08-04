# VNPT Dev Story Orchestrator

This package adds a story-first implementation orchestrator for BMAD 6.2.0 + OpenCode.

Installed files:
- `.opencode/commands/vnpt-dev-story-loop.md`
- `.opencode/agents/vnpt-dev-story-orchestrator.md`
- `.opencode/agents/vnpt-story-implementer.md`
- `docs/vnpt-dev-story-orchestrator.README.md`

## Installation

The orchestrator runs the pre/post-write duplicate-detection protocol
via the shared `dedup.py` module. The script auto-detects the repo root
(via `git rev-parse --show-toplevel`) and is path-independent, so callers
just invoke it as a cwd-relative path:

```bash
# Run from the repo root (or any cwd under which the path resolves)
python3 docs/vnpt-dev-story-orchestrator/tools/dedup.py <subcommand> ...
```

No env var is required. Both the monorepo layout and the consumer-repo
layout (after running `install_vnpt_bmad_custom_all.py`) put `dedup.py`
at `docs/vnpt-dev-story-orchestrator/tools/dedup.py`, so the same
command works in both cases.


Usage:

```text
/vnpt-dev-story-loop docs/stories/story-1.md
```

The command is designed to:
1. Treat `bmad-dev-story` as the mandatory implementation workflow.
2. Read the story and linked documents fully before coding.
3. Materialize run artifacts in `docs/vnpt-flow/<story-id>/`:
   - `story-context-packet.md`
   - `execution-plan.md`
   - `slice-matrix.md`
   - `requirements-coverage.md`
   - `phase-state.json`
   - `validation-report.md`
   - `review-handoff.md`
   - `forensics.md` (generated on stall/failure)
4. Execute bounded slices by wave:
   - parallel only for non-overlapping write scopes
   - sequential for dependency/overlap cases
5. Enforce requirements coverage gate before coding:
   - every acceptance criterion must map to at least one slice
6. Merge, build, lint, test, and typecheck with stack-aware validation policies and explicit reporting.
7. Run `/vnpt-review-loop docs/vnpt-flow/<story-id>/review-handoff.md` as a mandatory quality gate.
8. Support resume from `phase-state.json` and stall detection with escalation + forensics.
9. Only finish when the latest fresh review pass reports zero actionable issues and validations are clean.
