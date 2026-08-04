# Slice 2-2-A Implementation: Backend Session Management

**Run ID:** run_2026_08_02_005
**Story:** 2.2 — Manage Sessions Securely
**Slice:** 2-2-A — Backend Session Management (Refresh Token Rotation + Revocation)
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
| AC-1: Access tokens short-lived and refresh tokens rotate | `IdentityServiceImplTest` 3 rotation tests passing: happy-path rotation, token-not-found rejection, non-refresh-token rejection |
| AC-3: User can list and revoke sessions; revoked sessions cannot refresh | `IdentityServiceImplTest` 6 session tests passing: list (active sessions, empty, current marking), revoke (happy path, not-found, already-revoked), revoke-all |

---

## 3. Files Changed / Created

### New Files (5)

**Migration (1)**
- `apps/api/src/main/resources/db/migration/V5__refresh_tokens.sql`

**Entity (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/entity/RefreshToken.java`

**Repository (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/repository/RefreshTokenRepository.java`

**DTO (1)**
- `apps/api/src/main/java/vnpt/vsp/module/identity/dto/SessionResponse.java`

**Tests (1)**
- Extended `apps/api/src/test/java/vnpt/vsp/module/identity/IdentityServiceImplTest.java` with 9 new session management tests

### Modified Files (7)

| File | Change |
|------|--------|
| `apps/api/src/main/java/vnpt/vsp/module/identity/security/JwtService.java` | Added `hashToken(SHA-256)`, `getRefreshTokenExpirationMs()` methods |
| `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityService.java` | Added `rotateRefreshToken()`, `listSessions()`, `revokeSession()`, `revokeAllSessions()` interface methods |
| `apps/api/src/main/java/vnpt/vsp/module/identity/IdentityServiceImpl.java` | Implemented rotation, list, revoke, revoke-all; updated `refreshToken()` to delegate to rotation; added `RefreshTokenRepository` dependency |
| `apps/api/src/main/java/vnpt/vsp/api/auth/AuthController.java` | Added `GET /auth/sessions`, `DELETE /auth/sessions/{sessionId}` endpoints; updated `POST /auth/refresh` to pass device-info/user-agent/IP; added `extractDeviceInfo()` and `extractClientIp()` helpers |
| `apps/api/src/main/java/vnpt/vsp/api/error/VspErrorCode.java` | Added `AUTH_018` (Session not found), `AUTH_019` (Session already revoked) |
| `packages/contracts/openapi.yaml` | Added `GET /auth/sessions`, `DELETE /auth/sessions/{sessionId}` endpoints; updated `POST /auth/refresh` response to `AuthResponse` (rotation returns full token pair) |
| `packages/contracts/schemas/auth.yaml` | Added `SessionResponse`, `SessionListResponse` schemas |

---

## 4. API Endpoints Implemented / Updated

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/refresh` | Refresh + **rotate** refresh token (returns full `AuthResponse` with both access + new refresh token) |
| GET | `/auth/sessions` | List all active (non-revoked, non-expired) sessions for the authenticated golfer |
| DELETE | `/auth/sessions/{sessionId}` | Revoke a specific session; revoked sessions cannot refresh |

---

## 5. Rotation Design

**Token never stored raw.** Only the SHA-256 hash of the refresh token is stored in `refresh_tokens.token_hash`. The raw JWT refresh token is returned to the client and never persisted server-side.

**Rotation flow:**
1. Client sends refresh token to `POST /auth/refresh`
2. Server validates JWT signature and expiry
3. Server looks up `token_hash = SHA-256(raw_token)` in `refresh_tokens` WHERE `revoked_at IS NULL`
4. Old token marked `revoked_at = NOW()`, `replaced_by_token_id = new_token.id`
5. New refresh token generated and stored with hash
6. New access + refresh tokens returned to client

**Revocation:** Any attempt to use a revoked refresh token fails at step 3 (token not found in active DB lookup), satisfying AC-3 "revoked sessions cannot refresh".

---

## 6. Error Codes Added

| Code | Message | Used When |
|------|---------|-----------|
| AUTH_018 | Session not found | `revokeSession` called with non-existent or other-account session ID |
| AUTH_019 | Session already revoked | `revokeSession` called on an already-revoked session |

---

## 7. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → `clean` → POST_WRITE → `clean` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/2-2-A/dedup_report.json`
Final symbol status: `clean`

---

## 8. Quality Gate Results

| Gate | Result |
|------|--------|
| `mvn compile` | ✅ PASS |
| `mvn test -Dtest=IdentityServiceImplTest` | ✅ 30 PASS (17 existing + 9 new session tests + 4 others) |
| `mvn package -DskipTests` | ✅ PASS |
| Pre-existing failure | `VspApiApplicationTests.contextLoads` — Epic-01 OpenTelemetry GlobalOpenTelemetry double-init (unrelated to this slice, documented in 2-1-A) |

---

## 9. Session List Response Schema

```json
GET /auth/sessions
{
  "sessions": [
    {
      "sessionId": 42,
      "deviceInfo": "iPhone 15 Pro",
      "userAgent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)...",
      "ipAddress": "203.0.113.42",
      "createdAt": "2026-08-01T10:00:00Z",
      "expiresAt": "2026-08-08T10:00:00Z",
      "currentSession": true
    }
  ]
}
```

---

## 10. Rotation Response Schema

```
POST /auth/refresh → 200 OK
{
  "accessToken": "eyJhbGci...",
  "refreshToken": "eyJhbGci...",   // NEW rotated refresh token
  "expiresIn": 3600,
  "tokenType": "Bearer",
  "userId": 1,
  "displayName": "John Doe",
  "status": "ACTIVE"
}
```

---

## 11. Session Revocation Response

```
DELETE /auth/sessions/42 → 204 No Content
```

---

## 12. Remaining Issues

| Issue | Severity | Owner |
|-------|----------|-------|
| `VspApiApplicationTests.contextLoads` fails with OpenTelemetry GlobalOpenTelemetry double-init | Epic-01 pre-existing | Epic-01 owner |

---

## 13. Next Steps

1. **Slice 2-2-B**: Mobile — Encrypted Token Storage + Session Management UI (depends on Slice 2-2-A API contracts)
2. **Story 2.2 status**: Move to `review` after all slices complete
