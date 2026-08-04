# Step 01: Context Intake

**Goal:** Discover and index project-level context docs (PRD, architecture, UX/UI, mockup) before any epic/story planning begins.

## Sequence

1. **Discover project-level sources under `docs/`:**
   - PRD candidates: `docs/PRD.md`, `docs/prd.md`, `docs/**/prd*.md`, `docs/**/product-requirements*.md`
   - Architecture candidates: `docs/architecture.md`, `docs/**/architecture*.md`, `docs/**/likec4/*.md`, `docs/**/likec4/*.likec4`
   - UX/UI candidates: `docs/ux-design.md`, `docs/**/ux*.md`, `docs/**/ui*.md`, `docs/**/design*.md`
   - Mockup candidates: `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*`

2. **Persist `context-doc-index.md`** — resolved paths grouped by PRD/architecture/UX/mockup.

3. **Persist `context-understanding.md`** — non-trivial constraints and implementation implications.

## Failure policy

- If no PRD is found, log a warning but continue. PRD may be added later.
- Architecture and UX/UI absence are warnings, not halts.
- Sub-agents adapt when context is missing.

## Outputs

- `{epic_run_folder}/context-doc-index.md`
- `{epic_run_folder}/context-understanding.md`

## Next step

After intake is complete, update `epic-state.json` with `phase: preflight` and proceed to `step-02-resume.md` (which handles the resume check) or `step-03-discover.md` (for fresh runs).
