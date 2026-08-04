# Step 01: Scope and Mode Detection

**Goal:** Discover and define the review target scope from invocation arguments, handoff artifacts, git state, or workspace analysis. Determine the review mode (diff / full / path-arg / handoff / manual).

## Sequence

1. **Resolve scope from invocation:**
   - Parse `$ARGUMENTS` for explicit paths or handoff file references
   - If `$ARGUMENTS` points to `review-handoff.md` or `review-handoff.json`, treat as structured handoff mode
   - If `$ARGUMENTS` points to a path, treat as path-arg mode
   - If no arguments, analyze git state (changed files since last commit) for diff mode
   - Fall back to full workspace mode if no other signal available

2. **Detect mode:**
   | Signal | Mode |
   |--------|------|
   | `review-handoff.md/.json` argument | `handoff` |
   | Explicit path argument | `path-arg` |
   | Git diff available | `diff` |
   | No signal | `full` |

3. **For handoff mode:**
   - Read `review-handoff.md` or `review-handoff.json` completely
   - Extract: touched scope, changed files, validations already executed, known residual risks
   - This becomes the primary source for all subsequent steps

4. **For diff mode:**
   - Run `git diff --name-only HEAD~1` or equivalent to discover changed files
   - Expand changed files to their containing modules/features
   - Limit scope to changed files + immediate dependents

5. **For path-arg mode:**
   - Validate the given path exists
   - Expand scope to cover the full feature/module context

6. **For full mode:**
   - Set scope to the entire project workspace
   - Exclude `.opencode/**` and nested `vnpt-ai-driven-platform/**` copies by default

7. **Exclusion rules (apply to all modes):**
   - Always exclude: `.opencode/**` (scaffold source)
   - Always exclude: nested `vnpt-ai-driven-platform/**` copies
   - Never exclude user-targeted paths even if they match the above

8. **Build deterministic `scope_id`:**
   - Use a hash or timestamp-based ID derived from scope contents
   - Format: alphanumeric, max 64 chars
   - Example: `scope-{datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")}-{short_hash}`

9. **Create run folder:** `docs/vnpt-flow/<scope-id>/review/`

10. **Initialize `review-state.json`:**
    - Set `run_id`, `scope_id`, `mode`, `scope_source`, `status: pending`
    - Set `pass_count: 0`, `open_issue_count_history: []`
    - Set `fresh_confirmation_pass_done: false`

11. **Initialize `review-handoff.json`** (if handoff mode):
    - Materialize handoff data as structured JSON

## Outputs

- `{review_folder}/review-state.json` (initial)
- `{review_folder}/review-handoff.json` (handoff mode only)
- Scope definition (files + modules in scope)

## Next step

Proceed to `step-02-resume-check.md` (which handles resume routing for in-progress runs, or chains back to `step-01` in headless mode if no state exists).
