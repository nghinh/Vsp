# Step 03: BMAD Docs Inventory

**Goal:** If `docs/**` exists, recursively inventory all BMAD documents before the first review pass. Build the docs inventory artifact to inform context reading.

## Prerequisites

- Scope has been defined in `step-01-scope-and-mode.md`
- `review-state.json` exists with `scope_id` and `mode`

## Sequence

1. **Check if `docs/**` exists:**
   - If `docs/` does not exist or is empty → skip this step, proceed to `step-04-context-map.md`
   - If `docs/**` exists → proceed with inventory

2. **Recursive BMAD docs scan** under `docs/`:
   - Discover all markdown files recursively
   - Classify each by BMAD document type using path patterns and frontmatter:
     - `epic` / `planning-artifacts` → Epic documents
     - `story` / `implementation-artifacts` → Story documents
     - `prd*.md` / `product-requirements*.md` → PRD documents
     - `architecture*.md` / `likec4/*` → Architecture documents
     - `ux*.md` / `ui*.md` / `design*.md` → UX/UI documents
     - `workflow*.md` / `checklist*.md` / `runbook*.md` → Workflow documents
     - `**/docs/**` miscellaneous → Other project docs

3. **Build `review-docs-inventory.md`:**
   - Table of discovered documents with: path, type, title (from frontmatter or filename)
   - Example format:
     ```
     | Path | Type | Title |
     |------|------|-------|
     | docs/PRD.md | prd | Product Requirements |
     | docs/architecture.md | architecture | System Architecture |
     ```

4. **Update `review-state.json`:**
   - Set `current_phase: docs_inventory`
   - Record `docs_inventory_completed: true` with timestamp

## Scope filtering

- Only inventory docs relevant to the current scope
- If mode is `diff` or `path-arg`, only inventory docs related to the changed/targeted scope
- If mode is `full`, inventory all docs

## Hard stops

- **Never** skip the docs inventory when `docs/**` exists — the inventory informs context reading for all subsequent passes.
- **Never** treat the docs inventory as the review itself — it is context only.

## Outputs

- `{review_folder}/review-docs-inventory.md`

## Next step

Proceed to `step-04-context-map.md`.
