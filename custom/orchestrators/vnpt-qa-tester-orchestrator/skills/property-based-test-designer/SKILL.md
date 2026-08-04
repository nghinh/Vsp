# Skill: property-based-test-designer

## Purpose

Designs invariants and property-based tests using Hypothesis, fast-check, jqwik, FsCheck, or equivalent.

## Required outputs

- `04g-property-invariants.md`
- `property test files`

## Procedure

1. identify invariants.
2. define input domains and generators.
3. include edge cases null/empty/min/max/negative/huge/unicode/malformed/duplicates/timezone.
4. avoid duplicating example tests.
5. add shrinking/debug notes.
6. map to risk IDs.

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
