#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source only the conversion helper; the backup command itself is not run.
# shellcheck source=backup_postgres.sh
source "${script_dir}/backup_postgres.sh"

temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT

captured_dbname=''
pg_dump() {
	local argument
	for argument in "$@"; do
		case "${argument}" in
			--dbname=*) captured_dbname="${argument#--dbname=}" ;;
		esac
	done
}

DATABASE_URL='postgresql+psycopg://backup-user@db.internal:5432/boom_bala_staging' \
	BACKUP_DIR="${temporary_dir}/backups" run_backup
[[ "${captured_dbname}" == 'postgresql://backup-user@db.internal:5432/boom_bala_staging' ]]

already_libpq="$(database_url_to_libpq 'postgresql://backup-user@db.internal:5432/boom_bala_staging')"
[[ "${already_libpq}" == 'postgresql://backup-user@db.internal:5432/boom_bala_staging' ]]

if database_url_to_libpq 'mysql://backup-user@db.internal/boom_bala_staging' >/dev/null 2>&1; then
	echo 'unsupported database scheme was accepted' >&2
	exit 1
fi

echo 'backup database URL conversion: PASS'
