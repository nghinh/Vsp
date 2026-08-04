# Review Context Reading Contract

## Discovery rule

If `docs/**` exists, the orchestrator must recursively scan it and classify relevant BMAD files before review reasoning starts.

## Required inventory

The context map must track:

- PRD / spec / story
- architecture / design
- ADRs
- API and data docs
- acceptance criteria
- validation notes

## Proof rule

For every scope-relevant document, record:

- file path
- document type
- line range
- discovery path
- read method
- 0-EOF status
- scope relevance
- open gaps

## Evidence priority

1. Source code / config
2. Relevant docs
3. Validation commands and outputs
4. Free-form narrative

## Boundary rule

Pasted trees, copied notes, and handoff summaries are not evidence unless the declared source files back them up.
