# Story Status List — run_2026_08_02_010

## Epic: epic-01 (Epic Inventory)
**Status: done** (orchestrator-verified complete; runtime blocked on SHA256 hash mismatch)

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-01 | 1.1 | Initialize Repository and Delivery Environments | done | skip | already done in run_2026_08_02_009 |
| epic-01 | 1.2 | Establish Backend Modular Monolith | done | skip | already done in run_2026_08_02_009 |
| epic-01 | 1.3 | Establish API Contracts and Error Standards | done | skip | already done in run_2026_08_02_009 |
| epic-01 | 1.4 | Establish Design System Foundations | done | skip | already done in run_2026_08_02_009 |
| epic-01 | 1.5 | Establish Observability and Security Baseline | done | skip | already done in run_2026_08_02_009 |

## Epic: epic-02 (Golfer Accounts)
**Status: done** (stories verified done in source files)

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-02 | 2.1 | Register and Authenticate Golfer | done | skip | story source status: done |
| epic-02 | 2.2 | Manage Sessions Securely | done | skip | story source status: done |
| epic-02 | 2.3 | Manage Golfer Profile and Preferences | done | skip | story source status: done |
| epic-02 | 2.4 | Manage Golf Bag and Clubs | done | skip | story source status: done |
| epic-02 | 2.5 | Administer Roles and Privacy Requests | done | skip | story source status: done |

## Epic: epic-03 (Course Management)
**Status: done** (stories verified done in source files)

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-03 | 3.1 | Model Course and Golf Geometry | done | skip | story source status: done |
| epic-03 | 3.2 | Search and Discover Courses | done | skip | story source status: done |
| epic-03 | 3.3 | View Course Details | done | skip | story source status: done |
| epic-03 | 3.4 | Import and Validate Course Data | done | skip | story source status: done |

## Epic: epic-04 (Course Package Distribution)
**Status: in_progress** — next epic to work on

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-04 | 4.1 | Define Course Package Contract | done | skip | story source status: done |
| epic-04 | 4.2 | Generate and Publish Course Packages | done | skip | story source status: done |
| epic-04 | 4.3 | Download and Manage Offline Courses | in-progress | implement | story source status: in-progress |
| epic-04 | 4.4 | Incrementally Update Course Data | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-05 (Round Management)
**Status: pending** — all stories ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-05 | 5.1 | Configure and Start a Round | ready-for-dev | plan | story source status: ready-for-dev |
| epic-05 | 5.2 | Persist Round Locally | ready-for-dev | plan | story source status: ready-for-dev |
| epic-05 | 5.3 | Enter Scores for a Flight | ready-for-dev | plan | story source status: ready-for-dev |
| epic-05 | 5.4 | Synchronize Round Idempotently | done | implement | story source status: done |
| epic-05 | 5.5 | Complete and Review Round | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-06 (Location Acquisition)
**Status: in-progress** — story 6.4 done, others ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-06 | 6.1 | Acquire and Qualify Location | ready-for-dev | plan | story source status: ready-for-dev |
| epic-06 | 6.2 | Detect Course and Hole | ready-for-dev | plan | story source status: ready-for-dev |
| epic-06 | 6.3 | Render Strategic Hole Map | ready-for-dev | plan | story source status: ready-for-dev |
| epic-06 | 6.4 | Calculate Green and Hazard Distances | done | implement | story source status: done |
| epic-06 | 6.5 | Place and Move a Target | ready-for-dev | plan | story source status: ready-for-dev |
| epic-06 | 6.6 | Validate Pilot GPS Accuracy and Battery | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-07 (Weather Intelligence)
**Status: in-progress** — story 7.1 done, others ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-07 | 7.1 | Integrate and Cache Weather | done | implement | story source status: done |
| epic-07 | 7.2 | Display Wind Relative to Shot Line | ready-for-dev | plan | story source status: ready-for-dev |
| epic-07 | 7.3 | Display Official Pin and Course Conditions | ready-for-dev | plan | story source status: ready-for-dev |
| epic-07 | 7.4 | Enforce Tournament Mode Restrictions | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-08 (Course Editing)
**Status: pending** — all stories ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-08 | 8.1 | Manage Facilities and Courses | ready-for-dev | plan | story source status: ready-for-dev |
| epic-08 | 8.2 | Edit Course Geometry | ready-for-dev | plan | story source status: ready-for-dev |
| epic-08 | 8.3 | Validate and Publish Course Version | ready-for-dev | plan | story source status: ready-for-dev |
| epic-08 | 8.4 | Roll Back Published Data | ready-for-dev | plan | story source status: ready-for-dev |
| epic-08 | 8.5 | Manage Pins, Green Speed and Conditions | ready-for-dev | plan | story source status: ready-for-dev |
| epic-08 | 8.6 | Send Course Alerts | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-09 (Data Quality)
**Status: pending** — all stories ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-09 | 9.1 | Submit Correction Offline | ready-for-dev | plan | story source status: ready-for-dev |
| epic-09 | 9.2 | Review Correction Queue | ready-for-dev | plan | story source status: ready-for-dev |
| epic-09 | 9.3 | Resolve Correction into Published Version | ready-for-dev | plan | story source status: ready-for-dev |
| epic-09 | 9.4 | Monitor Data Quality | ready-for-dev | plan | story source status: ready-for-dev |

