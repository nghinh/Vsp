# VNPT Stitch Mockup Batch

This package adds a stitch mockup batch command that:

1. Uploads BMAD markdown (PRD, architecture, epics, stories) to a Stitch project
2. Generates 1 screen per story using Stitch MCP
3. Downloads HTML/PNG to `docs/mockup/` at project root

**Explicit non-goal**: React source code generation (separate phase).

## Installation

Run standard installer:
```bash
python3 install_vnpt_bmad_custom_all.py
```

Installed files (after install):
- `<consumer-repo>/.opencode/commands/vnpt-stitch-mockup-batch.md`
- `<consumer-repo>/.opencode/agents/vnpt-stitch-mockup-runner.md`

## Usage

```bash
runtime stitch-mockup-batch \
  --prd docs/prd.md \
  --architecture docs/architecture.md \
  --epic-dir docs/epics \
  --stories-dir docs/stories \
  --mockup-dir docs/mockup  # default
```

## Output
- `docs/mockup/<page-slug>.html`
- `docs/mockup/<page-slug>.png`
- `.stitch/screens/<page-slug>.json` (metadata)
- `.stitch/mockup-state.json` (overall status)
- `.stitch/mockup-failures.json` (if any failure)
