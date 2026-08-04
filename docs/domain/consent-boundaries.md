# Consent Boundaries — Booking, Membership, Loyalty, and Sponsorship

## Overview

This document defines the consent boundaries between customer operations modules (Booking, Membership, Loyalty, Sponsorship) and the core platform. It ensures GDPR/data residency compliance, explicit opt-in requirements, and audit trail integrity.

---

## Module Boundary Summary

| Module | Customer Data | Consent Required | Audit Trail |
|--------|--------------|------------------|-------------|
| Booking | userId, tee time, player list | Yes (per-booking) | Yes |
| Membership | userId, plan, entitlements | Yes (per-plan) | Yes |
| Loyalty | userId, points, transactions | Yes (per-account) | Yes |
| Sponsorship | userId, sponsorship preferences | Yes (per-sponsorship) | Yes |

---

## Data Sharing Rules

### What CAN Be Shared With Customer Operation Modules

1. **User identity** (userId, email) — for booking confirmation, loyalty account linking
2. **Course information** (courseId, facilityId) — for local pricing, availability
3. **Timestamps** — for scheduling, expiration tracking
4. **Aggregate statistics** — course popularity, booking patterns (no individual round data)

### What MUST NOT Be Shared

1. **RoundModule data** — GPS coordinates, shot locations, hole-by-hole scores
2. **ScoreModule data** — individual scores, handicaps, leaderboard positions
3. **Raw location trails** — player movements during rounds
4. **Device identifiers** — hardware IDs collected during round play

### Rationale

The core GPS and scoring platform is a separate product concern. Customer operations (bookings, loyalty programs) must not create data dependencies on round internals. This prevents:
- Circular coupling between booking and scoring systems
- GDPR exposure of precise location data to third-party booking partners
- Data residency violations when booking servers are in different jurisdictions

---

## Consent Requirements (Per AC1)

### Booking Consent
- **When**: Before confirming a tee time reservation
- **What**: User agrees to share name, email, handicap (optional) with the course
- **Scope**: Single booking session only
- **Retention**: 30 days after booking completion or cancellation
- **Withdrawal**: User can cancel booking to withdraw consent

### Membership Consent
- **When**: Before purchasing or activating a membership plan
- **What**: User agrees to share membership status with partner courses
- **Scope**: Duration of membership + 30 days
- **Retention**: Duration of membership + 1 year for billing records
- **Withdrawal**: User must cancel membership (with applicable notice period)

### Loyalty Consent
- **When**: Before creating a loyalty account or earning first points
- **What**: User agrees to track points activity for rewards program
- **Scope**: Until account closure
- **Retention**: Account lifetime + 5 years for tax/compliance
- **Withdrawal**: Account closure (points forfeited per program rules)

### Sponsorship Consent
- **When**: Before receiving sponsor-targeted promotions
- **What**: User agrees to receive communications from sponsors
- **Scope**: Until consent withdrawn
- **Retention**: Until withdrawal + 30 days
- **Withdrawal**: One-click unsubscribe in any sponsor communication

---

## Data Residency Requirements

Customer operations modules may process data in different regions than the core GPS platform.

### Requirements
1. **User consent records** must be stored in the same region as the user
2. **Booking data** must not leave the booking system's certified region without explicit consent
3. **Points/loyalty data** with financial implications must comply with local financial regulations
4. **Cross-border transfer** of user identity data requires explicit opt-in

### Implementation
- BookingService and MembershipService must accept a region parameter
- LoyaltyService must validate residency before processing financial points
- SponsorshipService must not store user GPS coordinates

---

## Audit Trail Requirements

All consent events must be logged with:

| Field | Description |
|-------|-------------|
| eventId | Unique identifier (UUID) |
| userId | User identifier |
| module | booking / membership / loyalty / sponsorship |
| action | consent_given / consent_withdrawn |
| timestamp | ISO-8601 instant |
| ipAddress | Hash of IP address (for fraud detection) |
| userAgent | Browser/app user agent |
| consentScope | What data is covered |
| consentVersion | Version of consent text shown |

Audit logs are:
- Immutable (append-only)
- Encrypted at rest
- Retained for 7 years (regulatory requirement)
- Accessible only to compliance officers

---

## Enforcement

### Technical Enforcement
1. **BookingService.recordConsent()** — stores consent with audit trail
2. **MembershipService** — checks consent before processing plan changes
3. **LoyaltyService** — validates consent on every points operation
4. **SponsorshipService** — returns 403 if consent not given

### Schema Enforcement
- `consentGiven: boolean` — required on all booking/sponsorship requests
- `consentTimestamp: date-time` — recorded automatically
- White-label config enforces `forkGpsBehavior: false` and `forkScoreBehavior: false`

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-08-01 | Initial consent boundary document |
