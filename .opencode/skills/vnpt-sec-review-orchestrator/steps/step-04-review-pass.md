# Step 04: Review Pass — Parallel Security Audits

**Goal:** Spawn parallel `vnpt-sec-review-auditor` subagents by lane or control family; merge and deduplicate findings into `security-current-pass-findings.json`.

## Sequence

### 1. Determine review lanes

From `security-risk-map.md` and `config/security-lane-routing.yaml`, determine the lanes to audit:
- Group by lane or control family, not by arbitrary file chunks
- One auditor per lane/family

Example lane grouping:
- Lane 1: `auth` (authn/authz/session/token)
- Lane 2: `appsec` (injection/input handling)
- Lane 3: `api` (API abuse/rate limiting/object authorization)
- Lane 4: `devsecops` (secrets/crypto/logging, dependency/supply chain)
- Lane 5: `cloud-k8s` (container/K8s/IaC hardening)
- Lane 6: `compliance` (observability/audit)
- Stack lanes: `nodejs`, `python`, `go`, etc.

### 2. Spawn parallel auditors

For each lane/family, spawn one `vnpt-sec-review-auditor` subagent with:
- Assigned scope (lane-specific subset)
- `security-context-map.md` and `security-risk-map.md` as routing baseline
- `security-scope-policy.yaml` and `security-lane-routing.yaml` as routing baseline
- Hard rule: use source/config evidence first; scanners corroborate only
- Hard rule: treat `.opencode/**` and `vnpt-ai-driven-platform/**` as out of scope unless explicitly targeted
- Hard rule: return `NO_ACTIONABLE_ISSUES` if nothing found — one line

Each auditor must return findings with:
- `issue_id`: deterministic identity
- `issue_signature`: fingerprint
- `title`
- `severity`
- `category`
- `files`
- `evidence_before`: source/config proof
- `fix_recommendation`
- `blocking_validation`
- `success_condition`

### 3. Increment pass counter

Update `security-review-state.json`:
- `pass_count += 1`
- Generate new `latest_pass_id` (e.g., `pass-001`, `pass-002`)
- Append current open issue count to `open_issue_count_history`

### 4. Merge and deduplicate findings

Collect all auditor results:
- Merge into single findings set
- Deduplicate by `issue_signature` (same fingerprint = same issue across lanes)
- For duplicate: keep the one with richer `evidence_before`
- Reconcile `security-live-backlog.json` from the latest pass
  - Issues present in previous backlog but NOT in current pass → closed (with `evidence_after`)
  - Issues in current pass → open/actionable

### 5. Write security-current-pass-findings.json

Write with schema:
```json
{
  "pass_id": "<latest_pass_id>",
  "pass_count": "<N>",
  "findings": [
    {
      "issue_id": "SEC-<001>",
      "issue_signature": "<fingerprint>",
      "title": "...",
      "severity": "critical|high|medium|low",
      "category": "...",
      "files": ["..."],
      "evidence_before": "...",
      "success_condition": "...",
      "status": "open|closed|waived",
      "evidence_after": null
    }
  ]
}
```

### 6. Stall detection

If `open_issue_count_history` shows non-decreasing count for 2 consecutive passes:
- Set `security-review-state.json` status to `stalled`
- Write `forensics.md`
- Narrow scope before continuing

### 7. Decision

- If `security-current-pass-findings.json` has 0 actionable issues → proceed to `step-08-confirmation.md`
- If actionable issues exist → proceed to `step-05-fix-waves.md`

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-current-pass-findings.json` (updated)
- `docs/vnpt-flow/<scope-id>/security-review/security-live-backlog.json` (reconciled)
- `docs/vnpt-flow/<scope-id>/security-review/security-review-state.json` (pass count incremented)

## Next step

If no actionable issues: `step-08-confirmation.md`
If actionable issues exist: `step-05-fix-waves.md`
