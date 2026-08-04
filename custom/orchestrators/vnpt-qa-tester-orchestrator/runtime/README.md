# QA Tester Orchestrator Runtime Harness

This directory contains runtime harness integration for the QA Tester Orchestrator,
providing checkpoint enforcement, decision-request triggers, and governance policies.

## Directory Structure

```
runtime/
├── checkpoints/
│   ├── checkpoint_definitions.yaml   # Phase-based checkpoints with enforcement rules
│   └── README.md
├── decision_requests/
│   ├── decision_request_triggers.yaml    # When an operator decision request is emitted
│   └── README.md
└── governance/
    ├── policy_engine.yaml            # Quality policies and anti-gaming rules
    ├── approval_workflow.yaml        # Approval workflow for exceptions
    └── README.md
```

## Checkpoints

Checkpoints are enforced at key phases to ensure quality gates are not bypassed:

| ID | Name | Phase | Blocking | Description |
|----|------|-------|----------|-------------|
| CP-01 | Context Completion | 01 | Yes | BMAD docs 0-EOF proof exists |
| CP-02 | Risk Map Completeness | 02 | No | P0 risks have test strategy |
| CP-03 | Oracle Before Automation | 05 | Yes | Oracle exists for all tests |
| CP-04 | Quality Gate | 10 | No | Hard fails passed before final report |

## Decision Request Triggers

Decision requests are emitted when:
- P0 bugs are found (approve fix brief)
- Exploratory tests are planned (review charter)
- SECURITY_ISSUE bugs found (review classification)
- Coverage delta > 10% (review risk model change)

## Governance Policies

Key policies enforced:
- `no_shallow_tests_count`: Shallow tests don't count toward coverage
- `traceable_test_coverage`: Every test must trace to risk AND oracle
- `p0_risk_minimum_coverage`: P0 requires >=1 happy + >=2 negative + >=2 boundary

## Usage

Run checkpoint enforcement:
```bash
python scripts/run_checkpoints.py CP-01 docs/qa/<feature>
python scripts/run_checkpoints.py all docs/qa/<feature>
```

Run decision-request review:
```bash
python scripts/run_decision_request_review.py docs/qa/<feature>
```

## Version

Version: 1.0.0
Integration with: vnpt-opencode-runtime (harness agent)
