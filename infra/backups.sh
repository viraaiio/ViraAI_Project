#!/usr/bin/env bash
set -euo pipefail

################################################################################
# ViraAI Backup Script (Hardened)
#
# - Daily, automated backups for:
#     * Application code (tar + compression)
#     * PostgreSQL database (pg_dump)
# - Upload artifacts to S3-compatible storage (Backblaze B2 via awscli).
# - Export metrics for observability (file-based or Pushgateway).
# - Enforce retention via lifecycle rules (storage-level) or optional cleanup job.
#
# Security:
# - Environment-driven config, no hardcoded secrets.
# - Safe logging (no secrets).
################################################################################

SCRIPT_NAME="$(basename "$0")"
NOW_UTC="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"

log_info() { printf '%s [INFO] [%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&1; }
log_warn() { printf '%s [WARN] [%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&1; }
log_error(){ printf '%s [ERROR][%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&2; }

################################################################################
# Configuration (Environment-Driven)
################################################################################

REQUIRED_VARS=(
  "VIRAAI_ENV"
  "VIRAAI_BACKUP_ROOT"
  "VIRAAI_CODE_PATH"
  "VIRAAI_PG_HOST"
  "VIRAAI_PG_PORT"
  "VIRAAI_PG_DATABASE"
  "VIRAAI_PG_USER"
  "VIRAAI_BACKUP_S3_ENDPOINT"
  "VIRAAI_BACKUP_S3_BUCKET"
  "VIRAAI_BACKUP_S3_REGION"
  "VIRAAI_BACKUP_RETENTION_DAYS"
)

# Optional metrics (file-based)
: "${VIRAAI_METRICS_DIR:=/var/lib/viraai/metrics}"        # writable dir for .prom files
: "${VIRAAI_METRICS_ENABLE:=1}"                           # 1=enable file metrics, 0=disable

# Optional Pushgateway (if you prefer pushing metrics)
: "${VIRAAI_PUSHGATEWAY_URL:=}"                           # e.g., http://pushgateway:9091
: "${VIRAAI_PUSHGATEWAY_ENABLE:=0}"                       # 1=enable pushgateway, 0=disable

check_env() {
  local missing=0
  for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var-}" ]]; then
      log_error "Missing required environment variable: ${var}"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    log_error "One or more required environment variables are missing. Aborting."
    exit 10
  fi
  if ! [[ "$VIRAAI_BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    log_error "VIRAAI_BACKUP_RETENTION_DAYS must be an integer. Current value: ${VIRAAI_BACKUP_RETENTION_DAYS}"
    exit 10
  fi
}

################################################################################
# Paths and Filenames
################################################################################

BACKUP_ROOT="${VIRAAI_BACKUP_ROOT%/}"
BACKUP_DIR="${BACKUP_ROOT}/${VIRAAI_ENV}/${NOW_UTC}"

CODE_ARCHIVE_NAME="code-${VIRAAI_ENV}-${NOW_UTC}.tar.gz"
DB_DUMP_NAME="db-${VIRAAI_ENV}-${NOW_UTC}.sql.gz"

CODE_ARCHIVE_PATH="${BACKUP_DIR}/${CODE_ARCHIVE_NAME}"
DB_DUMP_PATH="${BACKUP_DIR}/${DB_DUMP_NAME}"

################################################################################
# S3-Compatible Upload (Backblaze B2 via awscli)
################################################################################

ensure_awscli() {
  if ! command -v aws >/dev/null 2>&1; then
    log_error "awscli not found. Install awscli on the runner or container. Aborting."
    exit 40
  fi
  if [[ -z "${AWS_ACCESS_KEY_ID-}" || -z "${AWS_SECRET_ACCESS_KEY-}" ]]; then
    log_error "AWS credentials are not set (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY). Aborting."
    exit 40
  fi
}

upload_file_s3() {
  local file_path="$1"
  local object_key="$2"

  if [[ ! -f "$file_path" ]]; then
    log_error "File to upload not found: ${file_path}"
    return 1
  fi

  ensure_awscli

  local destination="s3://${VIRAAI_BACKUP_S3_BUCKET}/${object_key}"
  log_info "Uploading to object storage: ${destination}"

  # Disable metadata calls (faster, safer on non-EC2)
  AWS_EC2_METADATA_DISABLED=true \
  aws --endpoint-url "${VIRAAI_BACKUP_S3_ENDPOINT}" \
      --region "${VIRAAI_BACKUP_S3_REGION}" \
      s3 cp "${file_path}" "${destination}" --only-show-errors --no-progress

  log_info "Upload complete: ${destination}"
}

################################################################################
# Local Backup Creation
################################################################################

create_directories() {
  log_info "Creating backup directory: ${BACKUP_DIR}"
  mkdir -p "${BACKUP_DIR}"
}

backup_code() {
  log_info "Starting code backup from path: ${VIRAAI_CODE_PATH}"
  if [[ ! -d "${VIRAAI_CODE_PATH}" ]]; then
    log_error "Code path does not exist: ${VIRAAI_CODE_PATH}"
    exit 20
  fi
  tar -czf "${CODE_ARCHIVE_PATH}" -C "${VIRAAI_CODE_PATH}" .
  if [[ ! -f "${CODE_ARCHIVE_PATH}" ]]; then
    log_error "Failed to create code archive: ${CODE_ARCHIVE_PATH}"
    exit 20
  fi
  log_info "Code backup created: ${CODE_ARCHIVE_PATH}"
}

backup_database() {
  log_info "Starting PostgreSQL backup for DB: ${VIRAAI_PG_DATABASE} on ${VIRAAI_PG_HOST}:${VIRAAI_PG_PORT}"
  if ! command -v pg_dump >/dev/null 2>&1; then
    log_error "pg_dump not found in PATH."
    exit 30
  fi
  # PGPASSWORD must be provided via env or .pgpass; never logged.
  pg_dump \
    --host="${VIRAAI_PG_HOST}" \
    --port="${VIRAAI_PG_PORT}" \
    --username="${VIRAAI_PG_USER}" \
    --format=plain \
    "${VIRAAI_PG_DATABASE}" \
    | gzip > "${DB_DUMP_PATH}"
  if [[ ! -f "${DB_DUMP_PATH}" ]]; then
    log_error "Failed to create database dump: ${DB_DUMP_PATH}"
    exit 30
  fi
  log_info "Database backup created: ${DB_DUMP_PATH}"
}

################################################################################
# Remote Upload and Retention
################################################################################

upload_backups() {
  local code_key="backups/${VIRAAI_ENV}/code/${CODE_ARCHIVE_NAME}"
  local db_key="backups/${VIRAAI_ENV}/db/${DB_DUMP_NAME}"

  upload_file_s3 "${CODE_ARCHIVE_PATH}" "${code_key}" || { log_error "Upload failed (code)"; exit 40; }
  upload_file_s3 "${DB_DUMP_PATH}" "${db_key}" || { log_error "Upload failed (db)"; exit 40; }

  log_info "All artifacts uploaded successfully."
}

enforce_retention() {
  log_info "Retention policy (storage-level): ${VIRAAI_BACKUP_RETENTION_DAYS} days"
  log_info "Use Backblaze B2 Lifecycle Rules for bucket '${VIRAAI_BACKUP_S3_BUCKET}' to keep ${VIRAAI_BACKUP_RETENTION_DAYS} days and delete older versions."
  log_warn "No direct deletions performed by this script to preserve auditability. If required, implement an audited cleanup job."
}

################################################################################
# Metrics export
################################################################################

write_file_metrics_success() {
  [[ "${VIRAAI_METRICS_ENABLE}" -eq 1 ]] || return 0
  mkdir -p "${VIRAAI_METRICS_DIR}"
  local mf="${VIRAAI_METRICS_DIR}/backup.prom"
  local ts="$(date +%s)"
  cat > "${mf}.tmp" <<EOF
# TYPE viraai_backup_last_success_timestamp gauge
viraai_backup_last_success_timestamp{environment="${VIRAAI_ENV}"} ${ts}
# TYPE viraai_backup_failures_total counter
# Keep last failures counter file separate; do not reset here.
EOF
  mv "${mf}.tmp" "${mf}"
  log_info "File metrics updated: ${mf}"
}

increment_file_metrics_failure() {
  [[ "${VIRAAI_METRICS_ENABLE}" -eq 1 ]] || return 0
  mkdir -p "${VIRAAI_METRICS_DIR}"
  local ff="${VIRAAI_METRICS_DIR}/backup_failures.prom"
  local current=0
  if [[ -f "${ff}" ]]; then
    current="$(awk '/viraai_backup_failures_total/ {print $2}' "${ff}" || echo 0)"
  fi
  local next=$((current+1))
  cat > "${ff}.tmp" <<EOF
# TYPE viraai_backup_failures_total counter
viraai_backup_failures_total{environment="${VIRAAI_ENV}"} ${next}
EOF
  mv "${ff}.tmp" "${ff}"
  log_warn "File metrics failure counter incremented: ${next}"
}

pushgateway_metrics_success() {
  [[ "${VIRAAI_PUSHGATEWAY_ENABLE}" -eq 1 ]] || return 0
  [[ -n "${VIRAAI_PUSHGATEWAY_URL}" ]] || { log_warn "Pushgateway enabled but URL empty"; return 0; }
  local ts="$(date +%s)"
  cat <<EOF | curl -s -m 5 --retry 2 --data-binary @- "${VIRAAI_PUSHGATEWAY_URL}/metrics/job/viraai_backups/env/${VIRAAI_ENV}" >/dev/null || log_warn "Pushgateway push failed"
# TYPE viraai_backup_last_success_timestamp gauge
viraai_backup_last_success_timestamp ${ts}
EOF
  log_info "Metrics pushed to Pushgateway (success)"
}

pushgateway_metrics_failure() {
  [[ "${VIRAAI_PUSHGATEWAY_ENABLE}" -eq 1 ]] || return 0
  [[ -n "${VIRAAI_PUSHGATEWAY_URL}" ]] || { log_warn "Pushgateway enabled but URL empty"; return 0; }
  cat <<EOF | curl -s -m 5 --retry 2 --data-binary @- "${VIRAAI_PUSHGATEWAY_URL}/metrics/job/viraai_backups/env/${VIRAAI_ENV}" >/dev/null || log_warn "Pushgateway push failed"
# TYPE viraai_backup_failures_total counter
viraai_backup_failures_total 1
EOF
  log_info "Metrics pushed to Pushgateway (failure increment)"
}

################################################################################
# Main
################################################################################

main() {
  log_info "Starting backup run for environment: ${VIRAAI_ENV}"
  trap 'log_error "Backup run failed"; increment_file_metrics_failure; pushgateway_metrics_failure' ERR

  check_env
  create_directories
  backup_code
  backup_database
  upload_backups
  enforce_retention

  write_file_metrics_success
  pushgateway_metrics_success

  log_info "Backup run completed successfully."
}

main "$@"