# Slice Plan — Story 12.2: Add Booking, Membership, and Loyalty Boundaries

## Story Reference
- **Story:** 12.2
- **Epic:** 12 — Tournament and Smart Golf Ecosystem (MVP 4)
- **Phase:** MVP 4 (explicitly deferred from MVP 1)
- **Status:** `ready-for-dev` → `in-progress`

---

## Scope Determination

### What THIS Story IS
- Define domain module boundaries for Booking, Membership, Loyalty, Sponsorship
- Create OpenAPI contract schemas ( stubs — no implementation)
- Add white-label configuration schema that preserves core GPS behavior
- Document consent boundaries between customer operations and core platform
- Add minimal module stub infrastructure (empty controller + service interface)

### What THIS Story is NOT
- Full booking implementation (tee time slots, reservations, calendar)
- Full membership implementation (plans, tiers, entitlements)
- Full loyalty implementation (points, rewards, promotions)
- Full payment processing
- Full white-label app customization
- Implementation of 12.1 (Tournament and Live Leaderboard) — separate story

### Critical Constraint
This is a **boundaries-only** story. All new modules are stubs with contracts. The goal is extension points that prevent future implementation from coupling to the core GPS Round Module.

---

## Slice Architecture

### Existing Modules (Architecture §6.1)
```
Identity | UserProfile | CourseCatalog | Geospatial | Package | Round | Score | Weather | Correction | Operations | Audit | Notification
```

### New Module Stubs (this slice)
```
Booking   — booking.* contract only, no DB, no provider integration
Membership — membership.* contract only, no DB, no plan logic
Loyalty   — loyalty.* contract only, no points engine
Sponsorship — sponsorship.* contract only, no ad serving
WhiteLabel — white_label.* config schema only
```

### Boundary Rules
1. **No direct Round Module imports** from new stubs
2. **No direct Score Module imports** from new stubs
3. **Cross-module calls** go through explicit service interfaces only
4. **White-label config** is read-only at round-time; never mutates round state

---

## Slice 1: Module Stub Infrastructure

### 1.1 Booking Module Stub
**File:** `apps/api/src/main/java/vnpt/vsp/module/booking/BookingModule.java`
- Empty Spring `@Module` class
- Exposes `BookingService` interface (no-op implementation)
- Exposes `BookingController` with 405 (Not Yet Implemented) for all endpoints
- Maps to OpenAPI schema `schemas/booking.yaml`

### 1.2 Membership Module Stub
**File:** `apps/api/src/main/java/vnpt/vsp/module/membership/MembershipModule.java`
- Empty Spring `@Module` class
- Exposes `MembershipService` interface (no-op)
- Exposes `MembershipController` with 405
- Maps to OpenAPI schema `schemas/membership.yaml`

### 1.3 Loyalty Module Stub
**File:** `apps/api/src/main/java/vnpt/vsp/module/loyalty/LoyaltyModule.java`
- Empty Spring `@Module` class
- Exposes `LoyaltyService` interface (no-op)
- Exposes `LoyaltyController` with 405
- Maps to OpenAPI schema `schemas/loyalty.yaml`

### 1.4 Sponsorship Module Stub
**File:** `apps/api/src/main/java/vnpt/vsp/module/sponsorship/SponsorshipModule.java`
- Exposes `SponsorshipService` interface
- Exposes `SponsorshipController` with 405

---

## Slice 2: OpenAPI Contract Schemas

### 2.1 Booking Contract
**File:** `packages/contracts/schemas/booking.yaml`
```yaml
Booking:
  type: object
  properties:
    bookingId: { type: string, format: uuid }
    userId: { type: string, format: uuid }
    courseId: { type: string, format: uuid }
    teeTime: { type: string, format: date-time }
    players: { type: array, items: { $ref: '#/BookingPlayer' } }
    status: { type: string, enum: [pending, confirmed, cancelled, completed] }
    consentGiven: { type: boolean }
    consentTimestamp: { type: string, format: date-time }
BookingSlot:
  type: object
  properties:
    slotId: { type: string }
    courseId: { type: string }
    startTime: { type: string }
    endTime: { type: string }
    available: { type: boolean }
```

