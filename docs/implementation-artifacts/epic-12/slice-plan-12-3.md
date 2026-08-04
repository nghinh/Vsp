# Slice Plan — Story 12.3: Add Payments and Transaction Services

## Story Metadata

| Field | Value |
|-------|-------|
| Story ID | 12.3 |
| Epic | 12 (Tournament Platform) |
| Phase | MVP 4 |
| Status | `in-progress` |
| Dependencies | 12.2 (booking/membership/loyalty boundaries — `ready-for-dev`) |
| Source | `docs/implementation-artifacts/epic-12/12-3-add-payments-and-transaction-services.md` |

---

## Context: What 12.3 Must Build

From acceptance criteria:
1. **Payment provider handles sensitive payment details; platform stores no prohibited card data.**
   → Platform only stores a payment reference/token from the provider. No PAN, CVV, expiry stored.
2. **Transactions are idempotent, auditable, refundable where required, and reconciled.**
   → Idempotency key on every write. Full audit trail. Refund workflow. Daily reconciliation job.
3. **Failure and pending states are explicit to user and operator.**
   → Explicit `pending`, `failed`, `succeeded`, `refunded` states. Clear error messages.

Epic 12 AC also says: "Domain boundaries prevent payment/customer operations from coupling to core GPS rounds" (from 12.2).

---

## Dependency Note

Story 12.2 (`Add Booking, Membership, and Loyalty Boundaries`) is `ready-for-dev` and establishes domain boundaries for booking, membership, loyalty, and sponsorship. Story 12.3 must consume those boundaries and extend the Payments module alongside them. Both stories should be planned together in the epic wave, but 12.3 can proceed with its own module skeleton while 12.2 is being implemented.

---

## Architecture Placement

```
apps/
  api/                           # Modular monolith backend
    modules/
      payments/                  # NEW: isolated payments module
        domain/
          models/                # PaymentTransaction, PaymentMethod, RefundRequest
          services/              # PaymentService (orchestrates provider)
          repositories/           # IPaymentRepository
        infrastructure/
          persistence/           # PostgreSQL persistence (no card data)
          provider/              # PaymentProviderAdapter (Stripe/payOS/VNPay interface)
          idempotency/           # IdempotencyStore
          audit/                 # PaymentAuditLog
        presentation/
          controllers/           # PaymentController
          dtos/                  # Request/response DTOs
      booking/                   # From 12.2 — defines booking entities consumed here
      membership/                # From 12.2
      loyalty/                   # From 12.2
packages/
  contracts/
    schemas/payment.yaml          # NEW: OpenAPI payment schemas
    openapi.yaml                 # Updated with /payments/* routes
```

**Critical constraint**: No card data, no PAN, CVV, expiry month/year crosses the `payments` module boundary or enters the platform database. Only opaque `paymentMethodRef` (provider token) is stored.

---

## Slice Plan

### Slice 1: Payment Contracts and Domain Models
**Intent**: Establish the schema and domain model that all downstream slices depend on.

**Files to create/modify**:
- `packages/contracts/schemas/payment.yaml` — NEW: Transaction, PaymentMethodRef, RefundRequest, PaymentState enums, payment request/response schemas
- `packages/contracts/openapi.yaml` — Add `/payments/*` paths: POST /payments/intent, GET /payments/{id}, POST /payments/{id}/refund, GET /payments/{id}/audit
- `packages/contracts/lib/src/dto/payment_dto.dart` — NEW: Dart DTOs matching schemas
- `packages/domain/lib/src/payment/` — NEW: `payment_transaction.dart`, `payment_state.dart`, `refund_request.dart` domain models

**Acceptance**:
- OpenAPI schema validates: no `cardNumber`, `cvv`, `expiryMonth`, `expiryYear` fields in any request/response
- `PaymentState` enum covers: `pending`, `succeeded`, `failed`, `refunded`, `partially_refunded`
- Idempotency key field present on intent creation request

---

### Slice 2: Payments Module — Infrastructure Layer
**Intent**: Persistence, idempotency, audit log, and payment provider adapter.

**Files to create**:
- `apps/api/modules/payments/infrastructure/persistence/payment_transaction_table.dart` — PostgreSQL table definition (migration)
- `apps/api/modules/payments/infrastructure/persistence/payment_audit_log_table.dart` — Audit log table
- `apps/api/modules/payments/infrastructure/persistence/idempotency_record_table.dart` — Idempotency dedup table
- `apps/api/modules/payments/infrastructure/persistence/payment_repository.dart` — `IPaymentRepository` implementation
- `apps/api/modules/payments/infrastructure/provider/payment_provider_adapter.dart` — `IPaymentProvider` interface + stub implementation (Stripe/payOS/VNPay — provider is configurable)
- `apps/api/modules/payments/infrastructure/idempotency/idempotency_store.dart` — Checks and stores idempotency keys; TTL-based cleanup

**Acceptance**:
- Repository stores only: `transactionId`, `providerReference`, `paymentMethodRef`, `amount`, `currency`, `state`, `idempotencyKey`, `createdAt`, `updatedAt`, `metadata`
- No card fields in any persistence model
- Idempotency store returns existing result for duplicate key within TTL window

---

### Slice 3: Payments Module — Domain Service and Orchestration
**Intent**: Core business logic: create payment intent, confirm, refund, reconcile.

**Files to create**:
- `apps/api/modules/payments/domain/services/payment_service.dart` — `createPaymentIntent()`, `confirmPayment()`, `refundPayment()`, `getPayment()`, `getAuditLog()`
- `apps/api/modules/payments/domain/services/reconciliation_service.dart` — Daily reconciliation job: compare provider state vs local state, flag discrepancies
- `apps/api/modules/payments/presentation/dtos/` — Request/response DTOs (create intent, confirm, refund)
- `apps/api/modules/payments/presentation/controllers/payment_controller.dart` — REST endpoints

