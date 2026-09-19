#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must be provided by the protected environment file}"

backup_dir="${BACKUP_DIR:-/var/backups/boom-bala/postgres}"
retention_days="${BACKUP_RETENTION_DAYS:-14}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="${backup_dir}/boom-bala-${timestamp}.sql.gz"
temporary_file="${backup_file}.tmp"

mkdir -p "${backup_dir}"
trap 'rm -f "${temporary_file}"' EXIT

# DATABASE_URL is injected by systemd from /etc/boom-bala/staging.env; the
# repository never contains a password or a pgpass file.
pg_dump --no-owner --no-privileges --dbname="${DATABASE_URL}" \
  | gzip -9 > "${temporary_file}"
mv "${temporary_file}" "${backup_file}"

find "${backup_dir}" -type f -name 'boom-bala-*.sql.gz' \
  -mtime "+${retention_days}" -delete

printf 'PostgreSQL backup written: %s\n' "${backup_file}"
