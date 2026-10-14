#!/usr/bin/env bash
set -euo pipefail

database_url_to_libpq() {
	local database_url="${1:?database URL is required}"
	case "${database_url}" in
		postgresql+psycopg://*)
			printf 'postgresql://%s\n' "${database_url#postgresql+psycopg://}"
			;;
		postgresql://*)
			printf '%s\n' "${database_url}"
			;;
		*)
			printf '%s\n' 'DATABASE_URL must use postgresql:// or postgresql+psycopg://' >&2
			return 1
			;;
	esac
}

run_backup() {
	: "${DATABASE_URL:?DATABASE_URL must be provided by the protected environment file}"

	local libpq_database_url
	libpq_database_url="$(database_url_to_libpq "${DATABASE_URL}")"

	local backup_dir="${BACKUP_DIR:-/var/backups/boom-bala/postgres}"
	local retention_days="${BACKUP_RETENTION_DAYS:-14}"
	local timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	local backup_file="${backup_dir}/boom-bala-${timestamp}.sql.gz"
	local temporary_file="${backup_file}.tmp"

	mkdir -p "${backup_dir}"
	trap 'rm -f "${temporary_file:-}"' EXIT

	# DATABASE_URL is injected by systemd from /etc/boom-bala/staging.env; the
	# repository never contains a password or a pgpass file. SQLAlchemy's
	# +psycopg driver suffix is removed because libpq does not understand it.
	pg_dump --no-owner --no-privileges --dbname="${libpq_database_url}" \
	  | gzip -9 > "${temporary_file}"
	mv "${temporary_file}" "${backup_file}"
	trap - EXIT

	find "${backup_dir}" -type f -name 'boom-bala-*.sql.gz' \
	  -mtime "+${retention_days}" -delete

	printf 'PostgreSQL backup written: %s\n' "${backup_file}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	run_backup
fi
