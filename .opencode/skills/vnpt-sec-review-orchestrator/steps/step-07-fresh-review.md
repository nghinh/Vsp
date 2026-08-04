# Step 07: Fresh Re-Review — Brand New Review from Current Workspace

**Goal:** Spawn fresh `vnpt-sec-review-auditor` subagents on the current workspace; close issues without fresh evidence; repeat until zero actionable issues.

## Sequence

### 1. Spawn fresh auditors (new first-pass style review)

Spawn parallel `vnpt-sec-review-auditor` subagents — same as Step 04 but:
- Hard rule: this is a BRAND NEW first-pass style review, not a replay of previous issues
- Hard rule: do NOT use prior-pass findings as evidence
- Hard rule: if an old issue is NOT reproduced in the newest fresh review, close it
- Hard rule: never close an issue without `evidence_after` captured in the latest pass

Each auditor returns:
- `issue_id` (may reuse if same finding reproduced)
- `issue_signature`
- `evidence_before` (fresh, from current workspace only)
- Or `NO_ACTIONABLE_ISSUES` (one line)

### 2. Increment pass counter

Update `security-review-state.json`:
- `pass_count += 1`
- New `latest_pass_id`
- Append to `open_issue_count_history`

### 3. Compare with previous pass

- Issues from previous backlog NOT reproduced in current fresh review → close them
- Issues still reproduced → keep open
- New issues found → add to current pass findings

### 4. Re-run fix waves if needed

If fresh review finds actionable issues:
- Return to `step-05-fix-waves.md` to build new fix waves
- Then `step-06-validate.md`
- Then loop back to `step-07-fresh-review.md` (repeat until clean)

### 5. Decision

- If fresh review returns 0 actionable issues AND `pass_count > 1`:
  - Set `security-review-state.json` status to `confirmation_pending`
  - Proceed to `step-08-confirmation.md`
- If fresh review still has actionable issues:
  - Loop: `step-05-fix-waves.md` → `step-06-validate.md` → `step-07-fresh-review.md`

### 6. Stall detection (again)

If `open_issue_count_history` shows non-decreasing for 2 consecutive loops:
- Set status to `stalled`
- Write `forensics.md`
- Narrow scope before continuing

### 7. Hard stops

- MUST NOT stop after only one review pass
- MUST NOT return raw review findings early unless blocked
- MUST repeat review → fix → validate → fresh review until zero actionable issues

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-current-pass-findings.json` (fresh findings)
- `docs/vnpt-flow/<scope-id>/security-review/security-live-backlog.json` (reconciled — closed without fresh evidence)
- `docs/vnpt-flow/<scope-id>/security-review/security-review-state.json` (updated)

## Next step

Zero actionable issues + more than one pass completed: `step-08-confirmation.md`
Still has actionable issues: back to `step-05-fix-waves.md`
