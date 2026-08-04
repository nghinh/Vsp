# BMAD Docs Context Reading Contract

This contract is mandatory for `vnpt-qa-tester-orchestrator` when running inside a VNPT AI Driven Platform project that follows BMAD output conventions.

## Goal

The orchestrator must understand product context from BMAD-generated documentation before designing any QA test case. Test cases generated without reading BMAD docs are invalid.

## Standard BMAD docs root

The default BMAD output root is:

```text
docs/
```

The orchestrator must scan this folder before designing tests.

## Critical recursive discovery rule

BMAD documents are **not guaranteed to be direct children of `docs/`**. PRD, architecture, epics, stories, UX specs, API specs, data models, and acceptance criteria may be sharded into arbitrary subfolders, for example:

```text
docs/product/prd.md
docs/prd/index.md
docs/requirements/prd-v1.md
docs/architecture/system/overview.md
docs/architecture/components/*.md
docs/epics/epic-01/*.md
docs/stories/epic-01/story-01.md
docs/bmad/prd/*.md
docs/bmad/stories/*.md
docs/specs/frontend/*.md
```

Therefore the agent must perform a **recursive scan of `docs/**`**, not only a root-level `docs/*.md` scan. Root-level conventional names are priority hints only, not the complete discovery set.

Generated QA outputs under `docs/qa/**` must be excluded from BMAD source-of-truth discovery to avoid reading its own generated artifacts as requirements.

## Mandatory discovery order

The agent must discover and inventory these locations, if present:

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

The final recursive sweep is required to catch custom BMAD/VNPT names, but the agent must prioritize PRD, architecture, epics, stories, UX/frontend spec, API spec, DB schema, and acceptance criteria.

## Classification rule

Because BMAD files may use custom names, the agent must classify documents using all of the following:

1. relative path under `docs/`;
2. filename;
3. first headings and section titles;
4. requirement/story/acceptance-criteria markers;
5. links from other BMAD docs.

Do not skip a nested file merely because its filename is generic, such as `overview.md`, `index.md`, `requirements.md`, or `notes.md`. If it is inside a PRD/story/architecture/epic/spec folder or contains relevant headings, include it in the inventory.

## Mandatory 0-EOF reading rule

For every relevant BMAD doc selected for the target scope, the agent must:

1. Check total line count first.
2. Read the file from line 1 to EOF.
3. Never rely on grep snippets only.
4. For large files, read in explicit chunks until EOF.
5. Record proof in `docs/qa/<feature>/01-context-map.md`.

Required proof table:

```markdown
## BMAD Docs Inventory and 0-EOF Proof

| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Extracted requirement IDs | Open gaps |
|---|---|---:|---|---|---|---|---|---|
```

Accepted `0-EOF status` values:

```text
READ_0_EOF
NOT_FOUND
NOT_RELEVANT_WITH_REASON
TOO_LARGE_READ_IN_CHUNKS
BLOCKED_WITH_REASON
```

`BLOCKED_WITH_REASON` is allowed only when the file cannot be read due to tool/runtime limits. It must create an `ENV_GAP` or `TOOL_GAP` and cannot be hidden.

## Minimum BMAD context requirements

Before Phase 2 risk modeling, the context map must include:

- product goal and non-goals from PRD/brief;
- personas/users/stakeholders;
- feature scope and out-of-scope;
- functional requirements;
- acceptance criteria;
- epics/stories relevant to target scope;
- architecture components and data flow;
- API contracts if available;
- DB/data model if available;
- UI/UX behavior if available;
- known assumptions, ambiguity, and conflicts between docs and code.

## Hard gate

The agent must not generate risk map, test cases, oracle, or automation until:

```text
BMAD_DOCS_RECURSIVE_SCAN_DONE = true
BMAD_DOCS_SCAN_DONE = true
BMAD_RELEVANT_DOCS_READ_0_EOF = true OR documented JUSTIFIED_EXCEPTION exists
```

If no BMAD docs exist anywhere under `docs/**`, excluding `docs/qa/**`, the agent must record:

```text
SPEC_AMBIGUITY: No BMAD docs found recursively under docs/**. Falling back to README/source/API/tests only.
```

## Traceability requirement

Each generated test case must reference at least one of:

- BMAD requirement ID;
- story/epic ID;
- acceptance criterion;
- architecture/API/data contract;
- risk derived from BMAD docs;
- explicit ambiguity/gap ID.

A test case with only source-code-based intent is allowed only if BMAD docs are missing or the feature is undocumented; it must be marked `SOURCE_DERIVED_TEST` and linked to a gap.
