> **Ownership:** Skill-layer (LLM agent facing).

# Story Artifact Schemas

## phase-state.json

```json
{
  "story_id": "string",
  "phase": "discovery | planning_artifacts_ready | executing_wave_n | merge_and_validate | quality_gate | fix_loop | stalled | done",
  "status": "pending | in_progress | done | stalled",
  "bmad_status": "ready-for-dev | in-progress | review | done",
  "routing_decision": "skip | planning | quality",
  "context_read": "boolean",
  "contract_read": "boolean",
  "wave_count": "number",
  "waves": [
    {
      "wave": "number",
      "slices": ["string"],
      "parallel": "boolean"
    }
  ],
  "completed_waves": ["number"],
  "current_wave": "number | null",
  "review_pass_count": "number",
  "open_issue_count_history": ["number"],
  "quality_status": "clean | pending | failed",
  "duplicate_detection_status": "string | null",
  "started_at": "ISO8601",
  "updated_at": "ISO8601",
  "completed_at": "ISO8601 | null"
}
```

## story-source-read.md Format

```markdown
# Story Source: {story_id}

## Story Info
- **ID:** {id}
- **Title:** {title}
- **BMAD Status:** {status}

## Description
{story description}

## Acceptance Criteria
{AC list}

## Tasks / Subtasks
{task list}

## Dev Notes
{dev notes}
```

## contract-read.md Format

```markdown
# Contract: {story_id}

## Source-Root Contract
{contract content or "No explicit contract; epic summary used as implicit contract"}
```

## story-context-packet.md Format

```markdown
# Story Context Packet: {story_id}

## Story Intent
{intent description}

## Constraints
{constraints list}

## Acceptance Criteria
{AC list}

## Linked Documents
- PRD: {path}
- Architecture: {path}
- UX/UI: {path}
```

## execution-plan.md Format

```markdown
# Execution Plan: {story_id}

## Slice Objectives
### Slice {n}: {objective}
- Dependencies: {list}
- Wave: {wave_number}

## Wave Assignments
- Wave 1 (parallel): {slice list}
- Wave 2 (sequential): {slice list}
```

## slice-matrix.md Format

```markdown
# Slice Matrix: {story_id}

## Slices
| Slice | Owner | Allowed Paths | Blocked Paths | Validations |
|-------|-------|---------------|---------------|-------------|
| {id} | {owner} | {paths} | {paths} | {commands} |

## Duplicate Detection Outcomes
{per-slice outcome}
```

## requirements-coverage.md Format

```markdown
# Requirements Coverage: {story_id}

## Acceptance Criteria Mapping
| AC ID | AC Description | Mapped Slices | Status |
|-------|---------------|---------------|--------|
| {id} | {desc} | {slices} | covered | uncovered |

## Coverage Gate
- All criteria covered: {boolean}
```

## validation-report.md Format

```markdown
# Validation Report: {story_id}

## Wave {N} Results
| Slice | Status | Files | Validation |
|-------|--------|-------|------------|
| {id} | pass/fail | {files} | {results} |

## Summary
- Total Slices: {n}
- Passed: {n}
- Failed: {n}
```

## review-handoff.md Format

```markdown
# Story {story_id} Review Handoff

## Story Info
- **Story ID:** {id}
- **BMAD Status:** review

## Implementation Scope
- Changed files: {list}
- Slices implemented: {list}

## Validations
{validation results}

## Remaining Risks
{risks list}
```

## forensics.md Format

```markdown
# Forensics: {story_id}

## Failure Phase
{phase}

## Likely Root Cause
{cause}

## Repeated Files/Scopes
{list}

## Failing Validation Commands
{commands}

## Recommended Next Action
{action}
```

## story-summary.md Format

```markdown
# Story {story_id} Summary

## Story Info
- **Title:** {title}
- **BMAD Status:** done
- **Routing:** {routing}

## Execution
- **Waves Executed:** {count}
- **Slices Implemented:** {count}
- **Quality Loops:** {count}

## Validation Results
{results table}

## Quality Summary
- Critical Issues: {n}
- Major Issues: {n}
- Minor Issues: {n}

## Changed Files
{list}

## Residual Risks
{risks}
```
