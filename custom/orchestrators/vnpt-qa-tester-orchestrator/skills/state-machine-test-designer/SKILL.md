# Skill: state-machine-test-designer

## Purpose

Designs state models, allowed/forbidden transitions, sequence tests, retry/timeout/cancel tests, duplicate-event tests, and concurrency scenarios.

## Required outputs

- `04e-state-model.md`
- `04f-state-sequence-tests.md`

## Procedure

1. list states and terminal states.
2. list events/actions.
3. define allowed transitions.
4. define forbidden transitions.
5. generate normal sequences.
6. generate invalid sequences.
7. generate retry/timeout/cancel/duplicate cases.
8. map to unit/API/E2E/property tests.

## Quality bar

- P0/P1 risks must not be skipped.
- Negative, boundary, failure, recovery, and regression behavior must be considered when relevant.
- Output must include concrete IDs and traceability.
- Tool unavailability must result in a fallback plan, not silent omission.


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