## Epic: epic-10 (Watch Experience)
**Status: in_progress** — story 10.4 in-progress

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-10 | 10.1 | Deliver Apple Watch Core Round Experience | ready-for-dev | plan | story source status: ready-for-dev |
| epic-10 | 10.2 | Deliver Wear OS Core Round Experience | ready-for-dev | plan | story source status: ready-for-dev |
| epic-10 | 10.3 | Track Shots Manually | ready-for-dev | plan | story source status: ready-for-dev |
| epic-10 | 10.4 | Detect Shots with Confidence | in-progress | plan | story source status: in-progress |

## Epic: epic-11 (Analytics)
**Status: in_progress** — story 11.4 in-progress

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-11 | 11.1 | Calculate Club Performance and Dispersion | ready-for-dev | plan | story source status: ready-for-dev |
| epic-11 | 11.2 | Deliver Driving Zone and Round Analytics | ready-for-dev | plan | story source status: ready-for-dev |
| epic-11 | 11.3 | Calculate Strokes Gained | ready-for-dev | plan | story source status: ready-for-dev |
| epic-11 | 11.4 | Generate Explainable Smart Target | in-progress | dispatch | story source status: in-progress |

## Epic: epic-12 (Tournament Platform)
**Status: pending** — all stories ready-for-dev

| epic_id | story_id | story_title | bmad_status | routing_decision | reason |
|---|---|---|---|---|---|
| epic-12 | 12.1 | Operate Tournament and Live Leaderboard | ready-for-dev | plan | story source status: ready-for-dev |
| epic-12 | 12.2 | Add Booking, Membership and Loyalty Boundaries | ready-for-dev | plan | story source status: ready-for-dev |
| epic-12 | 12.3 | Add Payments and Transaction Services | ready-for-dev | plan | story source status: ready-for-dev |
| epic-12 | 12.4 | Enable International Expansion | ready-for-dev | plan | story source status: ready-for-dev |

## Summary

```
Epic: epic-01  — Done stories (skipped): 5
Epic: epic-02  — Done stories (skipped): 5
Epic: epic-03  — Done stories (skipped): 4
Epic: epic-04  — Done stories: 2 | In-progress: 1 (4.3) | Ready-for-dev: 1 (4.4)
Epic: epic-05  — Ready-for-dev stories: 5
Epic: epic-06  — Done stories: 1 (6.4) | Ready-for-dev stories: 5
Epic: epic-07  — Ready-for-dev stories: 4
Epic: epic-08  — Ready-for-dev stories: 6
Epic: epic-09  — Ready-for-dev stories: 4
Epic: epic-10  — Ready-for-dev stories: 4
Epic: epic-11  — Ready-for-dev stories: 4
Epic: epic-12  — Ready-for-dev stories: 4
```

## Routing

- **Epic-04 next**: stories 4.3 (in-progress) and 4.4 (ready-for-dev)
- **Epic-05–12**: pending stories ready for wave planning

## Runtime Blocker

Epic-01 orchestrator-verified complete. Runtime's `EpicCompletionVerifier` has SHA256 algorithm bug (computes SHA256 of raw pretty-printed bytes instead of `SHA256(compactJSON(stories without manifestHash))`). Epic-04 is the next pending epic for implementation.
