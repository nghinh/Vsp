# Backup Retention Policy

## Overview

This document defines the Vietnam Smart Golf Platform (VSP) backup retention schedule, covering PostgreSQL database dumps and encrypted archive files. This policy supports operational recovery, regulatory compliance, and disaster recovery objectives.

---

## Scope

- **PostgreSQL database** (all schemas including `audit_entries`, course geometry, user data, rounds, scores)
- **Object storage** (S3 bucket — course packages, map tiles, PMTiles)
- **Retention applies to**: encrypted backup files stored locally and in S3

---

## Backup Schedule

| Type | Frequency | Time (UTC) | Method |
|------|-----------|------------|--------|
| Full backup | Weekly | Sunday 02:00 UTC | `pg_dump -Fc` (custom compressed format) |
| Incremental backup | Daily | Monday–Saturday 02:00 UTC | `pg_dump --format=plain --compress=9` |

---

## Retention Tiers

| Tier | Retention | Rationale |
|------|-----------|-----------|
| **Daily incremental** | 30 days | Short-term operational recovery |
| **Weekly full** | 12 weeks (~3 months) | Month-level recovery scenarios |
| **Monthly archive** | 12 months | Annual regulatory review, audit support |
| **Annual compliance archive** | 7 years | NFR10 compliance, data retention law (Vietnam PDPD) |

---

## Backup Encryption

All backups are encrypted at rest:

- **Production**: AWS KMS CMK envelope encryption (`VSP_BACKUP_ENCRYPTION_KEY_ID`)
- **Local/dev fallback**: AES-256-GCM with PBKDF2 key derivation, `VSP_BACKUP_SYMMETRIC_KEY` from secrets manager

No plaintext backups are written to persistent storage.

---

## Backup Verification

After each successful backup:

1. **Local integrity check** — `pg_restore --list` on the `.dump` file must succeed without errors
2. **S3 upload confirmation** — `aws s3 ls` confirms the object exists at the expected prefix
3. **Restore drill** (quarterly, staging environment) — A full restore is executed against the staging database and a smoke-check query is run

---

## Restoration Procedures

### Point-in-Time Recovery (PITR)

1. Identify the nearest full backup before the target time.
2. Restore the full backup with `pg_restore`.
3. Apply WAL segments (if using continuous archiving) up to the target timestamp.
4. Verify data integrity with a spot-check query.

### Latest Full Backup Restore

```bash
# Download from S3
aws s3 cp "s3://${VSP_BACKUP_S3_BUCKET}/${VSP_BACKUP_S3_PREFIX}/vsp_full_LATEST.tar.gz.enc" /tmp/
# Decrypt
aws kms decrypt --ciphertext-blob fileb:///tmp/vsp_full_LATEST.tar.gz.enc --output /tmp/vsp_full_LATEST.dump
# Restore
pg_restore --host="${PGHOST}" --port="${PGPORT}" --dbname="${PGDATABASE}" --username="${PGUSER}" /tmp/vsp_full_LATEST.dump
```

---

## Offsite and Disaster Recovery

- S3 bucket configured with **cross-region replication** to a secondary AWS region (ap-southeast-2).
- Backup bucket has **Object Lock (WORM)** enabled with a 7-year retention period on archived backups.
- An alternative: monthly backups are copied to an AWS Glacier Deep Archive vault for long-term compliance storage.

---

## Roles and Responsibilities

| Role | Responsibility |
|------|---------------|
| Platform Engineering | Run backup jobs, verify S3 upload, monitor cron health |
| Security Team | Audit backup encryption keys, review IAM policies for S3 access |
| Compliance Officer | Annual review of retention schedule against current regulations |
| DBA (on-call) | Execute restoration procedures during incident response |

---

## Related Documents

- `infra/scripts/backup.sh` — Automated backup script
- `infra/docker/docker-compose.yaml` — `backup-cron` service definition
- `docs/ops/encryption-policy.md` — Encryption standards for data at rest
- `SECRETS_POLICY.md` — Secrets scanning and management policy

---

## Review Schedule

This policy is reviewed and approved annually, or after any significant infrastructure change that affects backup or recovery procedures.

| Review Date | Reviewer | Notes |
|-------------|----------|-------|
| — | — | Initial version (Story 1.5 OBS-2) |
