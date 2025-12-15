#!/usr/bin/env bash
set -euo pipefail

################################################################################
# ViraAI Restore Script (Hardened)
#
# - Safe restore for PostgreSQL from .sql.gz dumps.
# - Dry-run, operator confirmation, rollback snapshot before destructive actions.
# - Observability: success/failure metrics (file-based or Pushgateway).
################################################################################

SCRIPT_NAME="$(basename "$0")"

log_info() { printf '%s [INFO] [%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&1; }
log_warn() { printf '%s [WARN] [%s] %s\n' "$(date -u +"%Y:%m:%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&1; }
log_error(){ printf '%s [ERROR][%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SCRIPT_NAME" "$*" >&2; }

REQUIRED_VARS=(
  "VIRAAI_ENV"
  "VIRAAI_PG_HOST"
  "VIRAAI_PG_PORT"
  "VIRAAI_PG_DATABASE"
  "VIRAAI_PG_USER"
)

# Optional metrics
: "${VIRAAI_METRICS_DIR:=/var/lib/viraai/metrics}"
: "${VIRAAI_METRICS_ENABLE:=1}"
: "${VIRAAI_PUSHGATEWAY_URL:=}"
: "${VIRAAI_PUSHGATEWAY_ENABLE:=0}"

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
}

print_usage() {
  cat <<EOF
ViraAI Restore Script

Usage:
  ${SCRIPT_NAME} --db-backup /path/to/db-backup.sql.gz [--dry-run]

Options:
  --db-backup PATH   Path to the compressed PostgreSQL backup (.sql.gz).
  --dry-run          Validate inputs and connectivity without destructive changes.

Environment:
  VIRAAI_ENV, VIRAAI_PG_HOST, VIRAAI_PG_PORT, VIRAAI_PG_DATABASE, VIRAAI_PG_USER
  PGPASSWORD or .pgpass must be configured externally.
EOF
}

DB_BACKUP_PATH=""
DRY_RUN=0

parse_args() {
  if [[ "$#" -eq 0 ]]; then
    print_usage; exit 10
  fi
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --db-backup) DB_BACKUP_PATH="${2-}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift 1 ;;
      --help|-h) print_usage; exit 0 ;;
      *) log_error "Unknown argument: $1"; print_usage; exit 10 ;;
    esac
  done
  if [[ -z "${DB_BACKUP_PATH}" ]]; then
    log_error "--db-backup is required."; print_usage; exit 10
  fi
  if [[ ! -f "${DB_BACKUP_PATH}" ]]; then
    log_error "Backup file not found: ${DB_BACKUP_PATH}"; exit 10
  fi
}

confirm_destructive_action() {
  local prompt_message=$1
  log_info "DESTRUCTIVE OPERATION WARNING:"
  log_info "${prompt_message}"
  log_info "Target environment: ${VIRAAI_ENV}"
  log_info "Target database: ${VIRAAI_PG_DATABASE} on ${VIRAAI_PG_HOST}:${VIRAAI_PG_PORT}"
  printf 'Type "RESTORE %s" to confirm: ' "${VIRAAI_ENV}"
  local input; read -r input || true
  if [[ "${input}" != "RESTORE ${VIRAAI_ENV}" ]]; then
    log_error "Confirmation phrase mismatch. Aborting restore."; exit 20
  fi
}

validate_postgres_connection() {
  log_info "Validating PostgreSQL connectivity..."
  if ! command -v psql >/dev/null 2>&1; then
    log_error "psql not found."; exit 30
  fi
  PGPASSWORD="${PGPASSWORD-}" psql \
    --host="${VIRAAI_PG_HOST}" \
    --port="${VIRAAI_PG_PORT}" \
    --username="${VIRAAI_PG_USER}" \
    --dbname="${VIRAAI_PG_DATABASE}" \
    --command="SELECT 1;" >/dev/null 2>&1 || {
      log_error "Failed to connect to PostgreSQL."; exit 30;
    }
  log_info "PostgreSQL connectivity validated."
}

backup_current_database_state() {
  local timestamp; timestamp="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
  local rollback_dir="./rollback-backups/${VIRAAI_ENV}"
  local rollback_file="${rollback_dir}/db-before-restore-${timestamp}.sql.gz"
  log_info "Creating rollback snapshot at: ${rollback_file}"
  mkdir -p "${rollback_dir}"
  if ! command -v pg_dump >/dev/null 2>&1; then
    log_error "pg_dump not found."; exit 40
  fi
  pg_dump \
    --host="${VIRAAI_PG_HOST}" \
    --port="${VIRAAI_PG_PORT}" \
    --username="${VIRAAI_PG_USER}" \
    --format=plain \
    "${VIRAAI_PG_DATABASE}" \
    | gzip > "${rollback_file}"
  if [[ ! -f "${rollback_file}" ]]; then
    log_error "Failed to create rollback snapshot."; exit 40
  fi
  log_info "Rollback snapshot created successfully."
}

