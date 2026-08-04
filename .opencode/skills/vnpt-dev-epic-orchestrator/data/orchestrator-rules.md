> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by `vnpt-go-runtime`.
> 
> `vnpt-go-runtime` has its own policy code (context pressure thresholds in `internal/config/`, retry policy in `policies/retry_policy.go`, rotation policy in `policies/rotation_policy.go`, write-scope policy in `policies/write_scope_policy.go`). The runtime does NOT read this markdown file.
> 
> The 25 hard stops below govern the **BMAD epic workflow** (execution model, review-gate, parallelism, context reading). They are enforced by the LLM agent following `steps-c/step-*.md` instructions. They are NOT a duplicate of runtime policy — they cover a different layer (workflow vs. resource budget).
> 
> See `references/epic-artifact-schema.md` for the `epic-state.json` schema used by this skill (also skill-layer, not runtime `RuntimeState`).

# Orchestrator Rules (Hard Stops and Non-negotiables)

## Hard Stops (NEVER violate)

1. **Never run epics in parallel** — always sequential (one at a time).
2. **Never spawn multiple sub-agents simultaneously for a single story or slice when dependency or overlap evidence exists.** Independent stories/slices MAY run in parallel (one sub-agent per item).
3. **Never run dependent or overlapping stories in the same wave.**
4. **Never dispatch sub-agents without a populated `REQUIRED CONTEXT READING` file list.**
5. **Never mark an epic done while the latest `/vnpt-review-loop` pass has actionable issues.**
6. **Never bypass the missing-epics gate by inferring epics.**
7. **Never allow token/context pressure to downgrade implementation quality** — use checkpoint + resume instead.
8. **Never rename or alias the orchestrator identity `vnpt-dev-epic-orchestrator`** — it is a hard runtime contract.
9. **Never implement story logic directly in the epic loop** — always dispatch to `vnpt-epic-story-implementer`.
10. **Never run dependent or overlapping stories in parallel.** Independent stories (no `depends_on` / `blocked_by` / `parent` and no write-scope overlap) MAY run in parallel in the same story wave — one `vnpt-epic-story-runner` per independent story.
11. **Never collapse remaining pending stories in a resumed epic into sequential execution without explicit dependency/overlap evidence.** If pending stories have no `depends_on` / `blocked_by` / `parent` and no write-scope overlap, place them in the same parallel wave.
12. **Never run dependent or overlapping slices in parallel.** Independent slices (no dependency metadata, no shared write-scope) MAY run in parallel — one `vnpt-epic-story-implementer` per independent slice. After each slice wave, MUST wait for all implementers to finish before starting the next slice wave (synchronize barrier).
13. **Never allow `vnpt-epic-story-runner` sub-agents to implement slices directly.**
14. **Never process multiple stories inside one `vnpt-epic-story-runner` sub-agent instance.**
15. **Never execute a story wave of size >1 with only one `vnpt-epic-story-runner` sub-agent.** Wave size > 1 with independent stories MUST spawn one runner per story.
16. **Never accept outputs that justify simplification by token/context limits.**
17. **Never accept placeholders, TODO-only implementations, deferred production logic, or MVP-only shortcuts.**
18. **Never continue when a requested skill is not found** — correct to a valid skill name and retry, or persist a `skill_gap` and continue with available skills.
19. **Never continue execution when context evidence arrays are empty for a code-changing story run.**
20. **Never report a story complete while its BMAD story source status remains `ready-for-dev`.**
21. **Never abort the full run because a single story failed.**
22. **Never claim full success when `failure-backlog.md` is non-empty.**
23. **Never mark a story done while `phase-state.json.status` is not one of the six lifecycle values** in `data/orchestrator-policy.json` → `phaseStatusValues` (`preflight`, `planning`, `executing`, `validating`, `review_gate`, `done`).
24. **Never emit `recommendedAction="continue_with_checkpoint_only"` or embed a multi-choice question to the runtime.** If a story cannot be resolved in the current turn, either fix it in-place (so the next checkpoint can carry `continue`) or list it in `terminalState.blockedStories` with `terminalState.status="complete_with_blockers"`.
25. **Never claim packaging completion for a completed epic if the reverse-import quality gate still fails.**

## Skill namespace guard

- `vnpt-epic-story-runner` and `vnpt-epic-story-implementer` are **AGENTS**, not skills.
- Never bulk-load skills at the epic layer; only per-slice implementers load skills as required.
- Runtime loop is non-interactive: never ask the user to pick among options during active epic execution.
- If a stack skill appears missing, verify `.opencode/skills` first; if still unavailable, continue with available skills + native toolchain and persist blocker/remediation notes in artifacts.

## Failure handling policy

- Do not stop the global epic run when one story fails.
- Continue with the next story and next epic.
- Include root cause category and recommended retry command for each failure.
- Track non-progress streak in `epic-state.json`. If 2 consecutive stories fail with the same blocking reason class, mark `stalled_partial`, write `forensics.md`, and continue where possible.
- If reason class is `technical_debt_policy_violation`, include exact offending phrases/snippets in `forensics.md`.

## Phase failure transition (M4)

When any phase transitions to a failure outcome, the orchestrator MUST:

1. Set `phase-state.json.status = "failed"`.
2. Populate `phase-state.json.failure_reason_class` with one of the values in `data/orchestrator-policy.json` → `failureReasonClasses`:
   - `missing_prd_context_evidence`
   - `missing_context_evidence`
   - `missing_ux_context_evidence`
   - `technical_debt_policy_violation`
   - `story_status_not_progressed`
   - `story_status_invalid_done`
   - `duplicate_detection_failed`
3. Persist the failure record in `failure-backlog.md` with root cause and retry hint.
4. Continue with the next slice / story / epic — **never abort** the global run on a single phase failure.

## Context rehydration (every turn)

On every turn / step transition, the orchestrator MUST re-read context files from disk before any dispatch or decision. Required sources:

- PRD (`context-doc-index.md` → `docs/**/prd*.md` and variants)
- Architecture (`context-doc-index.md` → `docs/**/architecture*.md`, `docs/**/likec4/*`)
- UX/UI (`context-doc-index.md` → `docs/**/ux*.md`, `docs/**/ui*.md`, `docs/**/design*.md`)
- Mockups / wireframes / Figma (`context-doc-index.md` → `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*`)
- Epic and story artifacts (`docs/vnpt-flow/epic-run-<run_id>/**`, `docs/vnpt-flow/<story-id>/**`)

A dispatch prompt without rehydrated context is invalid.

## Resume protocol

- If `epic-state.json` exists and status is not `done`, load all pending stories for the current epic (not just the next index).
- Rebuild the wave plan on the pending-story set of the current epic before dispatch.
- If pending stories have no explicit dependency/overlap evidence, place them in the same **parallel** wave — one `vnpt-epic-story-runner` per independent story.
- Never re-run already completed stories unless explicitly requested.

## Stall protocol

- Track non-progress streak in `epic-state.json`.
- If 2 consecutive stories fail with the same blocking reason class:
  - Mark `stalled_partial`.
  - Write `forensics.md` with root cause analysis.
  - Continue to the next epic.
- For `technical_debt_policy_violation`, include exact offending phrases/snippets in `forensics.md`.

## Identity contract

- The runtime stamps this value into `producer`/`Producer` fields on checkpoints, handoffs, and continuation capsules.
- Do **not** rename, alias, or override this value.
