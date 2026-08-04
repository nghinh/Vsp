> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by any runtime service.

# Security Review Workflow State Machine

> Status values come from `data/orchestrator-policy.json` (pinned at run start). The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret values mid-run.

## Run states

```
   pending
      |
      v
   preflight ──► context_discovery ──► security_map ──► review_pass
      |                 |                    |               |
      v                 v                    v               v
   failed           (done)               (done)        fix_waves
                                                            |
                                                            v
                                                        validation
                                                            |
                                                            v
                                                       fresh_review
                                                            |
                        ┌───────────────────────────────────┘
                        v
              confirmation_pending ──► complete
                        |
                        v
                   fresh_review (if confirmation finds issues)
```

| State | Meaning | Allowed transitions |
|-------|---------|---------------------|
| `pending` | Scope not yet resolved | → `preflight` |
| `preflight` | Validating scope and tooling | → `context_discovery` / `failed` |
| `context_discovery` | BMAD docs inventory and 0-EOF proof | → `security_map` / `failed` |
| `security_map` | Stack detection and lane routing | → `review_pass` / `failed` |
| `review_pass` | Parallel auditor pass | → `fix_waves` / `confirmation_pending` |
| `fix_waves` | Non-overlapping fix workers | → `validation` |
| `validation` | Targeted stack validation | → `fresh_review` |
| `fresh_review` | Brand new review from current workspace | → `fix_waves` / `confirmation_pending` |
| `confirmation_pending` | Awaiting mandatory confirmation pass | → `complete` / `fresh_review` |
| `complete` | Zero issues + validator passed | (terminal) |
| `stalled` | 2+ consecutive non-decreasing issue counts | → `fresh_review` (narrowed scope) |
| `failed` | Hard failure (scope unresolved, tooling missing) | (terminal) |

## Stall detection

- Track `non_progress_streak` in `security-review-state.json` via `open_issue_count_history`.
- If issue count is non-decreasing for 2 consecutive passes (review → fix → validate → fresh_review loop):
  - Mark `status: stalled`.
  - Write `forensics.md` with root cause analysis.
  - Narrow scope before continuing (skip to `confirmation_pending` or terminate).

## Confirmation gate

- After first zero-issue fresh review pass, MUST run one extra confirmation pass.
- `confirmationMandatory: true` in `orchestrator-policy.json`.
- Only marks `complete` after `fresh_confirmation_pass_done: true` AND validator passes.
