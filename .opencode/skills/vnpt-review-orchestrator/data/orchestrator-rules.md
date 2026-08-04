> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by any runtime service.

> The 25 hard stops below govern the **BMAD review workflow** (review pass, fix waves, validation, confirmation). They are enforced by the LLM agent following `steps/step-*.md` instructions.

> See `references/review-artifact-schema.md` for the `review-state.json` schema used by this skill.

# Orchestrator Rules (Hard Stops and Non-negotiables)

## Hard Stops (NEVER violate)

1. **Never run review passes in parallel for the same scope** — sequential passes only, each must complete before the next begins.
2. **Never skip parallel fan-out when scope can be partitioned** — single-monolithic reviews are invalid; always partition into buckets for parallel auditors.
3. **Never replay old findings as fresh** — each pass must inspect the current workspace; only report issues that exist NOW.
4. **Never close an issue without `evidence_after`** — any `closed`, `fixed`, `waived`, or `deferred` item must have observable post-fix evidence.
5. **Never mark `status: complete` without `fresh_confirmation_pass_done: true`** — confirmation review is mandatory.
6. **Never mark `status: complete` while any issue is `open`** — zero open items required for completion.
7. **Never skip the confirmation review after a zero-issue pass** — it is mandatory, not optional.
8. **Never accept "close enough"** — confirmation pass must report zero actionable issues.
9. **Never skip phase order** — all 11 phases must execute in sequence.
10. **Never skip determining the validation route** — validation is a mandatory gate after every fix wave.
11. **Never mark an issue as `fixed` if its required validation command failed.**
12. **Never skip the artifact validator gate** — schema drift is the most common silent failure mode; run `validate_review_artifacts.py` after every pass.
13. **Never skip running validation commands appropriate to the stack** — validation is corroboration, not optional.
14. **Never spawn multiple fix workers for the same issue.**
15. **Never allow a fix worker to edit outside its owned paths** — path boundaries must be respected.
16. **Never close an issue without `evidence_after_by_issue`** — fix workers must supply evidence.
17. **Never claim all fixed if any validation command failed.**
18. **Never skip the synchronize barrier between fix waves** — must wait for ALL workers in the current wave before starting the next wave.
19. **Never dispatch an auditor without `REQUIRED CONTEXT READING`** from `review-context-map.md`.
20. **Never restart from scratch if valid `review-state.json` exists with `status == "in_progress"` or `status == "stalled"` — resume from recorded state.
21. **Never clear `pass_count` or `open_issue_count_history` on resume** — append to the existing history.
22. **Never stop after only one review pass** — the loop must run until zero actionable issues.
23. **Never replay findings from previous passes** — each re-review is a brand-new first-pass style review.
24. **Never re-report a `closed` or `waived` item** unless explicitly requested by the user.
25. **Never skip building `review-context-map.md` and `review-risk-map.md`** before spawning reviewers.

## Fresh Review Rule (NON-NEGOTIABLE)

Every pass (including re-reviews) must be a **brand-new first-pass style review**:
- Do NOT replay old findings from previous passes
- Do NOT use prior backlog/history as evidence
- Only report an issue if it can currently be observed in the code NOW
- If something was fixed, omit it entirely
- If an old issue is not reproduced in the newest fresh review, close it

## Fix Wave Rules

- **Parallel-allowed**: items with no write-scope overlap MAY share a wave
- **Sequential-required**: items with overlapping write-scope go in separate waves
  - HIGH overlap (same file) → separate sequential waves
  - MEDIUM overlap (same module) → separate sequential waves
  - LOW overlap (independent files) → same parallel wave
- After each wave, MUST wait for ALL workers to finish before starting the next wave

## Validation Gate Policy

The artifact validator must run after every review/fix pass:
```bash
python3 "${VNPT_BUNDLE_ROOT}/tools/validate_review_artifacts.py" docs/vnpt-flow/<scope-id>/review/
```
- Non-zero exit = BLOCK — fix violations, re-run, then continue
- Do not skip this gate

## Stall Detection

- Track `non_progress_streak` via `open_issue_count_history`
- If open issue count is non-decreasing for 2 consecutive passes:
  - Set `status: stalled`
  - Write `forensics.md` with root cause analysis
  - Narrow scope and escalate

## Resume Protocol

- If `review-state.json` exists and `status == "in_progress"` or `status == "stalled"`:
  - Resume from `current_phase` pointer
  - Do NOT restart from scratch
- If `status == "complete"` → report completion, do not resume
- If `status == "failed"` → report hard failure, halt unless user requests reset

## Completion Criteria

The review run is complete only when ALL of:
1. `review-state.json` `status == "complete"`
2. `fresh_confirmation_pass_done == true`
3. All backlog items are `fixed` / `closed` / `waived` / `deferred` (zero `open`)
4. `review-summary.md` is written
5. At least 2 passes have been executed (`pass_count >= 2`)
