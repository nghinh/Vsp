# Slice 2-1-A Implementation: Backend Phone/Email + OTP + Password Recovery

**Run ID:** run_2026_08_02_005  
**Story:** 2.1 — Register and Authenticate Golfer  
**Slice:** 2-1-A — Backend Phone/Email Registration, OTP Verification, Password Recovery  
**Status:** IMPLEMENTED

---

## 1. Source Status Transitions

| Phase | Status Before | Status After |
|-------|--------------|-------------|
| Story ready-for-dev | `ready-for-dev` | (not changed by implementer) |
| Implementer started | — | `in-progress` |
| Slice complete | — | `done` (per slice-matrix) |

---

## 2. AC Coverage

| AC | Verification |
|----|-------------|
| AC-1: Phone/email registration supports verification and password recovery | `IdentityServiceImplTest` 10 unit tests passing: phone+email registration, OTP send/verify, password recovery flow, account linking, token validation |
| AC-3: Auth failures expose clear, field-level, non-sensitive feedback | Error codes AUTH_001–AUTH_013 defined in `VspErrorCode`; all auth endpoints return structured `VspApiException` responses |

---

## 3. Files Changed / Created

### New Files (22)

**Database Migrations (3)**
- `apps/api/src/main/resources/db/migration/V2__golfer_accounts.sql`
- `apps/api/src/main/resources/db/migration/V3__otp_codes.sql`
- `apps/api/src/main/resources/db/migration/V4__password_recovery_tokens.sql`

**Entities (3)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/entity/GolferAccount.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/entity/OtpCode.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/entity/PasswordRecoveryToken.java`

**Repositories (3)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/repository/GolferAccountRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/repository/OtpCodeRepository.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/repository/PasswordRecoveryTokenRepository.java`

**DTOs (9)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/PhoneRegisterRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/EmailRegisterRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/OtpSendRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/OtpVerifyRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/PasswordRecoverRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/PasswordResetRequest.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/AuthResponse.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/GolferProfileResponse.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/OtpSendResponse.java`

**Security (3)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/security/JwtService.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/security/PasswordService.java`
- `apps/api/src/main/java/vnpt/vsp/module/identity/security/JwtAuthenticationFilter.java`

