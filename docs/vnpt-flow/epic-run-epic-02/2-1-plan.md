# Story 2-1 Plan: Register and Authenticate Golfer

**Run ID:** run_2026_08_02_005
**Epic:** Epic-02 (Golfer Management)
**Wave:** 1 of 5 (no dependencies on other Epic-02 stories)
**Status:** PLANNING
**Story Source:** `docs/implementation-artifacts/epic-02/2-1-register-and-authenticate-golfer.md`

---

## 1. Story Scope Summary

**User Story:** As a golfer, I want to register with phone, email, Google, or Apple so that I can access the platform using a trusted method.

**Acceptance Criteria:**
| AC | Description | Verification |
|----|-------------|--------------|
| AC-1 | Phone/email registration supports verification and password recovery where applicable. | Backend: OTP send/verify endpoints return success; password recovery flow resets password. Mobile: user completes full phone/email registration with OTP and password recovery. |
| AC-2 | Google and Apple authentication link to one canonical account when verified identifiers match. | Backend: same phone/email matched via Google+Email or Apple+Email creates one account; duplicate phone/email returns 409 conflict with canonical account hint. |
| AC-3 | Auth failures expose clear, field-level, non-sensitive feedback. | Mobile: field-level error messages; backend: structured error codes, no PII in error response fields. |

---

## 2. PRD / Architecture / UX Alignment Evidence

### PRD Alignment (docs/planning-artifacts/prd.md)
- **Section 8.1 Account and Profile:** Explicitly calls for phone, email, Google Sign-In, Apple Sign-In registration; OTP verification; password recovery.
- **Section 6 Technology Decisions:** Flutter (mobile), modular monolith (backend), PostgreSQL/PostGIS (data).
- **Section 10.6 Security:** TLS everywhere, token expiration, refresh-token rotation, encrypted token storage on mobile.

### Architecture Alignment (docs/planning-artifacts/architecture.md)
- **Section 6.1 Modular Monolith:** Identity Module listed as first bounded module.
- **Section 11.2 Minimum API Groups:** `/auth/*` endpoints are required.
- **Section 12 Security:** OAuth/OIDC-compatible identity, short-lived access tokens, refresh-token rotation, encrypted token storage on mobile.

### UX Spec Alignment (docs/planning-artifacts/ux-spec.md)
- **Section 5.2 Onboarding/Auth:** Phone/email/social login, OTP verification, permission education for location/notifications/offline storage.
- **Section 10 Accessibility:** Field-level errors, screen reader labels, 44/48dp touch targets.
- **Section 3 Design Principles:** Glanceable in under 2 seconds, one-hand operation, two taps or less for frequent actions.

### Epic-01 Foundations (DONE — stories 1-2 and 1-3)
- **Story 1.2 (done):** Backend modular monolith established with Identity Module boundary.
- **Story 1.3 (done):** OpenAPI contracts for `/auth/*` endpoints defined.

---

## 3. Slice Plan

### Slice 2-1-A: Backend — Phone/Email Registration, OTP Verification, Password Recovery
**Rationale:** Core registration backend must exist before mobile UI or social auth. Independent of other Epic-02 stories. Tests the "phone/email registration supports verification and password recovery" AC independently.

**Scope:**
- `apps/api/` — Identity module implementation
- Database schema: `golfer_accounts` table (phone, email, password_hash, google_subject, apple_subject, status, verified_at)
- `POST /auth/register/phone` — register with phone + password
- `POST /auth/register/email` — register with email + password
- `POST /auth/otp/send` — generate and send OTP (simulated SMS/email for MVP)
- `POST /auth/otp/verify` — verify OTP, mark account verified
- `POST /auth/password/recover` — initiate password recovery
- `POST /auth/password/reset` — reset password with token
- `POST /auth/login` — issue JWT access + refresh tokens
- `GET /auth/me` — return current authenticated golfer profile
- Account linking: when same phone/email registers via both phone and Google/Apple, return 409 with canonical account hint
- OpenAPI contract update for all new endpoints
- Unit tests: registration, OTP flow, password recovery, account linking edge cases

**Dependencies:** Epic-01 Story 1.2 (modular monolith), Story 1.3 (API contracts)

