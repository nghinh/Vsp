# Step 04: Review Context Map

**Goal:** Build `review-context-map.md` — a comprehensive record of what documents were read, scope boundaries, source/config verification evidence, and the phase trace table.

## Prerequisites

- Step `step-03-docs-inventory.md` has run (or was skipped if no docs exist)
- Scope is defined and stable

## Sequence

1. **Build `review-context-map.md`** with the following required sections:

   ### BMAD Docs Inventory
   - Copy/refer to `review-docs-inventory.md` findings
   - List all BMAD documents read for this review pass
   - Group by type: PRD, Architecture, UX/UI, Epic, Story, Workflow

   ### Scope Boundary Notes
   - Document what is IN scope and what is OUT of scope for this review
   - Explicitly list exclusion patterns applied (`.opencode/**`, nested copies)
   - Note any ambiguous paths and the ruling on each

   ### Source/Config Verification
   - Record which source files were read for evidence
   - Record which config files were verified
   - Note the primary evidence sources for each finding category

   ### Phase Trace Table
   ```
   | Phase | Step | Status | Timestamp |
   |-------|------|--------|----------|
   | scope_and_mode | step-01 | complete | ISO8601 |
   | docs_inventory | step-03 | complete | ISO8601 |
   | context_map | step-04 | in_progress | ISO8601 |
   ```

2. **Read relevant source files** based on scope:
   - For each file in scope, read the actual content
   - Extract key context: framework, dependencies, API surface, data models
   - Note any config discrepancies or unusual patterns

3. **Read relevant BMAD documents** from the docs inventory:
   - PRD if available and relevant to scope
   - Architecture if available and relevant to scope
   - Epic/Story documents if available and relevant to scope

4. **Update `review-state.json`:**
   - Set `current_phase: context_map`
   - Record `context_map_completed: true` with timestamp

## Hard stops

- **Never** proceed to `step-05-risk-map.md` without a complete `review-context-map.md`.
- **Never** skip reading source files for the assigned scope — context must be verified, not assumed.

## Outputs

- `{review_folder}/review-context-map.md` (complete)
- Updated `{review_folder}/review-state.json`

## Next step

Proceed to `step-05-risk-map.md`.
