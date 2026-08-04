# Story Orchestrator State Machine

## Phase States

```
discovery
  ↓
planning_artifacts_ready
  ↓
executing_wave_1 → executing_wave_2 → ... → executing_wave_n
  ↓
merge_and_validate
  ↓
quality_gate ←──────────────────────┐
  ↓                               │
fix_loop (if issues) ─────────────┘
  ↓
done
```

## Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Story run started, not yet complete |
| `in_progress` | Currently executing |
| `done` | Story completed successfully |
| `stalled` | Stuck in fix loop, issue count not decreasing |

## BMAD Story Status

| Status | Routing |
|--------|---------|
| `ready-for-dev` | Planning → Execute → Quality |
| `in-progress` | Planning (resume) → Execute → Quality |
| `review` | Quality Gate only |
| `done` | Skip to wrapup |

## Quality Loop

```
quality_gate:
  → review pass (0 issues) → done
  → review pass (issues) → fix_loop
                          ↓
                 fix issues
                          ↓
                 re-review
                          ↓
               if issues decrease → quality_gate
               if issues same 2x → stalled
```

## Routing Decision

```
DISCOVERY:
  if bmad_status = done → routing = skip
  if bmad_status = ready-for-dev → routing = planning
  if bmad_status = in-progress → routing = planning
  if bmad_status = review → routing = quality
```