**Acceptance**:
- `createPaymentIntent` generates idempotency key, calls provider, stores transaction with `pending` state
- `confirmPayment` updates state to `succeeded` or `failed` based on provider webhook/callback
- `refundPayment` supports full and partial; creates `RefundRequest` record; calls provider; updates transaction state
- All state transitions are atomic and auditable
- Reconciliation service outputs a discrepancy report

---

### Slice 4: Integration — Booking Flow Consumes Payments
**Intent**: Wire the payment service into the booking module (from 12.2) so a booking can trigger a payment.

**Files to create/modify**:
- `apps/api/modules/booking/domain/services/booking_service.dart` — Add `processPayment()` call after booking creation (when payment is required)
- `apps/api/modules/booking/presentation/controllers/booking_controller.dart` — Return payment intent URL/clientSecret in booking response when payment required
- Update booking DTOs to include `payment: { transactionId, state, amount }` field

**Acceptance**:
- A booking that requires payment returns a `paymentIntentClientSecret` in the response
- Payment state is linked to booking in the audit log
- Booking cannot be confirmed until payment reaches `succeeded` state

---

### Slice 5: Explicit Failure and Pending States — API + UI Contract
**Intent**: Ensure all API responses and mobile UI states are explicit about payment state.

**Files to create/modify**:
- `packages/contracts/schemas/payment.yaml` — Add `PaymentFailureReason` enum (provider_declined, insufficient_funds, network_error, cancelled, unknown)
- `packages/contracts/lib/src/dto/payment_dto.dart` — Add `PaymentStatusResponse` with `state`, `failureReason`, `failureMessage`, `providerReference`, `updatedAt`
- Mobile theme updates: `packages/mobile-theme/lib/components/vsp_payment_status_badge.dart` — NEW component showing `pending` (amber), `succeeded` (green), `failed` (red), `refunded` (blue) with icon + text
- `packages/mobile-theme/lib/components/components.dart` — Export new badge

**Acceptance**:
- Every payment response includes `state` and, when `failed`, a human-readable `failureReason` and `failureMessage`
- Mobile badge shows icon + label, not color alone
- Accessibility: screen reader reads full state text

---

### Slice 6: Automated Tests
**Intent**: Prove correctness of idempotency, state transitions, audit, and reconciliation.

**Files to create**:
- `apps/api/modules/payments/test/payment_service_test.dart` — Unit tests for all service methods
- `apps/api/modules/payments/test/idempotency_store_test.dart` — Duplicate key handling
- `apps/api/modules/payments/test/reconciliation_service_test.dart` — Discrepancy detection
- `apps/api/modules/payments/test/payment_provider_adapter_test.dart` — Stub provider behavior

**Acceptance**:
- Duplicate `createPaymentIntent` with same idempotency key returns same transaction, does not charge twice
- State transitions: pending → succeeded, pending → failed, succeeded → refunded, succeeded → partially_refunded
- All negative paths: invalid amount, provider unavailable, unauthorized, idempotency key conflict

---

## Verification Gates

| Gate | Criteria |
|------|----------|
| Format | Dart/Flutter format pass on all new files |
| Lint | `dart analyze` zero errors on `packages/contracts/`, `packages/domain/payment/` |
| Typecheck | All DTOs and domain models type-check |
| Test | All 4 test files pass |
| Build | Package compilation succeeds |

---

## Anti-Shortcuts Evidence

- ❌ NOT just a stub service returning success — real idempotency + provider adapter required
- ❌ NOT storing card data even in encrypted form — platform stores ZERO prohibited card fields
- ❌ NOT skipping audit log — every state transition logged with actor, timestamp, reason
- ❌ NOT skipping reconciliation — daily job comparing provider vs local state
- ❌ NOT skipping explicit failure states — `failed` state MUST include reason + message

---

## Planning Evidence

| Evidence | Source |
|----------|--------|
| Story spec read | `docs/implementation-artifacts/epic-12/12-3-add-payments-and-transaction-services.md` |
| PRD read | `docs/planning-artifacts/prd.md` (Phase 4 payments deferred from MVP 1; FR24 → Epic 12) |
| Architecture read | `docs/planning-artifacts/architecture.md` (modular monolith, explicit boundaries, idempotency, audit) |
| UX spec read | `docs/planning-artifacts/ux-spec.md` (semantic tokens, state colors, accessibility) |
| Epics read | `docs/planning-artifacts/epics.md` (Story 12.3 AC, Epic 12 context, dependency on 12.2) |
| Epic run status read | `docs/vnpt-flow/epic-run-run_2026_08_02_010/story-status-list.md` (all epic-12 stories `ready-for-dev`) |
| Repo structure checked | `packages/` contains Flutter packages: contracts, domain, mobile-theme, portal-ui, design-tokens, course-package, map-style |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Payment provider SDK not available for MVP build | Medium | Low | Abstract adapter; stub works for tests; real provider injected at runtime |
| 12.2 booking boundaries not ready when 12.3 needs them | Medium | Low | Slice 4 (booking→payments integration) is last; booking module is consumed, not defined by 12.3 |
| Idempotency key collision | Low | High | Use UUIDv7 + provider reference as composite key; TTL window prevents unbounded growth |
| Reconciliation false positives from provider webhook delay | Medium | Medium | Reconciliation uses provider's transaction list API (not just webhooks) with lookback window |

---

*Generated: 2026-08-02 | Runner: vnpt-dev-story-orchestrator | Epic: epic-12 | Story: 12.3*
