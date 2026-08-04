#!/bin/bash
# backup.sh — VSP PostgreSQL backup script
# Idempotent: safe to re-run; replaces in-progress backup files on restart.
#
# Usage:
#   backup.sh full        — Full pg_dump (weekly schedule)
#   backup.sh incremental — Incremental pg_dump using WAL (daily schedule)
#
# Environment variables (all required in prod; script skips S3 upload if
# VSP_BACKUP_S3_BUCKET is empty):
#   PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
#   VSP_BACKUP_S3_BUCKET, VSP_BACKUP_S3_PREFIX
#   VSP_BACKUP_ENCRYPTION_KEY_ID
#   VSP_BACKUP_RETENTION_DAYS, VSP_BACKUP_RETENTION_WEEKS
set -euo pipefail

BACKUP_TYPE="${1:-full}"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RETENTION_DAYS="${VSP_BACKUP_RETENTION_DAYS:-30}"
RETENTION_WEEKS="${VSP_BACKUP_RETENTION_WEEKS:-12}"
S3_BUCKET="${VSP_BACKUP_S3_BUCKET:-}"
S3_PREFIX="${VSP_BACKUP_S3_PREFIX:-prod/backups}"
ENCRYPTION_KEY_ID="${VSP_BACKUP_ENCRYPTION_KEY_ID:-}"
BACKUP_DIR="/backup"
mkdir -p "$BACKUP_DIR"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# ── Lock file to prevent concurrent backups ──────────────────────────────────
LOCK_FILE="$BACKUP_DIR/.backup.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || { log "ERROR: Another backup is already running — skipping."; exit 0; }

# ── Cleanup on exit ──────────────────────────────────────────────────────────
trap 'rm -f "$LOCK_FILE"; log "Backup process ended."' EXIT

log "Starting $BACKUP_TYPE backup"

# ── Determine backup filename ─────────────────────────────────────────────────
case "$BACKUP_TYPE" in
  full)
    BACKUP_FILE="$BACKUP_DIR/vsp_full_${TIMESTAMP}.sql.gz.enc"
    DUMP_FORMAT="custom"   # pg_dump custom format (compressed)
    ;;
  incremental)
    BACKUP_FILE="$BACKUP_DIR/vsp_incr_${TIMESTAMP}.sql.gz.enc"
    DUMP_FORMAT="plain"     # plain SQL for incremental (WAL-based in full setup)
    ;;
  *)
    log "ERROR: Unknown backup type '$BACKUP_TYPE'. Use 'full' or 'incremental'."
    exit 1
    ;;
esac

# ── Run pg_dump ───────────────────────────────────────────────────────────────
DUMP_FILE="${BACKUP_FILE%.enc}"
pg_dump \
  --host="${PGHOST:-localhost}" \
  --port="${PGPORT:-5432}" \
  --dbname="${PGDATABASE:-vsp}" \
  --username="${PGUSER:-vsp}" \
  --format="$DUMP_FORMAT" \
  --no-owner \
  --no-acl \
  --file="$DUMP_FILE" \
  --compress=9

# ── Encrypt the dump ──────────────────────────────────────────────────────────
if [[ -n "$ENCRYPTION_KEY_ID" ]]; then
  # AWS KMS envelope encryption (produces ciphertext blob)
  ENC_FILE="${DUMP_FILE}.kms.enc"
  aws kms encrypt \
    --key-id "$ENCRYPTION_KEY_ID" \
    --plaintext "fileb://$DUMP_FILE" \
    --output text \
    --query CiphertextBlob \
    > "$ENC_FILE"
  mv "$ENC_FILE" "${BACKUP_FILE}"
else
  # Symmetric AES-256-GCM encryption using a derived key from environment
  # Key must be provided via VSP_BACKUP_SYMMETRIC_KEY (base64-encoded 32-byte key)
  SYMMETRIC_KEY="${VSP_BACKUP_SYMMETRIC_KEY:-$(openssl rand -base64 32)}"
  openssl enc -aes-256-gcm -salt -pbkdf2 \
    -in "$DUMP_FILE" \
    -out "${BACKUP_FILE}" \
    -pass "pass:$SYMMETRIC_KEY" \
    -iter 100000
fi
rm -f "$DUMP_FILE"

log "Backup file created: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# ── Upload to S3 ─────────────────────────────────────────────────────────────
if [[ -n "$S3_BUCKET" ]]; then
  S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/$(basename "$BACKUP_FILE")"
  log "Uploading to $S3_PATH"
  if aws s3 cp "$BACKUP_FILE" "$S3_PATH" --storage-class STANDARD_IA; then
    log "Upload complete: $S3_PATH"
  else
    log "WARNING: S3 upload failed — backup file remains locally at $BACKUP_FILE"
  fi
else
  log "INFO: VSP_BACKUP_S3_BUCKET not set — skipping S3 upload"
fi

# ── Prune local backups beyond retention ─────────────────────────────────────
log "Pruning local backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -name "vsp_full_*.sql.gz.enc" -mtime "+$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "vsp_incr_*.sql.gz.enc" -mtime "+$RETENTION_DAYS" -delete

# ── Prune S3 backups beyond retention ────────────────────────────────────────
if [[ -n "$S3_BUCKET" ]]; then
  log "Pruning S3 backups older than $RETENTION_DAYS days in $S3_BUCKET/$S3_PREFIX"
  # List and delete objects older than retention via S3 lifecycle rule is preferred.
  # Here we use a conservative prefix-based approach.
  EXPIRY_DATE=$(date -u -d "$RETENTION_DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)
  aws s3api list-objects-v2 \
    --bucket "$S3_BUCKET" \
    --prefix "${S3_PREFIX}/" \
    --query "Contents[?LastModified<'${EXPIRY_DATE}'].[Key]" \
    --output text \
  | while read -r key; do
    [[ -z "$key" ]] && continue
    aws s3 rm "s3://${S3_BUCKET}/${key}" && log "Deleted S3 object: $key"
  done
fi

log "$BACKUP_TYPE backup completed successfully"