perform_restore() {
  log_info "Starting restore from: ${DB_BACKUP_PATH}"
  if ! command -v psql >/dev/null 2>&1; then
    log_error "psql not found."; exit 50
  fi
  log_info "Restoring database. This may take some time..."
  gunzip -c "${DB_BACKUP_PATH}" \
    | PGPASSWORD="${PGPASSWORD-}" psql \
        --host="${VIRAAI_PG_HOST}" \
        --port="${VIRAAI_PG_PORT}" \
        --username="${VIRAAI_PG_USER}" \
        --dbname="${VIRAAI_PG_DATABASE}"
  log_info "Database restore completed successfully."
}

# Metrics
write_file_metrics_success() {
  [[ "${VIRAAI_METRICS_ENABLE}" -eq 1 ]] || return 0
  mkdir -p "${VIRAAI_METRICS_DIR}"
  local mf="${VIRAAI_METRICS_DIR}/restore.prom"
  local ts="$(date +%s)"
  cat > "${mf}.tmp" <<EOF
# TYPE viraai_restore_last_success_timestamp gauge
viraai_restore_last_success_timestamp{environment="${VIRAAI_ENV}"} ${ts}
# TYPE viraai_restore_failures_total counter
# Keep failures counter in a separate file.
EOF
  mv "${mf}.tmp" "${mf}"
  log_info "File metrics updated: ${mf}"
}
increment_file_metrics_failure() {
  [[ "${VIRAAI_METRICS_ENABLE}" -eq 1 ]] || return 0
  mkdir -p "${VIRAAI_METRICS_DIR}"
  local ff="${VIRAAI_METRICS_DIR}/restore_failures.prom"
  local current=0
  if [[ -f "${ff}" ]]; then
    current="$(awk '/viraai_restore_failures_total/ {print $2}' "${ff}" || echo 0)"
  fi
  local next=$((current+1))
  cat > "${ff}.tmp" <<EOF
# TYPE viraai_restore_failures_total counter
viraai_restore_failures_total{environment="${VIRAAI_ENV}"} ${next}
EOF
  mv "${ff}.tmp" "${ff}"
  log_warn "File metrics failure counter incremented: ${next}"
}
pushgateway_metrics_success() {
  [[ "${VIRAAI_PUSHGATEWAY_ENABLE}" -eq 1 ]] || return 0
  [[ -n "${VIRAAI_PUSHGATEWAY_URL}" ]] || { log_warn "Pushgateway enabled but URL empty"; return 0; }
  local ts="$(date +%s)"
  cat <<EOF | curl -s -m 5 --retry 2 --data-binary @- "${VIRAAI_PUSHGATEWAY_URL}/metrics/job/viraai_restore/env/${VIRAAI_ENV}" >/dev/null || log_warn "Pushgateway push failed"
# TYPE viraai_restore_last_success_timestamp gauge
viraai_restore_last_success_timestamp ${ts}
EOF
  log_info "Metrics pushed to Pushgateway (success)"
}
pushgateway_metrics_failure() {
  [[ "${VIRAAI_PUSHGATEWAY_ENABLE}" -eq 1 ]] || return 0
  [[ -n "${VIRAAI_PUSHGATEWAY_URL}" ]] || { log_warn "Pushgateway enabled but URL empty"; return 0; }
  cat <<EOF | curl -s -m 5 --retry 2 --data-binary @- "${VIRAAI_PUSHGATEWAY_URL}/metrics/job/viraai_restore/env/${VIRAAI_ENV}" >/dev/null || log_warn "Pushgateway push failed"
# TYPE viraai_restore_failures_total counter
viraai_restore_failures_total 1
EOF
  log_info "Metrics pushed to Pushgateway (failure increment)"
}

main() {
  trap 'log_error "Restore failed"; increment_file_metrics_failure; pushgateway_metrics_failure' ERR

  parse_args "$@"
  check_env
  validate_postgres_connection

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log_info "Dry run enabled. No destructive operations will be performed."
    log_info "Validated env variables, backup file presence, and PostgreSQL connectivity."
    exit 0
  fi

  confirm_destructive_action "You are about to overwrite the target database with the backup file."
  backup_current_database_state
  perform_restore

  write_file_metrics_success
  pushgateway_metrics_success
}

main "$@"