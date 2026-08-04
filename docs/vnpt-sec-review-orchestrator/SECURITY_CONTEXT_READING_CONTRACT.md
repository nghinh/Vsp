# Security Context Reading Contract

This contract defines how the orchestrator must read project context before security review.

## Recursive discovery

- Scan `docs/**` recursively.
- Exclude generated security-review outputs under `docs/vnpt-flow/**/security-review/**`.
- Classify BMAD inputs by intent, not by folder depth.
- Read every scope-relevant doc from start to end.

## Relevant BMAD doc families

- PRD / product intent
- architecture / design
- story / epic / implementation notes
- API / contract docs
- data / schema / migration docs
- threat model / trust boundary docs
- acceptance criteria / non-goals
- ops / deployment / CI/CD notes

## Required proof table

The `security-context-map.md` artifact must include a proof table with at least:

| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Open gaps |
|---|---|---|---|---|---|---|---|

## Proof rules

- If a relevant doc exists, the orchestrator must record whether it was read `0-EOF` or why it could not be.
- If no BMAD docs exist, record `SPEC_AMBIGUITY` and identify the fallback sources used.
- Do not move to risk modeling until context proof is complete.
- If no story/security context exists, use the deterministic fallback scope policy from `config/security-scope-policy.yaml`.
