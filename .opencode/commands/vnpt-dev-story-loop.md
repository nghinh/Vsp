---
description: VNPT story-first implementation loop for BMAD 6.2.0 + OpenCode
argument-hint: [story-file-or-story-id]
---

You are executing the VNPT story-first delivery loop.

User input: `$ARGUMENTS`

## Pattern: Epic Orchestrator Style

This command follows the step-based execution pattern:
1. Step 01: Discovery — check story status
2. Step 03: Planning + Execute — build plan, execute waves
3. Step 05: Quality Gate — `/vnpt-review-loop`, fix, loop until clean
4. Step 06: Wrapup — finalize

## Story Status Routing

| Status | Routing |
|--------|---------|
| `done` | Skip to wrapup |
| `ready-for-dev` | Planning → Execute → Quality |
| `in-progress` | Planning (resume) → Execute → Quality |
| `review` | Quality Gate only (skip implementation) |

## Discovery Step (Step 01)

1. **Locate story file:**
   - Search `docs/**/implementation-artifacts/**/<story-id>.md`
   - Search `docs/**/planning-artifacts/**/<story-id>.md`

2. **Read story source:**
   - Extract BMAD status from frontmatter or body
   - Parse: description, ACs, tasks, dev notes

3. **Read source-root contract** (if exists)

4. **Route based on status:**
   - `done` → skip to Step 06
   - `ready-for-dev`/`in-progress` → Step 03
   - `review` → Step 05

5. **Create run folder:** `docs/vnpt-flow/<story-id>/`

6. **Materialize context files:**
   - `story-source-read.md`
   - `contract-read.md`
   - `phase-state.json`

## Planning + Execution Step (Step 03)

1. **Spawn `vnpt-story-runner` in PLANNING mode:**
   - Read: story source, contract, PRD, architecture, UX docs
   - Build: slice plan, wave plan, coverage matrix

2. **Coverage gate:** every AC must map to a slice

3. **Preflight gate:** docs readable, scopes deterministic, validations runnable

4. **Execute waves (Step 04):**
   - Spawn `vnpt-story-implementer` per slice
   - Dedup protocol: pre-write gate → write → post-write gate → reindex
   - Parallel for independent slices, sequential for dependent

5. **Merge results** to `validation-report.md`

## Quality Gate Step (Step 05)

1. **Generate `review-handoff.md`:**
   - Summary of scope, changed files, validations, risks

2. **Run `/vnpt-review-loop`:**
   ```
   /vnpt-review-loop docs/vnpt-flow/<story-id>/review-handoff.md
   ```

3. **If issues found:** fix → validate → re-review → loop until clean

4. **Stall detection:** if issues not decreasing for 2 loops → mark stalled

## Wrapup Step (Step 06)

1. **Verify all artifacts exist**
2. **Update `phase-state.json`** to `status: done`
3. **Write `story-summary.md`**
4. **Update story source** to mark done

## Hard Stop Rules

- Never skip discovery — always check story status first
- Never proceed to execution without coverage complete
- Never parallelize overlapping write scopes
- Never skip dedup protocol
- Never mark done while `/vnpt-review-loop` reports actionable issues
- Never report done while validations failing

## Intent Detection

| Keyword | Intent |
|---------|--------|
| (none) / story-id | Create — new run from discovery |
| `resume` / `continue` | Resume — from `phase-state.json` |

## Completion

Story is complete only when:
- BMAD status is `done`
- All ACs implemented
- Validations clean
- `/vnpt-review-loop` reports zero actionable issues
- `phase-state.json` is `done`
