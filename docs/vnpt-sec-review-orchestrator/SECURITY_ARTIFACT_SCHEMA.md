# Security Artifact Schema

The security loop must materialize these artifacts under:

`docs/vnpt-flow/<scope-id>/security-review/`

## Required files

- `security-context-map.md`
- `security-risk-map.md`
- `security-review-state.json`
- `security-current-pass-findings.json`
- `security-live-backlog.json`
- `security-fix-plan.md`
- `security-validation-report.md`
- `security-summary.md`
- `schemas/security-review-state.schema.json`
- `schemas/security-current-pass-findings.schema.json`
- `schemas/security-live-backlog.schema.json`
- `schemas/security-handoff.schema.json`
- `config/security-scope-policy.yaml`
- `config/security-lane-routing.yaml`

`forensics.md` is required only when stalled or failed.

## Required content rules

### `security-context-map.md`
- recursive BMAD docs inventory
- 0-EOF proof table
- source/config evidence summary
- phase trace table

### `security-risk-map.md`
- control-family risk taxonomy
- stack detection result
- risk IDs
- validation route per risk
- phase trace table

### `security-review-state.json`
- scope identity
- mode
- status
- pass counter
- open issue history
- latest pass ID
- confirmation-review flag

### `security-current-pass-findings.json`
- deterministic issue identity
- evidence before
- success condition
- current status

### `security-live-backlog.json`
- deduplicated live issues
- ownership scope
- priority
- current state

### `security-fix-plan.md`
- wave grouping
- ownership scope
- overlap handling

### `security-validation-report.md`
- validation commands run
- validation result summary
- corroboration evidence

### `security-summary.md`
- pass counts
- closed/open/waived issues
- remaining risks
- confirmation review outcome
- phase trace table

### `schemas/*`
- explicit field requirements for state, findings, backlog, and handoff
- type constraints for closure evidence
- deterministic scope and routing policy anchors