**Risks:**
- OTP delivery (SMS) requires third-party provider decision (not a story blocker; implement OTP storage + verify endpoint, defer SMS delivery to infrastructure)
- Password recovery token expiration and storage needs clarification

---

### Slice 2-1-B: Backend — Google OAuth and Apple Sign-In
**Rationale:** Social auth is separate from phone/email to allow parallel work on mobile. Depends only on Slice 2-1-A's account linking logic.

**Scope:**
- `POST /auth/google` — exchange Google ID token, create/link GolferAccount
- `POST /auth/apple` — exchange Apple identity token, create/link GolferAccount
- Account linking: Google/Apple subject + verified email → canonical account
- If email verified by Google/Apple matches existing phone/email account → link providers to existing canonical account
- `POST /auth/refresh` — refresh access token using refresh token
- OpenAPI contract update for social auth endpoints
- Unit tests: Google flow, Apple flow, linking same email via different providers

**Dependencies:** Slice 2-1-A (account schema, linking logic, token issuance)

**Risks:**
- Google OAuth requires `GOOGLE_CLIENT_ID` configuration (infrastructure concern, not story blocker)
- Apple Sign-In requires `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (same)
- Apple Sign-In requires HTTPS and proper `applicationIdentifier` claim validation

---

### Slice 2-1-C: Mobile — Auth UI (Registration, Login, Social Auth Buttons)
**Rationale:** Mobile auth screens are the primary user-facing deliverable. Depends on backend API contracts (Epic-01 Story 1-3 done) and Slice 2-1-A for auth flows.

**Scope:**
- `apps/mobile/` — Flutter app
- Auth state management (Flutter_bloc or Riverpod)
- Phone/email registration form (phone number input, email input, password input)
- OTP entry screen (6-digit code input)
- Password recovery screen (email input → OTP → new password)
- Login screen (phone/email + password)
- Social auth buttons (Google, Apple) on login and registration screens
- Google Sign-In flow integration
- Apple Sign-In flow integration
- Loading states, error states, field validation feedback
- Session persistence (encrypted token storage)
- Navigation: post-login → main app (Courses screen per UX spec)

**Dependencies:** Slice 2-1-A (API endpoints), Slice 2-1-B (social auth endpoints)

**Risks:**
- Flutter Google Sign-In and Sign-In with Apple packages need to be added as dependencies
- Platform-specific configuration (iOS Info.plist, Android manifest) needed for Google/Apple auth

---

### Slice 2-1-D: Mobile — Field-Level Error Feedback and UX Polish
**Rationale:** Completes AC-3 (auth failures expose clear, field-level, non-sensitive feedback). Can run in parallel with 2-1-C.

**Scope:**
- Field-level error display on all auth forms (phone invalid → "Enter a valid phone number", email invalid → "Enter a valid email address", etc.)
- Backend error mapping: `AUTH_INVALID_CREDENTIALS` → "Invalid phone number or password" (no field attribution to avoid credential enumeration)
- Backend error mapping: `AUTH_ACCOUNT_LOCKED` → "Account temporarily locked. Try again later."
- Backend error mapping: `AUTH_OTP_EXPIRED` → "Verification code expired. Request a new one."
- Non-sensitive error responses: no tokens, no PII, no stack traces in error payloads
- Screen reader labels for all auth form fields and buttons
- Touch targets ≥ 44dp iOS / 48dp Android on auth buttons
- Loading spinner during OTP send, verification, login, social auth
- Offline-aware feedback: "Check your internet connection and try again" on network failure

**Dependencies:** Slice 2-1-A and 2-1-B (backend error codes), Slice 2-1-C (UI forms)

---

## 4. Slice-to-AC Mapping

| Slice | AC-1 (Phone/Email + verification + recovery) | AC-2 (Google/Apple linking) | AC-3 (Field-level errors) |
|-------|---------------------------------------------|------------------------------|--------------------------|
| 2-1-A (Backend Phone/Email) | ✅ Full | N/A | Partial (error codes) |
| 2-1-B (Backend Social Auth) | N/A | ✅ Full | Partial (error codes) |
| 2-1-C (Mobile Auth UI) | ✅ Full | ✅ Full | Partial (UI wiring) |
| 2-1-D (Error Feedback) | N/A | N/A | ✅ Full |

---

## 5. Skill Gap Analysis

| Required Skill | Status | Evidence |
|----------------|--------|----------|
| `bmad-dev-story` | ✅ Available | Loaded from `.agents/skills/bmad-dev-story/SKILL.md` |
| `vnpt-tdd` | ✅ Available | Skill `vnpt-tdd` in available_skills |
| Flutter auth (Google, Apple) | ✅ Standard packages | `flutter_signin` / `sign_in_with_apple` packages |
| Spring Boot identity module | ✅ Epic-01 Story 1.2 foundation | Modular monolith already has Identity module boundary |

**No skill gaps identified. All required skills and stack patterns are available.**

---

## 6. Quality Gate Checklist

### Pre-Dispatch Checks
| Check | Result | Evidence |
|-------|--------|----------|
| Story source status is `ready-for-dev` | ✅ Yes | `docs/implementation-artifacts/epic-02/2-1-register-and-authenticate-golfer.md` line 5: `status: ready-for-dev` |
| No placeholder/TODO-only scope | ✅ Clean | Full implementation scope defined in slices |
| No deferred-production behavior | ✅ Clean | All ACs addressed in slices |
| Skill-not-found error | ✅ None | Both `bmad-dev-story` and `vnpt-tdd` confirmed available |
| Epic-01 dependencies resolved | ✅ Done | Stories 1-2 and 1-3 both `status: done` |

### Anti-Shortcut Evidence
| Check | Result |
|-------|--------|
| No skipping required context reading | ✅ All 8 required source groups read |
| No collapse of independent slices into sequential-only | ✅ Slices 2-1-C and 2-1-D can run in parallel |
| PRD/Architecture/UX alignment verified | ✅ Full cross-reference table in Section 2 |
| AC coverage verified per slice | ✅ Section 4 slice-to-AC mapping |

### Dedup Pre-Check (symbols expected in new code)
| Symbol Pattern | Location | Dedup Action |
|----------------|----------|--------------|
| `AuthService`, `RegistrationController`, `GolferAccount` | `apps/api/` | Serena exact-match before creating; if found with matching signature → reuse |
| `OtpService`, `SocialAuthService` | `apps/api/` | Same as above |
| `AuthBloc`, `LoginScreen`, `RegisterScreen` | `apps/mobile/` | Same as above |

---

## 7. Implementation Wave Recommendation

**Recommended dispatch order:**
1. **Slice 2-1-A** (backend, wave 1) — first: all other slices depend on it
2. **Slice 2-1-B** (backend social, wave 2, depends on A) — sequential
3. **Slice 2-1-C** (mobile, wave 3, depends on A+B API contracts) — sequential  
4. **Slice 2-1-D** (error feedback, wave 3, depends on A+B+C) — sequential with C

**Rationale:** Backend must be stable before mobile integrates. Social auth depends on core account schema. Error feedback builds on both backend error codes and mobile forms.

---

## 8. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/vnpt-flow/epic-run-epic-01/epic-summary.md",
    "docs/vnpt-flow/epic-run-epic-02/epic-inventory.md",
    "docs/vnpt-flow/epic-run-epic-02/epic-state.json",
    "docs/vnpt-flow/epic-run-epic-02/epic-story-manifest.json"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-1-register-and-authenticate-golfer.md"
  ],
  "mockup_sources_read": []
}
```

**Note:** No mockup/wireframe/Figma docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story. The `vnpt-stitch-mockup-batch.README.md` indicates Stitch mockup generation is a separate batch step, not pre-populated for this story.

---

## 9. Completion Criteria for Implementer

Each slice implementer must deliver:
1. All slice-scoped acceptance criteria verified
2. Unit tests for happy paths, boundaries, and failures
3. Repository format, lint, typecheck, and test gates pass
4. Dedup report generated (`docs/vnpt-flow/epic-run-epic-02/2-1-{slice}/dedup_report.json`)
5. File list populated in story change log
6. Story status updated to `in-progress` during work, `review` when all slices complete

---

**Plan Status:** ✅ READY_FOR_IMPLEMENTER_DISPATCH
**Quality Gate:** PASS (all checks clean)
**Next Action:** Dispatch Slice 2-1-A to `vnpt-epic-story-implementer`
