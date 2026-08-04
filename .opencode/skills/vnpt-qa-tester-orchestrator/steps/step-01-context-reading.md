# Step 01: Full Context Reading (BMAD-Recursive)

**Goal:** Recursively scan BMAD `docs/**` first, read relevant PRD/story/epic/architecture/UX/API/DB/source/existing tests from 0-EOF, and build a context map that satisfies the **Hard gate** of `BMAD_DOCS_CONTEXT_READING_CONTRACT.md`. This step is the single source of truth for every later step's context rehydration.

## Prerequisites

- `docs/qa/<scope>/00-qa-mission.md` exists with a defined scope.
- `qa-state.json` `phase_status = "mission_setup"`.

## Sequence

### Step 1.1 — Mandatory recursive BMAD docs discovery

1. Scan `docs/` recursively before any risk or test design. BMAD documents may be direct children of `docs/` or may be inside any subfolder. Do **not** assume PRD, architecture, epic, or story files are directly under `docs/`.

2. Discover, inventory, and classify these files if present:

   ```text
   # conventional root-level names
   docs/prd.md
   docs/PRD.md
   docs/brownfield-prd.md
   docs/project-brief.md
   docs/brief.md
   docs/architecture.md
   docs/fullstack-architecture.md
   docs/front-end-spec.md
   docs/frontend-spec.md
   docs/ux-spec.md
   docs/epic*.md
   docs/stor*.md

   # recursive BMAD/sharded names at any depth under docs/
   docs/**/prd*.md
   docs/**/*prd*.md
   docs/**/brownfield-prd*.md
   docs/**/project-brief*.md
   docs/**/brief*.md
   docs/**/architecture*.md
   docs/**/*architecture*.md
   docs/**/fullstack-architecture*.md
   docs/**/front-end-spec*.md
   docs/**/frontend-spec*.md
   docs/**/ux-spec*.md
   docs/**/epic*.md
   docs/**/*epic*.md
   docs/**/story*.md
   docs/**/stories*.md
   docs/**/*stor*.md
   docs/**/acceptance*.md
   docs/**/*acceptance*.md
   docs/**/api*.md
   docs/**/openapi*.yaml
   docs/**/openapi*.yml
   docs/**/schema*.md
   docs/**/data*.md

   # final recursive sweep
   docs/**/*.md
   docs/**/*.mdx
   docs/**/*.yaml
   docs/**/*.yml
   docs/**/*.json
   ```

3. Exclude generated QA artifacts from source-of-truth discovery:

   ```text
   docs/qa/**
   docs/**/.archive/**
   docs/**/archive/**
   docs/**/generated/**
   ```

4. Classify files by path, filename, headings, content markers, and links from other BMAD docs. Generic nested files such as `overview.md`, `index.md`, or `requirements.md` must not be skipped if they sit under PRD/story/architecture/epic/spec folders or contain relevant headings.

### Step 1.2 — Mandatory 0-EOF reading proof

For every relevant BMAD doc, check line count first and read line 1 through EOF. Search/grep snippets are not sufficient. Large files must be read in chunks until EOF.

`01-context-map.md` must include:

```markdown
## BMAD Docs Inventory and 0-EOF Proof

| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Extracted requirement IDs | Open gaps |
|---|---|---:|---|---|---|---|---|---|
```

Allowed statuses: `READ_0_EOF`, `NOT_FOUND`, `NOT_RELEVANT_WITH_REASON`, `TOO_LARGE_READ_IN_CHUNKS`, `BLOCKED_WITH_REASON`.

If no BMAD docs exist recursively under `docs/**`, excluding generated QA folders, record `SPEC_AMBIGUITY: No BMAD docs found recursively under docs/**. Falling back to README/source/API/tests only.`

### Step 1.3 — Required context extraction

- PRD/product goal, non-goals, users/personas
- epic/story scope and acceptance criteria
- architecture and data flow
- UI/UX/frontend behavior
- API contracts
- DB schema/migrations/seeds
- source files
- existing tests/fixtures
- README/scripts
- known bugs/TODOs
- conflicts between BMAD docs and implemented code

### Step 1.4 — Hard gate (must pass before step 02)

Confirm all of:

```text
BMAD_DOCS_RECURSIVE_SCAN_DONE = true
BMAD_DOCS_SCAN_DONE = true
BMAD_RELEVANT_DOCS_READ_0_EOF = true OR documented JUSTIFIED_EXCEPTION exists
```

If any flag is false and no `JUSTIFIED_EXCEPTION` is documented, **do not proceed to step 02**. Write the missing flag into `01-context-map.md` and stop with `missing_context_evidence`.

## Required inputs

- outputs from all earlier phases — `00-qa-mission.md` from step 00.
- BMAD docs root: `docs/`
- relevant project files read from 0-EOF
- current risk map and oracle where applicable — none yet; this step produces the input for them.

## Required work (deliverables for this step)

- recursive `docs/**` BMAD scan
- `BMAD Docs Inventory and 0-EOF Proof` table
- per-doc requirement-ID extraction
- ambiguity log entries (using the uncertainty label vocabulary)
- conflict log between docs and implemented code

## Required output

`docs/qa/<scope>/01-context-map.md`

## Exit criteria

- the named output artifact exists
- recursive `docs/**` BMAD scan is completed and stated explicitly
- `BMAD Docs Inventory and 0-EOF Proof` exists
- BMAD relevant docs are read 0-EOF or a justified exception is recorded
- nested BMAD docs are not silently skipped
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped (forward reference; gate preserved)
- assumptions and ambiguities are explicitly recorded
- all three hard-gate flags above are `true` or `JUSTIFIED_EXCEPTION` is documented

## Anti-gaming checks

- do not proceed to risk modeling/test design when recursive BMAD docs scan/read proof is missing
- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## State writes

Update `qa-state.json`:

```json
{
  "current_step": "step-01-context-reading",
  "phase_status": "context_reading",
  "scope_artifacts": {
    "01-context-map.md": "written"
  },
  "evidence": {
    "prd_sources_read": ["<absolute paths>"],
    "project_context_sources_read": ["<absolute paths>"],
    "story_sources_read": ["<absolute paths>"],
    "mockup_sources_read": ["<absolute paths>"],
    "context_alignment_notes": "<free text>"
  },
  "uncertainty_labels_used": ["<labels appended>"],
  "bmad_hard_gate": {
    "recursive_scan_done": true,
    "scan_done": true,
    "relevant_docs_read_0_eof": true,
    "justified_exception": null
  }
}
```

## Hard stops

- Never proceed to step 02 when `bmad_hard_gate.recursive_scan_done = false`.
- Never proceed to step 02 when `bmad_hard_gate.relevant_docs_read_0_eof = false` AND `justified_exception` is null.
- Never record `READ_0_EOF` without actually reading the file from line 1 to EOF in this run.
- Never silently skip a nested BMAD doc.
- Never hide a `BLOCKED_WITH_REASON` — surface it as `ENV_GAP` or `TOOL_GAP`.
- Never merge the BMAD proof into a generic context dump; the table MUST exist verbatim.

## Next step

Proceed to `step-02-risk-modeling.md`. Only load that file when the BMAD hard-gate flags are satisfied and the exit criteria above are met. Never load multiple step files simultaneously.
