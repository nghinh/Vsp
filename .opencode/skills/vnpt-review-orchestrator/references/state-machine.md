> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by any runtime service.

> The state machine below describes the **review-level workflow** (scope detection, review passes, fix waves, validation, confirmation). Status values come from `data/orchestrator-policy.json` (pinned at run start). The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret values mid-run.

# Review State Machine

## Run states

```
   pending
      |
      v
   in_progress ──────► stalled ◄── (2+ consecutive non-decreasing open counts)
      |                     |
      |                     v
      |                  failed (hard failure, capability mismatch)
      |
      +───────────────────► complete (zero open issues + confirmation pass)
```

| State | Meaning | Allowed transitions |
|-------|---------|---------------------|
| `pending` | Scope detected, run not started | → `in_progress` |
| `in_progress` | Review/fix loop actively running | → `stalled` / `complete` / `failed` |
| `stalled` | 2+ consecutive passes with non-decreasing open issue count | → `in_progress` (resume after strategy change) / `failed` |
| `complete` | Zero open issues, confirmation pass done | (terminal) |
| `failed` | Hard failure (schema validation, blocker) | → `in_progress` (manual reset) / (terminal) |

## Phase states (per pass)

```
   scope_and_mode ──► docs_inventory ──► context_map ──► risk_map
          │                                              │
          v                                              v
   review_pass ──► findings_aggregation ──► fix_waves ──► validation
          ^                                                      │
          │                                                      v
          └─────────────────── fresh_rereview ◄── (if open issues remain)
                                                                   │
                                                                   v
                                                     confirmation_rereview ──► complete
```

| Phase | Meaning | Allowed transitions |
|-------|---------|-------------------|
| `scope_and_mode` | Scope detection and mode determination | → `docs_inventory` / `in_progress` |
| `docs_inventory` | BMAD docs scan (if docs/ exists) | → `context_map` |
| `context_map` | Context map artifact build | → `risk_map` |
| `risk_map` | Risk taxonomy and validation routing | → `review_pass` |
| `review_pass` | Fan-out parallel auditors, collect findings | → `findings_aggregation` |
| `findings_aggregation` | Merge + dedupe findings vs. backlog | → `fix_waves` / `fresh_rereview` |
| `fix_waves` | Build fix waves, fan-out fix workers | → `validation` |
| `validation` | Run stack-aware validations, artifact validator | → `fresh_rereview` |
| `fresh_rereview` | Brand-new review after fixes | → `fix_waves` (loop) / `confirmation_rereview` (zero issues) |
| `confirmation_rereview` | Final zero-issue confirmation | → `complete` / `fresh_rereview` (still issues) |

## Finding lifecycle

```
      open
        │
        v
   in_progress (being fixed)
        │
        v
      stalled (fix failed, retry needed)
        │
        v
   fixed (fix applied, evidence provided)
        │
        v
   closed (confirmed fixed, no further action)
```

| Status | Meaning |
|--------|---------|
| `open` | Issue exists, awaiting fix |
| `in_progress` | Fix worker actively addressing |
| `stalled` | Fix attempted but failed validation |
| `fixed` | Fix applied, evidence provided |
| `closed` | Confirmed resolved |
| `waived` | Accepted risk with justification |
| `deferred` | Punted to future iteration |

## Severity taxonomy

| Severity | Blocking? | Examples |
|----------|-----------|----------|
| `critical` | Yes | Security vulnerability, data loss risk |
| `high` | Yes | Major logic error, broken feature |
| `medium` | Eventually | Style violation, minor logic issue |
| `low` | Eventually | Cosmetic, minor perf issue |
| `info` | No | Suggestion, documentation gap |

## Stall detection

- Track `open_issue_count_history` in `review-state.json`
- If `history[n] >= history[n-1] >= history[n-2]` (non-decreasing for 2+ passes):
  - Mark `status: stalled`
  - Write `forensics.md` with root cause analysis
  - Narrow scope and retry

## Closure rules (HARD)

1. **Never close without `evidence_after`** — any closed/fixed/waived/deferred item must have observable post-fix evidence.
2. **Never complete without confirmation pass** — `status: complete` requires `fresh_confirmation_pass_done: true`.
3. **Never complete while issues are open** — both current-pass findings and backlog must be empty of open items.
4. **Non-decreasing history is a stall** — if open count is non-decreasing for 2 consecutive passes → `status: stalled`.
5. **Minimum pass count** — completion requires at least 2 passes.