**Service (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityServiceImpl.java`

**Controller (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/AuthController.java`

**Config (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/config/SecurityConfig.java`

**Tests (1)**
- `apps/api/src/test/java/vnpt/vsp/module/identity/IdentityServiceImplTest.java`

### Modified Files (6)

| File | Change |
|------|--------|
| `apps/api/pom.xml` | Added spring-boot-starter-security, spring-security-core, jjwt 0.12.5, spring-boot-starter-validation dependencies |
| `apps/api/src/main/java/vnpt/vsp/VspApiApplication.java` | Added `@EntityScan("vnpt.vsp.module.identity.entity")` |
| `apps/api/src/main/java/vnpt/vsp/error/VspErrorCode.java` | Added AUTH_008–AUTH_013 error codes |
| `apps/api/src/main/resources/application.yml` | Added jwt.secret, jwt.access-token-expiration-ms, jwt.refresh-token-expiration-ms |
| `apps/api/src/main/resources/application-test.yml` | Added JPA ddl-auto: create-drop, JWT config |
| `packages/contracts/openapi.yaml` | Added /auth/register/phone, /auth/register/email, /auth/otp/send, /auth/otp/verify, /auth/password/recover, /auth/password/reset, /auth/login, /auth/me endpoints |
| `packages/contracts/schemas/auth.yaml` | Added PhoneRegisterRequest, EmailRegisterRequest, OtpSendRequest, OtpVerifyRequest, PasswordRecoverRequest, PasswordResetRequest, AuthResponse, GolferProfileResponse, OtpSendResponse schemas |

### Pre-existing Files Fixed (4) — Compilation Errors

| File | Issue Fixed |
|------|-------------|
| `apps/api/src/main/java/vnpt/vsp/config/AsyncConfig.java` | Import `DelegatingSecurityContextAsyncTaskExecutor` from `org.springframework.security.task` (not `org.springframework.security.concurrent`); wrapped `ExecutorService` with `TaskExecutorAdapter` |
| `apps/api/src/main/java/vnpt/vsp/api/observability/AlertRules.java` | `AlertThresholds` record requires constructor args; provided default-value factory. `Timer.getSnapshot()` removed in Micrometer 1.12; replaced with `mean()` |
| `apps/api/src/main/java/vnpt/vsp/module/audit/AuditServiceImpl.java` | `SecurityContextHolder` in `org.springframework.security.core.context` (not `org.springframework.security.core`) |
| `apps/api/src/main/java/vnpt/vsp/api/observability/OtelConfig.java` | Pre-existing Epic-01; no changes by this slice (blocked test `VspApiApplicationTests` with OpenTelemetry GlobalOpenTelemetry double-init — Epic-01 issue) |

### Tests Fixed (1)

| File | Issue Fixed |
|------|-------------|
| `IdentityServiceImplTest.java` | `TestJwtService.validateToken()`: fixed base64 URL decoding and JSON sub-extraction; fixed `createToken` to use URL-safe base64; fixed `isAccessToken`/`isRefreshToken` to use URL-safe decoder |
| `IdentityServiceImpl.java` | `getCurrentProfile()`: null-check on `createdAt` before calling `.toString()` |

---

## 4. API Endpoints Implemented

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register/phone` | Register with phone number + password |
| POST | `/auth/register/email` | Register with email + password |
| POST | `/auth/login` | Login with phone/email + password; returns access + refresh JWT |
| POST | `/auth/otp/send` | Send OTP (phone or email); supports REGISTER or PASSWORD_RECOVERY type |
| POST | `/auth/otp/verify` | Verify OTP; marks account verified or returns recovery token |
| POST | `/auth/password/recover` | Initiate password recovery (triggers OTP send) |
| POST | `/auth/password/reset` | Reset password using recovery token from OTP verify |
| GET | `/auth/me` | Return current authenticated golfer profile |

---

## 5. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| AUTH_008 | Phone number already registered | Phone registration with existing phone |
| AUTH_009 | Email already registered | Email registration with existing email |
| AUTH_010 | Account already verified | OTP verify on already-verified account |
| AUTH_011 | Invalid or expired OTP | OTP verify with wrong/expired code |
| AUTH_012 | OTP rate limit exceeded | More than 5 OTPs per phone/email per hour |
| AUTH_013 | Invalid or expired recovery token | Password reset with invalid/expired token |

---

## 6. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → SKIP_SEMANTIC (no collisions)  
**Symbols Reported:** `AuthService`, `GolferAccount`, `AuthController`, `OtpCode`, `PasswordRecoveryToken`  
**All Clean — No Refactors Required**

Dedup report: `docs/vnpt-flow/epic-run-epic-02/2-1-A/dedup_report.json`  
Final symbol status: `clean`

---

## 7. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS |
| `mvn test` | ✅ 21/22 PASS; 1 pre-existing Epic-01 failure (`VspApiApplicationTests.contextLoads` — OpenTelemetry GlobalOpenTelemetry double-init, unrelated to this slice) |
| Unit test count | 10 tests in `IdentityServiceImplTest` |
| Lint | N/A (no lint configured) |
| Typecheck | ✅ Maven compile succeeds |
| Build | ✅ `mvn package` completes |

---

## 8. Remaining Issues

| Issue | Severity | Owner |
|-------|----------|-------|
| `VspApiApplicationTests.contextLoads` fails with OpenTelemetry GlobalOpenTelemetry double-init | Epic-01 pre-existing | Epic-01 owner |
| `OtelConfig.openTelemetry()` calls `GlobalOpenTelemetry.set()` twice (once in OtelConfig, once elsewhere) | Epic-01 pre-existing | Epic-01 owner |

---

## 9. Next Steps

1. **Slice 2-1-B**: Backend — Google OAuth and Apple Sign-In (depends on Slice 2-1-A)
2. **Story 2.1 status**: Move to `review` after all slices complete
3. **Epic-01 cleanup**: Resolve `VspApiApplicationTests` OpenTelemetry issue separately
