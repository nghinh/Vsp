# Skill: quality-gate-reporter

## Purpose

Evaluates coverage, oracle quality, test depth, mutation results, and hard-fail rules.

## Required outputs

- `10-quality-gate-report.md`

## Procedure

1. score each gate.
2. check P0/P1 coverage.
3. check negative/boundary coverage.
4. check state/invariant/API/E2E coverage.
5. check mutation result.
6. declare PASS/CONDITIONAL PASS/FAIL.

## Quality bar

- Output must be project-specific.
- Traceability to requirement, risk, oracle, and evidence must be preserved.
- Missing inputs, tool failures, and assumptions must be explicit.
- Do not hide gaps or inflate coverage.


## Global rules

- Read relevant context from 0-EOF before producing outputs.
- Every output must map to risk IDs and test IDs where applicable.
- Prefer specific, executable artifacts over generic advice.
- Do not generate automation before oracle exists.
- Do not count shallow tests as meaningful coverage.
- Explicitly mark assumptions and SPEC_AMBIGUITY when expected behavior is unclear.

## Medium-model guardrails

When used by a mid-tier model, this skill must:

1. Work from completed upstream artifacts only; do not infer missing upstream work silently.
2. Emit stable IDs and traceability tables.
3. Prefer concrete project-specific cases over generic advice.
4. Mark ambiguity with `SPEC_AMBIGUITY` or `ORACLE_GAP` instead of inventing expected behavior.
5. Produce at least one self-check table with pass/fail for the skill's quality bar.
6. State explicitly which P0/P1 risks remain uncovered and why.
