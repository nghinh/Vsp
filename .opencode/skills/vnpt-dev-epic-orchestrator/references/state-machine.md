> **Ownership:** Skill-layer (LLM agent facing). NOT consumed by `vnpt-go-runtime`.
> 
> The state machine below describes the **story-level workflow** (`preflight → planning → executing → validating → review_gate → done`) and the 7 skill-specific failure reason classes (`missing_prd_context_evidence`, etc.). These concepts do not exist in the Go runtime.
> 

# Epic & Phase State Machine

> Status values come from `data/orchestrator-policy.json` (pinned at run start). The orchestrator MUST honor the pinned snapshot for the entire run; do not reinterpret values mid-run.

## Epic states

```
   pending
      |
      v
   in_progress ──────► review_gate ──────► done
      |                     |                 ▲
      |                     v                 │
      |                  fix_loop ────────────┘  (review reports 0 issues)
      |                     │
      |                     ▼
      ├─────────► failed ◄──┤
      |                     │
      |                     ▼
      └────────► stalled_partial ◄── (2+ consecutive same-reason failures)
```

| State | Meaning | Allowed transitions |
| --- | --- | --- |
| `pending` | Discovered, not yet started | → `in_progress` |
| `in_progress` | Stories are executing | → `review_gate` / `failed` / `stalled_partial` |
| `review_gate` | All stories `done`, awaiting review | → `done` / `in_progress` (fix loop) / `failed` |
| `done` | Review gate clean, all artifacts written | (terminal) |
| `failed` | Hard failure (governance, capability mismatch) | → `in_progress` (manual reset) / (terminal) |
| `stalled_partial` | 2+ consecutive same-reason failures | → `in_progress` (manual reset) / (terminal) |

## Phase states (per story)

```
   preflight ──► planning ──► executing ──► validating ──► review_gate ──► done
                   │             │             │              │
                   ▼             ▼             ▼              ▼
                            failed ◄──────────────────────────┘
```

| State | Meaning | Allowed transitions |
| --- | --- | --- |
| `preflight` | Context + skill loading checks | → `planning` / `failed` |
| `planning` | `vnpt-epic-story-runner` in PLANNING mode | → `executing` / `failed` |
| `executing` | `vnpt-epic-story-implementer` runs slices | → `validating` / `failed` |
| `validating` | Slice dedup gate + validations | → `review_gate` / `failed` |
| `review_gate` | `vnpt-epic-story-runner` in QUALITY-GATE mode | → `done` / `failed` |
| `done` | Quality gate clean, status moved to `done` | (terminal) |
| `failed` | Hard failure with `failure_reason_class` | → (terminal) |

## Failure reason classes

From `data/orchestrator-policy.json` → `failureReasonClasses`:

| Class | Triggered by | Detection |
| --- | --- | --- |
| `missing_prd_context_evidence` | Empty `prd_sources_read` | `phase-state.json` evidence check |
| `missing_context_evidence` | Empty `project_context_sources_read` or `story_sources_read` | Evidence check |
| `missing_ux_context_evidence` | UX/UI required, `mockup_sources_read` empty | Evidence check |
| `technical_debt_policy_violation` | Anti-shortcut signals indicate downgrade | Anti-shortcut evidence check |
| `story_status_not_progressed` | Completed story still in `ready-for-dev` / `draft` / `in-progress` | BMAD story-status check |
| `story_status_invalid_done` | Story marked `done` but failed validation/review | BMAD story-status check |
| `duplicate_detection_failed` | Slice dedup chain ended in failed state | `phase-state.json.duplicate_detection_status` |

## Stall detection

- Track `non_progress_streak` in `epic-state.json`.
- If 2 consecutive stories fail with the **same** `failure_reason_class`:
  - Mark epic `status: stalled_partial`.
  - Write `forensics.md` with root cause analysis.
  - For `technical_debt_policy_violation`, include exact offending phrases/snippets.
  - Continue to the next epic (do not abort the global run).