### 2.2 Membership Contract
**File:** `packages/contracts/schemas/membership.yaml`
```yaml
Membership:
  type: object
  properties:
    membershipId: { type: string }
    userId: { type: string }
    planId: { type: string }
    courseId: { type: string }
    status: { type: string, enum: [active, suspended, cancelled, expired] }
    effectiveDate: { type: string }
    expiryDate: { type: string }
    entitlements: { type: array, items: { type: string } }
MembershipPlan:
  type: object
  properties:
    planId: { type: string }
    name: { type: string }
    tier: { type: string }
    entitlements: { type: array, items: { type: string } }
    bookingDiscountPercent: { type: number }
```

### 2.3 Loyalty Contract
**File:** `packages/contracts/schemas/loyalty.yaml`
```yaml
LoyaltyAccount:
  type: object
  properties:
    accountId: { type: string }
    userId: { type: string }
    pointsBalance: { type: integer }
    lifetimePoints: { type: integer }
    tier: { type: string }
LoyaltyTransaction:
  type: object
  properties:
    transactionId: { type: string }
    accountId: { type: string }
    points: { type: integer }
    type: { type: string, enum: [earn, redeem, expire, adjust] }
    source: { type: string }
    timestamp: { type: string }
```

### 2.4 Sponsorship Contract
**File:** `packages/contracts/schemas/sponsorship.yaml`
```yaml
Sponsorship:
  type: object
  properties:
    sponsorshipId: { type: string }
    courseId: { type: string }
    sponsorName: { type: string }
    logoUrl: { type: string }
    targetSlots: { type: array, items: { type: string } }
    consentGiven: { type: boolean }
```

### 2.5 WhiteLabel Config Schema
**File:** `packages/contracts/schemas/whitelabel.yaml`
```yaml
WhiteLabelConfig:
  type: object
  properties:
    brandId: { type: string }
    brandName: { type: string }
    primaryColor: { type: string }
    logoUrl: { type: string }
    enabledModules:
      type: array
      items: { type: string, enum: [booking, membership, loyalty, sponsorship] }
    roundBehavior:
      type: object
      properties:
        allowCustomBranding: { type: boolean }
        forkGpsBehavior: { type: boolean }  # MUST be false
        forkScoreBehavior: { type: boolean }  # MUST be false
```

**Boundary Invariant:** `forkGpsBehavior` and `forkScoreBehavior` MUST always be `false`. This is enforced by schema `readOnly: true` and validated at config load time.

---

## Slice 3: Consent Boundary Documentation

### 3.1 Consent Policy Document
**File:** `docs/domain/consent-boundaries.md`
- Documents what customer data can be shared with booking/membership/loyalty modules
- GDPR/data residency boundaries
- Explicit opt-in requirements per AC1
- Audit trail requirements for consent events

---

## Slice 4: Boundary Enforcement Tests

### 4.1 No-Coupling Tests
**File:** `apps/api/src/test/java/vnpt/vsp/module/booking/BookingBoundaryTest.java`
- Verifies `BookingModule` has zero imports from `RoundModule`, `ScoreModule`
- Verifies `BookingService` interface does not accept round/score types

**File:** `apps/api/src/test/java/vnpt/vsp/module/membership/MembershipBoundaryTest.java`
- Verifies same boundary rule

**File:** `apps/api/src/test/java/vnpt/vsp/module/loyalty/LoyaltyBoundaryTest.java`
- Verifies same boundary rule

### 4.2 WhiteLabel Invariant Test
**File:** `apps/api/src/test/java/vnpt/vsp/whitelabel/WhiteLabelInvariantTest.java`
- Loads any `WhiteLabelConfig`
- Asserts `forkGpsBehavior == false`
- Asserts `forkScoreBehavior == false`

---

## Slice 5: Integration with OpenAPI Spec

