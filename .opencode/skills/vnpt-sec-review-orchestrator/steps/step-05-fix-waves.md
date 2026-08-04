# Step 05: Fix Waves — Non-Overlapping Write Workers

**Goal:** Build `security-fix-plan.md` grouping fixes into non-overlapping write waves; spawn parallel `vnpt-sec-fix-worker` subagents per wave.

## Sequence

### 1. Group findings into write waves

From `security-live-backlog.json` (open issues), group by write ownership scope:
- No overlapping file paths in the same wave
- Sequential fallback for overlapping scopes
- Independent fixes MAY run in parallel in the same wave

Example wave grouping:
```
Wave 1 (parallel):
  - fix-001: auth/session fix (auth-backend/)
  - fix-002: injection fix (api-server/)

Wave 2 (sequential to Wave 1):
  - fix-003: dependency update (package.json + requirements.txt overlap in shared lockfile)

Wave 3 (parallel, independent):
  - fix-004: secrets rotation (config/secrets.yaml)
  - fix-005: logging sanitization (utils/logger.py)
```

### 2. Write security-fix-plan.md

Document the wave plan:
```
# Security Fix Plan

## Wave 1
- fix-001: issue SEC-001 (auth/session)
- fix-002: issue SEC-002 (injection)
- Write scope: [non-overlapping]

## Wave 2
- fix-003: issue SEC-003 (dependency)
- Write scope: [sequential — overlaps Wave 1 via shared lockfile]

## Wave 3
- fix-004: issue SEC-004 (secrets)
- fix-005: issue SEC-005 (logging)
- Write scope: [non-overlapping]

## Overlap Handling
[document which scopes overlap and why sequential fallback chosen]
```

### 3. Spawn fix workers per wave

For each wave, spawn one `vnpt-sec-fix-worker` subagent with:
- Assigned backlog items (from `security-live-backlog.json`)
- Assigned write ownership scope (from `security-fix-plan.md`)
- Hard rule: never fix or edit files outside assigned owned paths
- Hard rule: never claim a finding is fixed without `evidence_after` validation
- Hard rule: never claim all fixed if any required validation command failed

Each worker must return:
- `fixed_issue_ids`
- `fixed_issue_signatures`
- `files_changed`
- `tests_or_validation_added_or_updated`
- `validation_commands_run`
- `validation_results`
- `evidence_after_by_issue`
- `blocked_items`
- `resume_hints`
- `residual_risks`

### 4. Wave synchronization (HARD)

- Wait for ALL workers in a wave to finish before starting the next wave
- If any worker in a wave is blocked, hold the wave until resolution
- Do not start Wave N+1 until Wave N is complete

### 5. Update security-live-backlog.json

After wave completes:
- Mark fixed issues with `status: closed` and `evidence_after`
- Keep open issues with updated `status: open`
- Append residual risks to backlog

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-fix-plan.md`
- `docs/vnpt-flow/<scope-id>/security-review/security-live-backlog.json` (updated)
- `docs/vnpt-flow/<scope-id>/security-review/security-review-state.json` (status updated)

## Next step

After all fix waves complete, proceed to `step-06-validate.md`.
