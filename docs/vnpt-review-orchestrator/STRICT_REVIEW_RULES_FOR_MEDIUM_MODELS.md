# Strict Review Rules for Medium Models

Applies to `minimax/MiniMax-M3` and similar mid-tier models.

## Non-negotiable rules

- Follow the phase order exactly.
- Do not skip scope discovery.
- Do not skip BMAD docs inventory when `docs/**` exists.
- Do not claim success after a single pass.
- Do not close an issue without `evidence_after`.
- Do not trust pasted trees or free-form handoff prose beyond declared fields.
- Use source/config as primary evidence; use validation output only as corroboration.
- Keep fixes inside owned write scope.
- Run the confirmation review before final completion.

## Mandatory phase order

1. Scope and mode
2. Recursive BMAD docs inventory
3. Review context map
4. Review risk map
5. Lane routing and review pass
6. Findings aggregation
7. Fix waves
8. Validation and corroboration
9. Fresh re-review
10. Confirmation re-review

## Required outputs

The loop must materialize and keep updated:

- `review-state.json`
- `review-current-pass-findings.json`
- `review-live-backlog.json`
- `review-handoff.json` when handoff data exists
- `review-context-map.md`
- `review-risk-map.md`
- `review-fix-plan.md`
- `review-validation-report.md`
- `review-summary.md`
- `forensics.md` only when stalled

## Completion gate

Completion is allowed only when:

- the latest fresh review is actionable-issue free,
- the confirmation review also returns no actionable issues,
- the state records at least two passes,
- and the validation report is present.
