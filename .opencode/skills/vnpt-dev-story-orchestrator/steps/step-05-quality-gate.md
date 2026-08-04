# Step 05: Quality Gate

**Goal:** Review implementation via `/vnpt-review-loop`, fix issues, loop until clean.

## Prerequisites

- All waves executed (Step 04 complete)
- OR story status was `review` (routing from Step 01)

## Sequence

### Step 5.1 — Generate Review Handoff

1. **Create `review-handoff.md`** in `docs/vnpt-flow/<story-id>/`:
   ```markdown
   # Story <story-id> Review Handoff

   ## Story Info
   - **Story ID:** <id>
   - **BMAD Status:** review

   ## Implementation Scope
   - Changed files: <list>
   - Slices implemented: <list>

   ## Validations
   - Validation commands run and results

   ## Remaining Risks
   - Any unresolved issues or open items
   ```

### Step 5.2 — Run Review Loop

1. **Execute:**
   ```
   /vnpt-review-loop docs/vnpt-flow/<story-id>/review-handoff.md
   ```

2. **Pass conditions:**
   - Review loop reports **ZERO actionable issues**
   - `review_pass_count` incremented in `phase-state.json`

3. **Fail conditions:**
   - Review loop reports **1+ actionable issues**
   - Issues logged to `failure-backlog.md`
   - Proceed to Step 5.3

### Step 5.3 — Fix Loop

If issues found:

1. **For each issue, implement fixes** (spawn `vnpt-story-implementer` if needed)

2. **Re-run validation** after fixes

3. **Update `validation-report.md`** with fix results

4. **Loop back to Step 5.2** — fresh `/vnpt-review-loop` pass

### Step 5.4 — Stall Detection

Track in `phase-state.json`:
```json
{
  "phase": "quality_gate",
  "review_pass_count": <n>,
  "open_issue_count_history": [<history>]
}
```

If issue count NOT decreasing for 2 consecutive loops:
- Mark `status: stalled`
- Write `forensics.md` with root cause analysis
- Switch strategy (re-slice ownership, narrower scope, sequential fallback)

### Step 5.5 — Quality Gate Pass

When review loop reports zero actionable issues:

1. **Update `phase-state.json`:**
   ```json
   {
     "phase": "quality_gate_pass",
     "quality_status": "clean"
   }
   ```

2. **Proceed to Step 06 (Wrapup)**

## Quality Loop

```
Review → if pass → done
       → if issues → fix → re-review → loop until clean or stalled
```

## Outputs

- `docs/vnpt-flow/<story-id>/review-handoff.md`
- `docs/vnpt-flow/<story-id>/validation-report.md` (updated)
- `docs/vnpt-flow/<story-id>/forensics.md` (if stalled)
- Updated `docs/vnpt-flow/<story-id>/phase-state.json`

## Hard Stops

- Never mark quality gate pass if review loop reports actionable issues
- Never skip the review gate even if implementation looks complete
- Never accept "close enough" — zero actionable issues required
- Never infer "pass" from no output — confirm zero issues in the response

## Next Step

Step 06 (Wrapup) — when quality gate is clean