### 5.1 Update Main OpenAPI
**File:** `packages/contracts/openapi.yaml`
- Add `schemas/booking.yaml`, `schemas/membership.yaml`, `schemas/loyalty.yaml`, `schemas/sponsorship.yaml`, `schemas/whitelabel.yaml` to `components/schemas`
- Add path groups for `/booking`, `/membership`, `/loyalty`, `/sponsorship`

---

## Acceptance Criteria Mapping

| AC | Implementation | Test |
|----|---------------|------|
| AC1: Booking, membership, loyalty, sponsorship use documented contracts and consent boundaries | OpenAPI schemas in `packages/contracts/schemas/` + `consent-boundaries.md` | Schema validation in OpenAPI build + consent invariant test |
| AC2: Domain boundaries prevent payment/customer operations from coupling to core GPS rounds | Boundary tests verifying zero RoundModule imports + service interface segregation | `BookingBoundaryTest`, `MembershipBoundaryTest`, `LoyaltyBoundaryTest` |
| AC3: White-label configuration does not fork core product behavior | `WhiteLabelConfig` schema with `forkGpsBehavior: false`, `forkScoreBehavior: false` invariants | `WhiteLabelInvariantTest` |

---

## Dependency Note

**Story 12.1** (`12-1-operate-tournament-and-live-leaderboard`) is listed as a dependency. However, 12.1 is currently `backlog` status. This slice has **no code dependency on 12.1** — it creates entirely new modules with no tournament coupling. The dependency is informational (future integration point) rather than a build-time constraint.

If 12.1 implements tournament policy propagation, the Tournament Module will consume Round Module data through explicit interfaces — the same boundary pattern used here.

---

## File List (Relative to Repo Root)

**New Files:**
- `apps/api/src/main/java/vnpt/vsp/module/booking/BookingModule.java`
- `apps/api/src/main/java/vnpt/vsp/module/booking/BookingService.java`
- `apps/api/src/main/java/vnpt/vsp/module/booking/BookingController.java`
- `apps/api/src/main/java/vnpt/vsp/module/membership/MembershipModule.java`
- `apps/api/src/main/java/vnpt/vsp/module/membership/MembershipService.java`
- `apps/api/src/main/java/vnpt/vsp/module/membership/MembershipController.java`
- `apps/api/src/main/java/vnpt/vsp/module/loyalty/LoyaltyModule.java`
- `apps/api/src/main/java/vnpt/vsp/module/loyalty/LoyaltyService.java`
- `apps/api/src/main/java/vnpt/vsp/module/loyalty/LoyaltyController.java`
- `apps/api/src/main/java/vnpt/vsp/module/sponsorship/SponsorshipModule.java`
- `apps/api/src/main/java/vnpt/vsp/module/sponsorship/SponsorshipService.java`
- `apps/api/src/main/java/vnpt/vsp/module/sponsorship/SponsorshipController.java`
- `packages/contracts/schemas/booking.yaml`
- `packages/contracts/schemas/membership.yaml`
- `packages/contracts/schemas/loyalty.yaml`
- `packages/contracts/schemas/sponsorship.yaml`
- `packages/contracts/schemas/whitelabel.yaml`
- `apps/api/src/test/java/vnpt/vsp/module/booking/BookingBoundaryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/membership/MembershipBoundaryTest.java`
- `apps/api/src/test/java/vnpt/vsp/module/loyalty/LoyaltyBoundaryTest.java`
- `apps/api/src/test/java/vnpt/vsp/whitelabel/WhiteLabelInvariantTest.java`
- `docs/domain/consent-boundaries.md`

**Modified Files:**
- `packages/contracts/openapi.yaml` (add new schema references)
- `apps/api/src/main/resources/application.yml` (register new module configs)

---

## Verification Gates

1. **Format:** `./mvnw spotless:apply` — Java formatting
2. **Lint:** `./mvnw checkstyle:check` — if configured
3. **Test:** `./mvnw test -Dtest="*BoundaryTest,*WhiteLabelInvariantTest"` — boundary tests pass
4. **OpenAPI:** `openapi-generator-cli validate -i packages/contracts/openapi.yaml` — schema valid
5. **Build:** `./mvnw compile` — all modules compile including new stubs
