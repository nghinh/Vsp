# Governance Policies

Governance policies enforce quality standards and prevent gaming of quality gates.

## Overview

The governance layer ensures:
- Shallow tests don't count toward coverage
- Every test traces to risk AND oracle
- P0/P1 risks have minimum required coverage
- Bug classification is accurate and nuanced

## Policy Engine

See `policy_engine.yaml` for machine-readable policy definitions.

## Quality Scoring

Quality gate scoring (100 points total):

| Component | Weight | Description |
|-----------|--------|-------------|
| Risk Coverage | 20 | P0/P1 risks have tests |
| Requirement Coverage | 15 | Requirements traced to tests |
| Negative/Boundary Coverage | 15 | Edge cases covered |
| State Transition Coverage | 15 | Workflow states tested |
| Property/Invariant Coverage | 10 | Invariants verified |
| API Contract/Fuzz Coverage | 10 | API schema tested |
| E2E Critical Path Coverage | 10 | User journeys covered |
| Mutation Quality | 5 | Mutants killed |

## Hard Fail Conditions

The following conditions always fail the quality gate regardless of score:

- P0 risk has no executable test or JUSTIFIED_EXCEPTION
- P1 business-critical state transition has no test
- Test oracle missing or incomplete
- Failed tests not triaged
- Critical module has only shallow tests
- No negative/boundary tests for critical area
- P0/P1 risk lacks test_id→risk_id→oracle_id traceability

## Anti-Gaming Rules

See `policy_engine.yaml` for anti-gaming configurations including:
- Shallow test detection
- Coverage inflation detection
- Duplicate test detection

## Approval Workflow

Exceptions to policies require approval:
- JUSTIFIED_EXCEPTION for P0/P1 minimum coverage
- Conditional pass below 85% score
- Skip of blocking checkpoint

## Version

Version: 1.0.0
Related: runtime/checkpoints/, runtime/decision_requests/