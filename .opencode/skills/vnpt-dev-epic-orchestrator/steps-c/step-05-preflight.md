# Step 05: Preflight Verification Gate

**Goal:** Verify ALL prerequisites before any story execution. Halt with a clear error if any check fails.

## Sequence — verify each item

- [ ] Context artifacts exist: `context-doc-index.md`, `context-understanding.md`
- [ ] At least one epic discovered (missing-epics gate already passed)
- [ ] Each epic has at least one story candidate
- [ ] Execution order is frozen and persisted in `execution-order.md`
- [ ] `vnpt-epic-story-runner` sub-agent available
- [ ] `vnpt-epic-story-implementer` sub-agent available

## On failure

If any preflight check fails, **HALT** and report which check failed. Do not proceed to execution.

## On success

Update `epic-state.json` `status: in_progress` and `phase: preflight`. Proceed to `step-06-execute-waves.md`.

## Hard stops

- **Never** bypass preflight. The gate exists to catch missing context before sub-agent dispatch.
- **Never** proceed to execution with empty `prd_sources_read` for a code-changing story.
