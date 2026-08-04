# Step 07: Findings Aggregation

**Goal:** Merge and deduplicate all findings from the latest review pass, reconcile them against the live backlog, and produce the updated `review-live-backlog.json`.

## Prerequisites

- `step-06-review-pass.md` has completed
- `review-current-pass-findings.json` exists with fresh findings
- `review-live-backlog.json` exists (or create new if first pass)

## Sequence

1. **Read `review-current-pass-findings.json`** (fresh findings from latest pass)

2. **Read existing `review-live-backlog.json`** (if exists):
   - Load all backlog items from previous passes
   - Each backlog item has: `issue_id`, `issue_signature`, `status`, `evidence_before`, `evidence_after`, `fixed_by`, `files`

3. **Deduplicate fresh findings vs. backlog:**
   - Match each fresh finding's `issue_signature` against backlog items
   - If match found in backlog with `status: open`:
     - Keep the finding (it still exists)
     - Update `evidence_before` if new evidence is stronger
   - If match found in backlog with `status: fixed`:
     - Re-verify: does the issue still exist in the current workspace?
     - If still exists → revert to `status: open`, update evidence
     - If truly fixed → keep as `status: fixed`, do not re-report
   - If match found in backlog with `status: closed` or `status: waived`:
     - Do NOT re-report — closed/waived items stay closed unless explicitly reopened
   - If no match in backlog → new issue, add with `status: open`

4. **Build updated `review-live-backlog.json`:**
   - All items: `open`, `in_progress`, `stalled`, `fixed`, `closed`, `waived`, `deferred`
   - Schema:
     ```json
     {
       "backlog": [
         {
           "issue_id": "string",
           "issue_signature": "string",
           "title": "string",
           "severity": "critical|high|medium|low|info",
           "category": "string",
           "files": "string[]",
           "status": "open|in_progress|stalled|fixed|closed|waived|deferred",
           "evidence_before": "string",
           "evidence_after": "string|null",
           "fixed_by": "string|null",
           "wave": "number|null",
           "opened_pass": "number",
           "updated_pass": "number"
         }
       ],
       "summary": {
         "total": "number",
         "open": "number",
         "in_progress": "number",
         "stalled": "number",
         "fixed": "number",
         "closed": "number",
         "waived": "number",
         "deferred": "number"
       }
     }
     ```

5. **Update `review-state.json`:**
   - Set `current_phase: findings_aggregation`
   - Record `open_issue_count: <count>`
   - Append to `open_issue_count_history: []`

6. **Stall detection:**
   - Check if `open_issue_count_history` shows non-decreasing count for 2+ consecutive passes
   - If stall detected:
     - Set `review-state.json` `status: stalled`
     - Write `forensics.md` with root cause analysis
     - Narrow strategy and escalate

## Hard stops

- **Never** close an issue without `evidence_after` — any `closed`, `fixed`, `waived`, or `deferred` item must have observable evidence.
- **Never** re-report a `closed` or `waived` item unless explicitly requested.
- **Never** clear the backlog on resume — maintain continuity across passes.

## Outputs

- `{review_folder}/review-live-backlog.json` (updated)
- Updated `{review_folder}/review-state.json`
- `forensics.md` if stall detected

## Next step

Proceed to `step-08-fix-waves.md`.
