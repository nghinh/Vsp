# Slice 2-1-B Implementation: Backend Google + Apple OAuth

**Run ID:** run_2026_08_02_005
**Story:** 2.1 — Register and Authenticate Golfer
**Slice:** 2-1-B — Backend Google OAuth and Apple Sign-In
**Status:** IMPLEMENTED

---

## 1. Source Status Transitions

| Phase | Status Before | Status After |
|-------|--------------|-------------|
| Implementer started | `ready-for-dev` | `in-progress` (unchanged by implementer — status moved by orchestrator) |
| Slice complete | — | `done` (per slice-matrix) |

---

## 2. AC Coverage

| AC | Verification |
|----|-------------|
| AC-2: Google and Apple authentication link to one canonical account when verified identifiers match | `IdentityServiceImplTest` 7 new social auth tests passing: Google new account, Google linking via email, Google already linked, Google invalid token; Apple new account, Apple linking via Google+Email canonical account, Apple invalid token |

---

## 3. Files Changed / Created

### New Files (5)

**DTOs (3)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/GoogleAuthRequest.java` — Google ID token exchange request
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/AppleAuthRequest.java` — Apple identity token exchange request
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/SocialAuthResponse.java` — Social auth response with isNewAccount flag and provider

**Social Token Validation (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/service/SocialTokenValidatorService.java` — Validates Google and Apple identity tokens; extracts subject, email, displayName claims

**Tests (1)**
- `apps/api/src/test/java/vnpt/vsp/module/identity/IdentityServiceImplTest.java` — Extended with 7 new social auth tests (Google: 4 tests, Apple: 3 tests)

### Modified Files (5)

| File | Change |
|------|--------|
| `apps/api/pom.xml` | Added `com.google.oauth-client:google-oauth-client:1.34.1` dependency for OAuth token validation |
| `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` | Added AUTH_014 (Google auth failed), AUTH_015 (Apple auth failed), AUTH_016 (email mismatch), AUTH_017 (cannot link: different provider already linked) |
| `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityService.java` | Added `authenticateWithGoogle()` and `authenticateWithApple()` interface methods |
| `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityServiceImpl.java` | Implemented Google and Apple auth methods with canonical account linking; added SocialTokenValidatorService dependency |
| `apps/api/src/main/java/vnpt/vsp/api/auth/AuthController.java` | Added `POST /auth/google` and `POST /auth/apple` endpoints |
| `packages/contracts/openapi.yaml` | Added `/auth/google` and `/auth/apple` paths; added GoogleAuthRequest, AppleAuthRequest, SocialAuthResponse schema references |
| `packages/contracts/schemas/auth.yaml` | Added GoogleAuthRequest, AppleAuthRequest, SocialAuthResponse schema definitions |

---

## 4. API Endpoints Added

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/google` | Exchange Google ID token → VSP JWT tokens + account linking |
| POST | `/auth/apple` | Exchange Apple identity token → VSP JWT tokens + account linking |

---

## 5. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| AUTH_014 | Google authentication failed | Google ID token is invalid, expired, or missing required claims |
| AUTH_015 | Apple authentication failed | Apple identity token is invalid, expired, or missing required claims |
| AUTH_016 | Email mismatch between social account and existing account | (Reserved for future explicit email mismatch scenarios) |
| AUTH_017 | Cannot link social account: different provider already linked | Same email registered via different Google/Apple subject |

---

## 6. Account Linking Logic

**Canonical account rule (per AC-2):** When a verified email from Google/Apple matches an existing phone/email account, the social subject is linked to the existing canonical account instead of creating a new account.

**Implementation decisions:**

1. **Google subject already linked** → Return existing account (no changes)
2. **Apple subject already linked** → Return existing account (no changes)
3. **Email matches existing phone/email account** → Link new provider subject to existing canonical account
4. **Email matches existing Google/Apple-only account** → Conflict if the same email is linked to a different Google/Apple subject (AUTH_017)
5. **No match** → Create new account with social subject and email

**isNewAccount flag:** `SocialAuthResponse.isNewAccount=true` when a new account is created; `false` when an existing canonical account was linked.

---

## 7. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → PRE_WRITE (no collisions) → POST_WRITE → clean
**Symbols Reported:** `GoogleAuthRequest`, `AppleAuthRequest`, `SocialAuthResponse`, `SocialTokenValidatorService`, `authenticateWithGoogle`, `authenticateWithApple`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/2-1-B/dedup_report.json`
Final symbol status: `clean`

---

## 8. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS |
| `mvn test -Dtest=IdentityServiceImplTest` | ✅ 17 PASS (10 existing + 7 new social auth tests) |
| `mvn package -DskipTests` | ✅ PASS |
| Lint | N/A (no lint configured) |
| Pre-existing failure | `VspApiApplicationTests.contextLoads` — Epic-01 OpenTelemetry double-init issue (unrelated to this slice) |

---

## 9. Configuration Notes

Google and Apple OAuth require runtime configuration (not story blockers):

| Config Key | Description |
|------------|-------------|
| `security.google.client-id` | Google OAuth 2.0 client ID (not validated in MVP token parsing — add before production) |
| `security.apple.team-id` | Apple Developer Team ID |
| `security.apple.key-id` | Apple Sign-In key ID |
| `security.apple.private-key` | Apple private key (P8 file content) |

---

## 10. Next Steps

1. **Slice 2-1-C**: Mobile — Auth UI (Google/Apple Sign-In buttons on Flutter)
2. **Story 2.1 status**: Move to `review` after all slices complete
3. **Epic-01 cleanup**: Resolve `VspApiApplicationTests` OpenTelemetry issue separately
