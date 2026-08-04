> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by any runtime service.
>
> The 20 hard stops below govern the **BMAD security review workflow** (scope resolution, evidence standards, pass loop, fix waves, confirmation gate). They are enforced by the LLM agent following `steps/step-*.md` instructions.

# Security Review Orchestrator Rules (Hard Stops and Non-negotiables)

## Hard Stops (NEVER violate)

1. **Never close a finding without `evidence_after`** — must be captured in the latest pass.
2. **Never trust scanner output over source/config evidence** — scanners corroborate, source is truth.
3. **Never stop after one review pass** — always run the extra confirmation review after the first zero-issue pass.
4. **Never use prior-pass findings as evidence in a fresh review** — each review pass must be a brand new first-pass style review.
5. **Never close an old issue that was not reproduced in the newest fresh review** — close only with fresh `evidence_after`.
6. **Never spawn auditors by arbitrary file chunks** — always divide by security lane or control family.
7. **Never spawn fix workers with overlapping write scopes in the same wave** — sequential fallback for overlapping scopes.
8. **Never claim all fixed if any required validation command failed** — report the failure instead.
9. **Never run fix Wave N+1 before Wave N is complete** — synchronize barrier between waves.
10. **Never dispatch auditors or fix workers without a populated `REQUIRED CONTEXT READING` file list.**
11. **Never bypass the missing-scope gate** — scope must be non-empty and resolvable before proceeding.
12. **Never include `.opencode/**` or `nested vnpt-ai-driven-platform/**` in security review/fix scope** unless user explicitly targets them.
13. **Never treat handoff file unstructured narrative as truth** — trust only explicitly declared structured fields.
14. **Never infer scope without evidence** — `$ARGUMENTS` preferred input but workspace overrides if contradictory.
15. **Never report 0 actionable issues without running the confirmation review** — confirmation pass is mandatory.
16. **Never mark run complete without running `validate_security_artifacts.py`** — bundled validator is the final gate.
17. **Never allow token/context pressure to downgrade evidence standards** — checkpoint + resume instead.
18. **Never accept scanner-only evidence without source/config verification** — anti-shallow rule.
19. **Never reopen an issue that failed to reproduce in fresh review unless scanner corroborates** — trust the fresh workspace.
20. **Never rename or alias the orchestrator identity `vnpt-sec-review-orchestrator`** — hard runtime contract.

## Anti-Shallow Rules

These do NOT count as security coverage:
- scanner output without source/config verification
- a single lint or build command without evidence of the vulnerable path
- vague statements like "looks secure"
- closure without `evidence_after`
- a fix that widens scope beyond the owned finding

## Gap Labels

When behavior is unclear, label the gap instead of inventing behavior:
- `SPEC_AMBIGUITY`
- `ORACLE_GAP`
- `ENV_GAP`
- `DATA_GAP`
- `TOOL_GAP`
- `JUSTIFIED_EXCEPTION`

## Stall Detection

Track `open_issue_count_history` in `security-review-state.json`:
- If open issue count is non-decreasing for 2 consecutive loops:
  - Set `status: stalled`
  - Write `forensics.md`
  - Narrow scope before continuing

## Resume Protocol

- If `security-review-state.json` exists and status is not `complete`, resume from recorded state
- Do not restart from scratch unless state is invalid or user explicitly requests
