# Encryption Policy

## Overview

This document defines the Vietnam Smart Golf Platform (VSP) encryption standards for data in transit (TLS) and data at rest (database storage, backups). These controls support NFR9 (TLS, RBAC, MFA, rate limiting), NFR10 (deletion/export/consent/retention), and architecture §12 security requirements.

---

## Data in Transit — TLS

### Requirements

- **TLS 1.3 only** — TLS 1.2 and below are explicitly disabled.
- **TLS 1.3 cipher suites** (in priority order):
  ```
  TLS_AES_256_GCM_SHA384
  TLS_AES_128_GCM_SHA256
  TLS_CHACHA20_POLY1305_SHA256
  ```
- RC4, DES, 3DES, MD5, and SHA-1 hash algorithms are **prohibited** for any cryptographic use.
- Forward secrecy (ECDHE) is **required** — static RSA key exchange is not permitted.
- Client certificate authentication (mutual TLS) is **required** for all production API endpoints.
- Session resumption with a session ticket is limited to 24-hour maximum session lifetime.

### Configuration

TLS is configured in `apps/api/src/main/resources/application-prod.yml`:

```yaml
server:
  ssl:
    enabled: true
    protocol: TLSv1.3
    enabled-protocols: TLSv1.3
    cipher-suite: TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256
    client-auth: need
    key-store: ${VSP_SSL_KEYSTORE_PATH}
    key-store-password: ${VSP_SSL_KEYSTORE_PASSWORD}
    key-store-type: PKCS12
    trust-store: ${VSP_SSL_TRUSTSTORE_PATH}
    trust-store-password: ${VSP_SSL_TRUSTSTORE_PASSWORD}
    trust-store-type: PKCS12
    session-cache-size: 8192
    session-timeout: 86400
```

All keystore passwords are loaded from environment variables — **never hardcoded**.

### Certificate Management

- **Keystore format**: PKCS#12 (`.p12`)
- **Certificate type**: X.509 with SAN covering all API hostnames
- **Key size**: Minimum 2048-bit RSA or 256-bit ECDSA
- **Rotation**: Keystore passwords and certificates rotate annually; process automated via cert-manager in Kubernetes or AWS ACM for load balancers
- **CSR and private key generation** must happen on a trusted bastion host; private key must never be committed to the repository

### External Load Balancer Variant

In production deployments where the API sits behind an AWS ALB/NLB:
- TLS termination happens at the load balancer (ALB uses AWS ACM managed certificates).
- ALB → API communication uses mTLS with a second certificate on the API server.
- All `server.ssl.*` configuration applies to the internal mTLS channel.

---

## Data at Rest — Database

### PostgreSQL Encryption

- **AWS RDS / Cloud SQL**: Encryption at rest is enabled by default using AWS KMS CMKs (AES-256). The KMS key ARN is referenced by `VSP_SECRETS_MANAGER_KMS_KEY_ID`.
- **Self-managed PostgreSQL**: `pgcrypto` module enabled for column-level encryption of sensitive fields (PII, auth tokens). Tablespaces encrypted using Linux dm-crypt.
- **Disk encryption**: All VM/data volumes use AES-256 encryption at the hypervisor/storage layer (AWS EBS encryption, GCP persistent disk encryption).

### Column-Level Encryption

Sensitive columns (e.g., `refresh_token`, `encrypted_payload`) use `pgcrypto` symmetric encryption:

```sql
-- Example: insert with column-level encryption
INSERT INTO auth_tokens (user_id, encrypted_payload)
VALUES (
  :user_id,
  pgp_sym_encrypt(:payload, current_setting('app.encryption_key'))
);
```

The `app.encryption_key` session variable is set from `VSP_DB_ENCRYPTION_KEY_REF` at connection time (via `ALTER DATABASE SET` or connection pool initialization).

---

## Data at Rest — Backups

See `docs/ops/backup-retention-policy.md` for the full backup encryption specification.

Summary:
- All backup files are encrypted before leaving the host.
- Production: AWS KMS CMK envelope encryption.
- Local/dev: AES-256-GCM with PBKDF2 key derivation.

---

## Key Rotation

| Key Type | Rotation Interval | Procedure |
|----------|------------------|-----------|
| TLS private key + certificate | Annually | New CSR → CA signing → keystore update → rolling restart |
| AWS KMS CMK | Annually | Create new CMK; update alias; re-encrypt data keys in key metadata |
| DB pgcrypto symmetric key | Annually | Double-feed strategy: re-encrypt all encrypted columns with new key before old key expires |
| Backup symmetric key (dev) | Per deployment | New random key generated; stored in secrets manager |

All rotations must be completed during a maintenance window with a rollback plan.

---

## Secrets Management

Secrets are never:
- Committed to the repository
- Stored in mobile app binaries or frontend bundles
- Logged in plaintext in application logs
- Stored in mobile encrypted storage without an additional user-derived key

Secrets are loaded from (in priority order):
1. **AWS Secrets Manager** — production workloads; `VSP_SECRETS_MANAGER_REGION` and `VSP_SECRETS_MANAGER_SECRET_NAME` specify the target.
2. **HashiCorp Vault** — if `VSP_SECRETS_MANAGER_VAULT_ADDR` is set; AppRole authentication using `VSP_SECRETS_MANAGER_VAULT_ROLE_ID` + `VSP_SECRETS_MANAGER_VAULT_SECRET_ID`.
3. **Environment variables** — acceptable for local development only; never used in production.

Refer to `infra/scripts/setupLocalEnv.sh` for the full list of environment variables.

---

## Compliance

| Standard | Requirement | Implementation |
|----------|-----------|----------------|
| NFR9 | TLS 1.3 | `server.ssl.protocol=TLSv1.3` in prod profile |
| NFR9 | Encryption at rest | AWS KMS + pgcrypto |
| NFR10 | 7-year retention | S3 Object Lock + Glacier Deep Archive |
| PDPD (Vietnam) | Data retention/deletion | Annual review; automated deletion after retention expiry |
| OWASP Top 10 | No hardcoded secrets | Gitleaks CI; secrets in env vars only |

---

## Related Documents

- `apps/api/src/main/resources/application-prod.yml` — TLS configuration
- `infra/scripts/setupLocalEnv.sh` — Environment variable template for TLS, secrets manager, encryption keys
- `infra/scripts/backup.sh` — Encrypted backup procedure
- `docs/ops/backup-retention-policy.md` — Backup encryption and retention details
- `SECRETS_POLICY.md` — Repository secrets scanning policy
