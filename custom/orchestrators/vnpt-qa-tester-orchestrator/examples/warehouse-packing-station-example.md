# Example: Warehouse Packing Station QA

This example shows how `vnpt-qa-tester-orchestrator` should think for a packing-station replenishment product.

## High-risk behaviors

| Risk ID | Risk | Priority | Strategy |
|---|---|---:|---|
| RISK-001 | Duplicate replenishment request when operator double taps | P0 | state-machine + E2E + API |
| RISK-002 | Negative or zero quantity accepted | P0 | property + boundary |
| RISK-003 | Offline sync creates duplicate task after reconnect | P0 | stateful + E2E |
| RISK-004 | Cancelled request still delivered | P1 | state-machine |
| RISK-005 | Robot unavailable but UI shows request confirmed | P1 | integration + E2E |

## Example combinatorial dimensions

```text
StationState: Idle, Busy, Blocked
NetworkState: Online, Offline, Timeout
InventoryState: Available, Low, Unavailable
RequestStatus: Draft, Pending, Assigned, Delivered, Cancelled, Failed
Action: CreateRequest, CancelRequest, Retry, ConfirmDelivery
Quantity: Zero, One, Normal, Large, Negative, Decimal
```

## Example state model

```text
Draft -> Pending -> Assigned -> Delivered -> Confirmed
Draft -> Cancelled
Pending -> Timeout -> RetryPending
Pending -> Cancelled
Assigned -> Failed -> RetryPending
```

Forbidden examples:

```text
Cancelled -> Delivered
Confirmed -> Pending
Failed -> Confirmed without retry
```

## Example invariants

- quantity must be a positive integer
- one station request must not create two active robot tasks
- cancelled request must never be delivered
- offline sync must be idempotent
- completed request must not become pending again
- UI state must reflect backend request status after refresh
