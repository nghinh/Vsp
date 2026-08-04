# Step 03: Epic Discovery

**Goal:** Recursively discover all epic/story markdown files and build the epic inventory.

## Sequence

1. **Recursively discover epic/story markdown files** under:
   - `docs/**/planning-artifacts/**`
   - `docs/**/implementation-artifacts/**`
   - Any nested `docs/**` subfolder

2. **Read all `epic-summary.md`** files found in `docs/` or `.runtime/`.

3. **Build deterministic `run_id`** using `datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")` or similar.

4. **Create run folder:** `docs/vnpt-flow/epic-run-<run_id>/`

5. **Materialize `epic-inventory.md`** — discovered epic/story map with evidence paths.

## Story classification rules

Field priority for epic/story frontmatter and metadata:
- `epic_id` / `id` → ID
- `title` / `name` → title
- `depends_on` / `blocked_by` / `parent` → explicit dependencies
- `acceptance_criteria` → scope

If multiple mappings conflict, choose the mapping with strongest explicit metadata. Unresolved stories are listed in `epic-inventory.md` and excluded from execution order.

## Missing-epics gate

If recursive discovery yields **zero epics**, **HALT** and recommend `/bmad-create-epics-and-stories`. Do not synthesize epics from inference.

## Outputs

- `{epic_run_folder}/epic-inventory.md`
- Initial `epic-state.json` with `status: pending` and `epic_count`.

## Next step

Proceed to `step-03.5-story-discovery.md` (Step 0 — story status check and routing).
