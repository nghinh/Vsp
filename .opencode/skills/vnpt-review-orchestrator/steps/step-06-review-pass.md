# Step 06: Review Pass

**Goal:** Fan out parallel `vnpt-review-auditor` sub-agents to perform a fresh first-pass-style review of the current workspace. Every re-review must be a brand-new review, not a replay of old findings.

## Prerequisites

- `step-04-context-map.md` has completed
- `step-05-risk-map.md` has completed
- Tech lanes and scope are determined

## Sequence

1. **Update `review-state.json`:**
   - Increment `pass_count`
   - Set `current_phase: review_pass`
   - Set `pass_started_at: ISO8601`

2. **Determine review buckets:**
   - Partition the scope into independent review buckets
   - Each bucket = one `vnpt-review-auditor` sub-agent invocation
   - Bucket strategy: by tech lane, by module, or by file count (aim for ~10-20 files per auditor)
   - Independent buckets MAY be reviewed in parallel

3. **Spawn parallel `vnpt-review-auditor` sub-agents:**
   - For each bucket, spawn one `vnpt-review-auditor` in parallel
   - Each auditor receives:
     - Assigned bucket/scope (file list)
     - Tech lane context from `review-risk-map.md`
     - Relevant VNPT skills to load (`bmad-code-review`, `bmad-review-edge-case-hunter`, plus stack-specific skills)
   - Loading requirements per auditor:
     - MUST load `bmad-code-review`
     - MUST load `bmad-review-edge-case-hunter`
     - MUST load stack-appropriate VNPT skill (e.g., `ui-ux-pro-max` for frontend)
   - Auditors are read-only (edit: deny)

4. **Await all auditor results:**
   - Wait for ALL auditors in the pass to return before proceeding
   - Collect all findings from each auditor

5. **Collect findings:**
   - Each auditor returns structured findings with:
     - `issue_id`, `issue_signature`, `title`, `severity`
     - `category`, `files`, `evidence_before`
     - `fix_recommendation`, `blocking_validation`, `success_condition`
   - If auditor returns `NO_ACTIONABLE_ISSUES`, treat as zero findings for that bucket

6. **Build `review-current-pass-findings.json`:**
   - Merge all findings into one deduplicated current-pass set
   - Deduplication key: `issue_signature`
   - If two findings have the same `issue_signature`, keep the one with stronger evidence
   - Sort by severity (critical → high → medium → low → info)

7. **Update `review-state.json`:**
   - Record `last_pass_findings_count: <count>`
   - Record `last_pass_actionable_count: <count>` (exclude info/low if appropriate)

## Fresh review rule (HARD)

- Every pass must be a **brand-new first-pass style review**
- Do NOT replay old findings from previous passes
- Do NOT use prior backlog/history as evidence
- Only report an issue if it can currently be observed in the code NOW
- If something was fixed in a previous pass, omit it entirely

## REQUIRED CONTEXT READING

Every auditor dispatch MUST contain a populated `REQUIRED CONTEXT READING` file list derived from `review-context-map.md`. A dispatch without context reading is invalid.

## Hard stops

- **Never** skip parallel fan-out when scope is large enough to partition — single-monolithic reviews are invalid.
- **Never** replay old findings as fresh — each pass must inspect the current workspace.
- **Never** dispatch an auditor without `REQUIRED CONTEXT READING` from `review-context-map.md`.
- **Never** treat an auditor that returns `NO_ACTIONABLE_ISSUES` as a failure — it is a valid clean result.

## Outputs

- `{review_folder}/review-current-pass-findings.json` (fresh findings, deduplicated)
- Updated `{review_folder}/review-state.json`

## Next step

Proceed to `step-07-findings-aggregation.md`.
