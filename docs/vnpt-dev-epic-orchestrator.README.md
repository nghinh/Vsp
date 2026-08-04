# VNPT Dev Epic Orchestrator

This package adds an epic-first orchestrator on top of the existing VNPT story-first orchestrator.

Installed files:
- `.opencode/commands/vnpt-dev-epic-loop.md`
- `.opencode/agents/vnpt-dev-epic-orchestrator.md`
- `.opencode/agents/vnpt-epic-story-runner.md`
- `.opencode/agents/vnpt-epic-story-implementer.md`
- `docs/vnpt-dev-epic-orchestrator.README.md`

## Installation

The orchestrator runs the pre/post-write duplicate-detection protocol
via the shared `dedup.py` module. The script auto-detects the repo root
(via `git rev-parse --show-toplevel`) and is path-independent, so callers
just invoke it as a cwd-relative path:

```bash
# Run from the repo root (or any cwd under which the path resolves)
python3 docs/vnpt-dev-epic-orchestrator/tools/dedup.py <subcommand> ...
```

No env var is required. Both the monorepo layout and the consumer-repo
layout (after running `install_vnpt_bmad_custom_all.py`) put `dedup.py`
at `docs/vnpt-dev-epic-orchestrator/tools/dedup.py`, so the same
command works in both cases.


Usage:

```text
/vnpt-dev-epic-loop Hãy phát triển toàn bộ các epic của dự án
```

Execution model:
1. Discover epic/story markdown files recursively in `docs/**`.
2. Accept flexible source folders, including nested `planning-artifacts` and `implementation-artifacts`.
3. Freeze deterministic execution order at epic level and story level.
4. Execute epics sequentially.
5. Inside each epic, build dependency-aware waves:
   - Independent stories (no `depends_on` / `blocked_by` / `parent`, no write-scope overlap) → grouped in a parallel wave.
   - Dependent or overlapping stories → placed in later sequential waves.
   - For each parallel story wave, dispatch one `vnpt-epic-story-runner` per story.
6. For each story, dispatch `vnpt-epic-story-runner` for planning and quality gate only.
7. Inside each story, build dependency-aware slice waves:
   - Independent slices → grouped in a parallel wave; dispatch one `vnpt-epic-story-implementer` per slice.
   - Wait for all implementers in a slice wave to finish before starting the next slice wave.
8. Story runner does not implement slices and does not spawn implementers.
9. Continue run when a story fails, then aggregate unresolved failures at the end.
10. On resume, do not collapse remaining pending stories to sequential execution without explicit dependency/overlap evidence.

Run artifacts:
- `docs/vnpt-flow/epic-run-<run-id>/epic-inventory.md`
- `docs/vnpt-flow/epic-run-<run-id>/execution-order.md`
- `docs/vnpt-flow/epic-run-<run-id>/epic-state.json`
- `docs/vnpt-flow/epic-run-<run-id>/epic-progress.md`
- `docs/vnpt-flow/epic-run-<run-id>/failure-backlog.md`
- `docs/vnpt-flow/epic-run-<run-id>/epic-summary.md`
- `docs/vnpt-flow/epic-run-<run-id>/forensics.md` (stall/failure only)

Enterprise policies:
- Resume from `epic-state.json` without rerunning completed stories.
- Never stop whole epic run because one story fails.
- Always provide retry recommendations for failed stories.
- Package-level independence: `vnpt-dev-epic-orchestrator` does not require `vnpt-dev-story-orchestrator` to exist.
- No-shortcut guardrails: token/context pressure must use checkpoint+resume, not scope reduction.
- Technical-debt gate: placeholder/mock/TODO-only/deferred-production outputs are treated as failed story execution.



## BMAD Method Alignment

This orchestrator is the **epic-first** entry into the BMAD method (BMM) `4-implementation` phase.
It composes the following BMAD skills and workflows; the orchestrator itself is the entry point and
does not reimplement them.

| BMAD skill / workflow | Role in this orchestrator | Where it runs |
| --- | --- | --- |
| `test-driven-development` | TDD gate enforced inside `vnpt-epic-story-implementer` | Subagent prompt |
| `bmad-create-epics-and-stories` | Suggested via `/bmad-create-epics-and-stories` when discovery yields zero epics | User-invoked from missing-epics gate |
| `/vnpt-review-loop` | Mandatory fresh-review gate after each epic; required to return zero actionable issues before marking the epic done | Command invoked from the orchestrator after `epic-summary.md` is written |

### BMAD package layout (v2.1+)

The orchestrator is structured as a BMAD-conformant skill:

```
vnpt-dev-epic-orchestrator/
├── SKILL.md                                  # BMAD manifest (frontmatter name + description)
├── customize.toml                            # workflow customization surface
├── pyproject.toml                            # Python package for tools/
├── LICENSE
├── README.md
├── .opencode/
│   ├── agents/
│   │   ├── vnpt-dev-epic-orchestrator.md     # primary agent (loads SKILL.md)
│   │   ├── vnpt-epic-story-runner.md         # sub-agent: planning + quality gate
│   │   └── vnpt-epic-story-implementer.md    # sub-agent: slice implementation + dedup
│   ├── commands/
│   │   └── vnpt-dev-epic-loop.md             # /vnpt-dev-epic-loop command
│   └── skills/vnpt-dev-epic-orchestrator/    # target install path
│       ├── SKILL.md
│       ├── workflow.md                       # full workflow spec
│       ├── data/
│       │   ├── orchestrator-policy.json      # pinned state values
│       │   ├── orchestrator-rules.md         # hard stops
│       ├── steps-c/                          # Create / Resume flow (9 steps)
│       ├── assets/
│       │   ├── schemas/dedup-report.schema.json
│       └── references/                       # state-machine.md + epic-artifact-schema.md
├── tools/dedup.py                            # shared dedup module (path-independent)
└── tests/                                    # Python tests (run via python3 -m unittest)
```

### Migration status

**Completed (v2.1)** — the package is fully migrated to the BMAD-conformant structure. Legacy v1 files (`workflow.yaml`, `instructions.xml`, `contract.json`, and the top-level `schemas/` folder) have been removed from the bundle, and the install script now fails fast if any of these stale files appear in a consumer repo.

### Identity contract

The orchestrator's identity `vnpt-dev-epic-orchestrator` is a **hard runtime contract** with `vnpt-go-runtime`.

The migration therefore preserves the name verbatim. No rule in the orchestrator may
rename or alias the identity.

### Runtime non-coupling

This orchestrator does NOT import, spawn, or HTTP-call `vnpt-go-runtime`. The two
layers are intentionally decoupled:

- `vnpt-go-runtime` owns the batch epic execution state machine
  (see `docs/flow-contract-run-epics.md`).
- `vnpt-dev-epic-orchestrator` owns the epic inventory, story dispatch waves,
  and the BMAD-aligned review gate described above.

If you need the orchestrator to drive runtime execution, the bridge must be added
explicitly as a future migration step; this BMAD-alignment migration does not
introduce such a bridge.
