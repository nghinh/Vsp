# Step 09: Validation

**Goal:** Run stack-aware validation commands after fix waves. Build `review-validation-report.md`. Run the canonical artifact validator. Gate continuation on clean validation.

## Prerequisites

- `step-08-fix-waves.md` has completed
- Fix workers have reported their `validation_commands_run` and results
- `review-fix-plan.md` shows which files were changed

## Sequence

1. **Build `review-validation-report.md`** with the following sections:

   ### Validation Commands Executed
   - Table of all validation commands run by fix workers
   - Format:
     ```
     | Wave | Issue | Command | Result | Exit Code |
     ```

   ### Result Summary
   - Count of: passed, failed, warnings
   - Note which issues failed validation (if any)

   ### Corroboration Evidence
   - Map each fixed issue to its validation evidence
   - Note any validation that could not be run (tool unavailable, etc.)

2. **Determine validation commands based on stack** (from `review-risk-map.md`):
   - **Frontend**: `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`
   - **Backend Node**: `npm run lint`, `npm run test`, `npm run build`
   - **Backend Python**: `flake8`, `pytest`, `mypy`
   - **Backend Java**: `mvn compile`, `mvn test`
   - **Backend .NET**: `dotnet build`, `dotnet test`
   - **Backend Go**: `go build`, `go test`
   - **Mobile Flutter**: `flutter analyze`, `flutter test`
   - **Mobile React Native**: `npm run lint`, `npm test`
   - **Infra/DevOps**: `terraform validate`, `ansible-lint`, `hadolint`

3. **Run the canonical artifact validator:**
   ```bash
   python3 "${VNPT_BUNDLE_ROOT}/tools/validate_review_artifacts.py" docs/vnpt-flow/<scope-id>/review/
   ```
   - `VNPT_BUNDLE_ROOT` resolves to the install root containing `tools/`, `schemas/`, `config/`
   - Treat non-zero exit as a **BLOCK** — fix violations, re-run, then continue
   - Do not skip this gate

4. **Validation failure handling:**
   - If any validation command failed:
     - Update `review-live-backlog.json`: set affected issues to `stalled`
     - Do NOT mark issues as `fixed` if validation failed
     - Record in `review-validation-report.md`
     - Continue to next step but note the stall

5. **Update `review-state.json`:**
   - Set `current_phase: validation`
   - Record `validation_passed: true/false`
   - Record `validation_failed_issues: []` if any

## Hard stops

- **Never** mark an issue as `fixed` if its required validation command failed.
- **Never** skip the artifact validator gate — schema drift is the most common silent failure mode.
- **Never** skip running validation commands appropriate to the stack — validation is corroboration, not optional.

## Outputs

- `{review_folder}/review-validation-report.md`
- Updated `{review_folder}/review-state.json`

## Next step

Proceed to `step-10-fresh-rereview.md`.
