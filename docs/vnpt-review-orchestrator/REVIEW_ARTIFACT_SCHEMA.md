# Review Artifact Schema

## Markdown artifacts

### `review-context-map.md`

Must include:

- `## BMAD Docs Inventory and 0-EOF Proof`
- `## Scope Boundary Notes`
- `## Source/Config Verification Notes`
- `## Phase Trace Table`

### `review-risk-map.md`

Must include:

- `## Review Risk Taxonomy`
- `## Stack / Scope Routing`
- `## Validation Route`
- `## Phase Trace Table`

### `review-fix-plan.md`

Must include:

- `## Wave Plan`
- wave ownership table
- validation/fallback notes

### `review-validation-report.md`

Must include:

- `## Validation Commands`
- `## Validation Result Summary`
- `## Corroboration Evidence`

### `review-summary.md`

Must include:

- `## Remaining Risks`
- `## Confirmation Review Outcome`
- `## Phase Trace Table`

## JSON artifacts

### `review-state.json`

Required fields:

- `scope_id`
- `scope_source`
- `mode`
- `status`
- `pass_count`
- `open_issue_count_history`
- `latest_pass_id`
- `fresh_confirmation_pass_done`

Recommended fields:

- `latest_zero_issue_pass_id`
- `closed_issue_ids`
- `open_issue_ids`
- `scope_resolution`
- `scope_policy`

### `review-current-pass-findings.json`

Each finding must include:

- `issue_id`
- `issue_signature`
- `title`
- `severity`
- `category`
- `files`
- `evidence_before`
- `success_condition`
- `status`

### `review-live-backlog.json`

Each backlog item must include:

- `issue_id`
- `issue_signature`
- `state`
- `owner_scope`
- `priority`
- `title`
- `severity`
- `category`
- `files`
- `evidence_before`
- `success_condition`

## Closure rule

Closed/fixed/waived/deferred items must carry `evidence_after`.
