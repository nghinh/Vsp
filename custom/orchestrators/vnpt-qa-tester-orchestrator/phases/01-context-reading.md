# Phase: 01-context-reading

## Purpose

Recursively scan BMAD `docs/**` first, read relevant PRD/story/epic/architecture/UX/API/DB/source/existing tests from 0-EOF, and build a context map.

## Required inputs

- outputs from all earlier phases
- BMAD docs root: `docs/`
- relevant project files read from 0-EOF
- current risk map and oracle where applicable

## Required work

### 1. Mandatory recursive BMAD docs discovery

Scan `docs/` recursively before any risk or test design. BMAD documents may be direct children of `docs/` or may be inside any subfolder. Do **not** assume PRD, architecture, epic, or story files are directly under `docs/`.

Discover, inventory, and classify these files if present:

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

Exclude generated QA artifacts from source-of-truth discovery:

```text
docs/qa/**
docs/**/.archive/**
docs/**/archive/**
docs/**/generated/**
```

Classify files by path, filename, headings, content markers, and links from other BMAD docs. Generic nested files such as `overview.md`, `index.md`, or `requirements.md` must not be skipped if they sit under PRD/story/architecture/epic/spec folders or contain relevant headings.

### 2. Mandatory 0-EOF reading proof

For every relevant BMAD doc, check line count first and read line 1 through EOF. Search/grep snippets are not sufficient. Large files must be read in chunks until EOF.

`01-context-map.md` must include:

```markdown
## BMAD Docs Inventory and 0-EOF Proof

| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Extracted requirement IDs | Open gaps |
|---|---|---:|---|---|---|---|---|---|
```

Allowed statuses: `READ_0_EOF`, `NOT_FOUND`, `NOT_RELEVANT_WITH_REASON`, `TOO_LARGE_READ_IN_CHUNKS`, `BLOCKED_WITH_REASON`.

If no BMAD docs exist recursively under `docs/**`, excluding generated QA folders, record `SPEC_AMBIGUITY: No BMAD docs found recursively under docs/**. Falling back to README/source/API/tests only.`

### 3. Required context extraction

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

## Required output

`docs/qa/<feature>/01-context-map.md`

## Exit criteria

- the named output artifact exists
- recursive `docs/**` BMAD scan is completed and stated explicitly
- `BMAD Docs Inventory and 0-EOF Proof` exists
- BMAD relevant docs are read 0-EOF or a justified exception is recorded
- nested BMAD docs are not silently skipped
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded

## Anti-gaming checks

- do not proceed to risk modeling/test design when recursive BMAD docs scan/read proof is missing
- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark SPEC_AMBIGUITY

## Medium-model strict checklist

Before leaving this phase, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.
