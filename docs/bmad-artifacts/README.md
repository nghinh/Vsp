# BMAD Artifacts — Vietnam Smart Golf Platform (VSP)

## Canonical Artifact Root

All BMAD lifecycle artifacts for VSP land under this directory. This directory is the single source of truth for:
- Story completion certificates
- Verification evidence records
- Contract approvals
- Source-of-truth classification

## Directory Structure

```
docs/bmad-artifacts/
├── README.md                         ← this file
├── artifact-index.yaml               ← FTS5-indexed artifact registry
├── project/
│   ├── source-of-truth-map.md        ← artifact classification register
│   └── lifecycle-status.yaml          ← epic/story lifecycle state machine
├── contracts/                        ← approved API/domain contracts
├── stories/                          ← per-story acceptance matrices + evidence
└── verification/                     ← lane-verifier evidence records
```

## Bootstrap

Created by: `vnpt-dev-epic-orchestrator` during epic-01 execution
Date: 2026-08-02
