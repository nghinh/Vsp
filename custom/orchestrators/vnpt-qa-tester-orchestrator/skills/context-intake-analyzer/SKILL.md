# Skill: context-intake-analyzer

## Purpose

Collects and reads all relevant project context from 0-EOF, then creates a context map for QA planning.

## Required outputs

- `00-qa-mission.md`
- `01-context-map.md`

## Procedure

1. identify feature scope.
2. collect candidate docs/source/API/DB/test files.
3. read relevant files fully.
4. summarize behavior without losing details.
5. record assumptions and ambiguities.
6. mark files not read and reason.

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

## BMAD docs mandatory rule

Before producing `01-context-map.md`, scan `docs/` for BMAD artifacts and read relevant docs from 0-EOF:

- PRD / brownfield PRD / project brief
- architecture / fullstack architecture
- epic files
- story files
- frontend/UX spec
- API/data docs
- sharded docs under `docs/prd/**` and `docs/architecture/**`

The output must include `BMAD Docs Inventory and 0-EOF Proof` with line counts and read status. If no BMAD docs exist, record `SPEC_AMBIGUITY` and explicitly document fallback sources.
