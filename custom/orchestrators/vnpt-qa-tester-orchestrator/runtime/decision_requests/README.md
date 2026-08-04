# Decision-request Integration

Decision-request triggers define when an operator decision request is emitted
during QA orchestrator execution.

## Overview

Decision requests capture critical operator decisions when:
- High-severity bugs are found (P0/P1)
- Security issues are discovered
- Exploratory testing is planned
- Risk model changes significantly

## When Decision Request is Required

| Trigger | Condition | Action | Artifact |
|---------|-----------|--------|----------|
| P0 Bug Found | Any PRODUCT_BUG with severity P0 | Approve fix brief | 09-fix-briefs/QA-BUG-XXX.md |
| Security Issue | Bug type = SECURITY_ISSUE | Review classification | 08-failure-triage.md |
| Exploratory Test | test_type = QA-EXP | Review charter | 04i-exploratory-charter.md |
| Risk Model Change | Coverage delta > 10% | Review risk map | 02-risk-map.md |
| Conditional Pass | Quality gate score 70-84% | Approve release | 10-quality-gate-report.md |
| Untriaged Failure | Any failure without type | Complete triage | 08-failure-triage.md |

## Decision Response Types

When decision-request is triggered, operators can respond with:

```yaml
approve_continue:       # Approve current progress and continue
approve_with_changes:   # Approve with patch modifications
request_changes:        # Request additional work before proceeding
reject:                 # Reject current output, restart phase
escalate:               # Escalate to senior QA/architect
```

## File Format

See `decision_request_triggers.yaml` for machine-readable configuration.

## Usage

Run decision-request review:
```bash
python scripts/run_decision_request_review.py docs/qa/<feature>
```

## Integration with Runtime Harness

Decision-request triggers integrate with `vnpt-opencode-runtime` via:
- `.runtime/current/decision-request.json`
- `.runtime/current/decision-response.json`
- `.runtime/current/decision-patch.json`

See runtime harness docs for full integration details.

## Version

Version: 1.0.0
Related: runtime/checkpoints/, runtime/governance/
