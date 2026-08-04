---
description: Run stitch mockup batch — upload BMAD markdown to Stitch, generate 1 screen per story, download HTML/PNG to docs/mockup/. NO React source.
argument-hint: --prd <path> --architecture <path> --epic-dir <dir> --stories-dir <dir> --mockup-dir <dir>
agent: vnpt-stitch-mockup-runner
---

You are executing the VNPT stitch mockup batch.

User input: `$ARGUMENTS` — a single string of `key=value` pairs separated by spaces. Keys are snake_case. Example:

  prd=docs/prd.md architecture=docs/architecture.md epic_dir=docs/epics stories_dir=docs/stories mockup_dir=docs/mockup

## Parse arguments

Extract values into shell variables (DO NOT use $ARGUMENTS directly, parse once at start):

```bash
# Parse $ARGUMENTS (one string of "key=value key=value ...") into shell vars.
# Use snake_case keys (matches Go's BuildStitchMockupBatchArgs output and
# is shell-var-name safe — hyphens break bash assignment).
for kv in $ARGUMENTS; do
  case "$kv" in
    prd=*)         prd="${kv#prd=}" ;;
    architecture=*) architecture="${kv#architecture=}" ;;
    epic_dir=*)    epic_dir="${kv#epic_dir=}" ;;
    stories_dir=*) stories_dir="${kv#stories_dir=}" ;;
    mockup_dir=*)  mockup_dir="${kv#mockup_dir=}" ;;
  esac
done
echo "prd=$prd arch=$architecture epic=$epic_dir stories=$stories_dir mockup=$mockup_dir"
```

Workflow (3 phases, SEQUENTIAL, do NOT parallelize):

## Phase 1 — Upload markdown to Stitch

- Run `stitch-upload-to-stitch` skill for each of: PRD, architecture, all `epic-dir/*.md`, all `stories-dir/*.md`.
- Stitch project: use existing or auto-create via Stitch MCP `list_projects` + `create_project` (name: `vnpt-mockup-<YYYYMMDD>`, `<YYYYMMDD>` = zero-padded YYYY-MM-DD in `Asia/Ho_Chi_Minh` timezone).
- Verify uploads via `.stitch/context-uploads.json` (or equivalent state file).
- **Halt** on any upload failure → write `.stitch/mockup-failures.json`.

## Phase 2 — Generate screen per story

- **Pre-flight**: verify `.stitch/DESIGN.md` exists. If missing, run `stitch-manage-design-system` skill first (BLOCKING — do not proceed if this fails).
- For each `stories-dir/*.md` (SEQUENTIAL):
  - Load `stitch-generate-design` skill.
  - Enhance prompt via `references/design-mappings.md` + `references/prompt-keywords.md`.
  - Call Stitch MCP `generate_screen_from_text` with `device: DESKTOP`.
  - Save response to `.stitch/screens/<page-slug>.json` with fields: `htmlCode.downloadUrl`, `screenshot.downloadUrl`, `width`.
- **Page-slug resolution** (MUST follow):
  1. Strip extension: `story-03-04.md` → `story-03-04`.
  2. If filename matches regex `^story-([0-9]+)-([0-9]+)\.md$`, use `<epic-id>-<n>` as page-slug (vd `story-03-04.md` → `03-04`).
  3. Else (no pattern match), use full filename without extension as page-slug.
  4. If 2 stories resolve to same slug → FAIL FAST, write `.stitch/mockup-failures.json` với message rõ, HALT.
- **Halt** on any generation failure → write `.stitch/mockup-failures.json`.

## Phase 3 — Download HTML/PNG to docs/mockup/

- Default output dir: `docs/mockup/` (MUST be at project root, NOT nested).
- For each `.stitch/screens/<page-slug>.json` (SEQUENTIAL):
  - Download HTML: `bash ~/.cache/opencode/stitch-skills-cache/react-components/scripts/fetch-stitch.sh "<htmlCode.downloadUrl>" "docs/mockup/<page-slug>.html"`
  - Download PNG: Stitch CDN trả low-res by default. Append `=w<width>` to URL: `bash ~/.cache/opencode/stitch-skills-cache/react-components/scripts/fetch-stitch.sh "<screenshot.downloadUrl>=w<width>" "docs/mockup/<page-slug>.png"`
  - Verify both files exist + non-empty (size > 0 bytes). If either fails → HALT.
- **Behavior khi `docs/mockup/` đã tồn tại** (with existing files):
  - **GHI ĐÈ** existing files with same name.
  - Log warning to stdout: `WARN: docs/mockup/<file> already exists, overwriting`.
  - Do NOT delete unrelated files in `docs/mockup/`.
- **HARD CONSTRAINT**: Use ONLY `fetch-stitch.sh` from `react-components` skill. Do NOT call other `react-components` tools (no React component generation, no `src/` writes, no validation scripts).

## Hard Stops (HARD)

- Halt on any phase failure. Write `.stitch/mockup-failures.json` with fields: `phase`, `target`, `error`, `timestamp`.
- Never skip phase 1 (no orphan screens).
- Never parallelize phases.
- Never run multiple stories in parallel in phase 2.
- Never auto-retry.
- Never write React source files.

## Output (final summary to user)

Print:
- Total stories attempted
- Success count
- Failure count
- List of `docs/mockup/*.{html,png}` files
- Path to `.stitch/mockup-state.json` and `.stitch/mockup-failures.json` (if any)
