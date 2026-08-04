# Step 05: Review Risk Map

**Goal:** Build `review-risk-map.md` — risk taxonomy, stack/scope routing, validation route determination, and phase trace table.

## Prerequisites

- `step-04-context-map.md` has completed
- `review-context-map.md` exists and is complete

## Sequence

1. **Build `review-risk-map.md`** with the following required sections:

   ### Risk Taxonomy
   - Categorize risks found in the scope by type:
     - `workflow/review` — review process issues
     - `workflow/fix` — fix process issues
     - `code/style` — style violations
     - `code/logic` — logical errors
     - `code/security` — security vulnerabilities
     - `code/performance` — performance issues
     - `config/build` — build configuration issues
     - `config/ci` — CI configuration issues
     - `docs/missing` — missing documentation
     - `test/coverage` — insufficient test coverage
     - `test/quality` — poor test quality
   - Assign preliminary severity to each risk category (info/low/medium/high/critical)

   ### Stack/Scope Routing
   - Determine the technology stack(s) in scope
   - Load the appropriate tech lane routing from `config/review-lane-routing.yaml`
   - Map files/modules to their respective tech lanes:
     - `frontend-react`, `frontend-vue`, `frontend-angular`
     - `backend-node`, `backend-python`, `backend-java`, `backend-dotnet`, `backend-go`, `backend-php`
     - `backend-c-cpp`
     - `mobile-flutter`, `mobile-react`
     - `infra-devops`, `architecture`, `docs`

   ### Validation Route
   - Determine the validation strategy based on stack:
     - **Frontend**: lint + typecheck + unit + build/smoke where available
     - **Backend**: lint + unit/integration + compile/build
     - **Mobile**: lint + static analysis + tests + compile
     - **Infra/DevOps**: linter/validator + syntax/dry-run checks
     - **Docs**: link checker + prose lint
   - List specific validation commands to run after fixes

   ### Phase Trace Table
   ```
   | Phase | Step | Status | Timestamp |
   |-------|------|--------|----------|
   | scope_and_mode | step-01 | complete | ISO8601 |
   | docs_inventory | step-03 | complete | ISO8601 |
   | context_map | step-04 | complete | ISO8601 |
   | risk_map | step-05 | in_progress | ISO8601 |
   ```

2. **Read `config/review-lane-routing.yaml`** to determine lane assignments:
   - Map each file in scope to a lane
   - Note any multi-lane files (e.g., full-stack features)

3. **Read `config/review-scope-policy.yaml`** for scope discovery rules:
   - Apply any scope-specific policies

4. **Update `review-state.json`:**
   - Set `current_phase: risk_map`
   - Record `risk_map_completed: true` with timestamp
   - Store `tech_lanes` array

## Hard stops

- **Never** proceed to `step-06-review-pass.md` without a complete `review-risk-map.md`.
- **Never** skip determining the validation route — validation is a mandatory gate after every fix wave.

## Outputs

- `{review_folder}/review-risk-map.md` (complete)
- Updated `{review_folder}/review-state.json`

## Next step

Proceed to `step-06-review-pass.md`.
