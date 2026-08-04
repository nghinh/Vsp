# vnpt-dev-story-orchestrator Workflow

## Story Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│  vnpt-dev-story-orchestrator (main orchestrator)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 01: Discovery — Check story status                    │
│  - Read story source file                                   │
│  - Classify: done|planning|quality                          │
│  - Read source-root contract                                │
│  - Update phase-state.json                                  │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         [done]        [planning]        [quality]
         (skip)      (Step 02)        (Step 03)
                              │               │
                              ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 02: Planning + Implementation                         │
│  - Spawn vnpt-story-runner (PLANNING mode)                  │
│  - Build slice plan, wave plan, coverage matrix             │
│  - Spawn vnpt-story-implementer agents per wave             │
│  - Execute waves with dedup protocol                        │
│  - Run validations                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 03: Quality Gate                                      │
│  - Spawn vnpt-story-review-auditor agents per slice         │
│  - Collect review feedback                                  │
│  - If issues found: spawn vnpt-story-fix-worker agents      │
│  - Loop until clean                                         │
│  - Update validation-report.md                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 04: Wrapup                                            │
│  - Final validation                                         │
│  - Update phase-state.json to done                          │
│  - Summary report                                           │
└─────────────────────────────────────────────────────────────┘
```

## State Machine

```
preflight → discovery → planning_artifacts_ready → executing_wave_n
    → merge_and_validate → quality_gate → fix_loop → done
                     ↑                           │
                     └───────────────────────────┘
                      (if quality gate fails)
```

## Quality Loop

```
Quality Gate:
  auditor review → if pass → done
                  → if issues → fix-worker implements fixes
                               → auditor re-reviews
                               → loop until clean or max_attempts
```
