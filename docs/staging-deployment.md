# Boom Bala staging deployment (Ubuntu VPS)

This runbook describes the first staging deployment on one ordinary Ubuntu VPS:

```text
Internet -> Caddy HTTPS -> FastAPI (127.0.0.1:8000) -> PostgreSQL (local)
                     \-> admin_panel/dist (static SPA)
```

The checked-in systemd units assume `/opt/boom-bala` as the checkout and a
dedicated `boom-bala` user. Replace the paths only if the installation uses a
different layout. No payment, ticket, QR, Visit, auth, or loyalty semantics are
changed by this deployment setup.

## 1. External prerequisites

Before touching the VPS, obtain:

- an Ubuntu VPS with a static public IP and SSH access;
- DNS `A`/`AAAA` records for `api-staging.boombala.kz` and
  `ops-staging.boombala.kz` pointing to that IP;
- inbound TCP 80/443 (Caddy uses these for ACME and HTTPS), with PostgreSQL
  bound to loopback only;
- a reviewed FreedomPay sandbox merchant/secret and a public result URL;
- a persistent disk or volume for `/var/lib/boom-bala/media` and
  `/var/backups/boom-bala/postgres`.

Do not put any of these credentials in the repository.

## 2. Install operating-system packages

```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-dev build-essential \
  libpq-dev postgresql postgresql-client curl ca-certificates nodejs npm
```

Install Caddy from its official Ubuntu package repository, then verify:

```bash
caddy version
```

## 3. Create the service user and checkout

```bash
sudo useradd --system --home /opt/boom-bala --shell /usr/sbin/nologin boom-bala
sudo mkdir -p /opt/boom-bala /etc/boom-bala /var/lib/boom-bala/media \
  /var/backups/boom-bala/postgres
sudo chown -R boom-bala:boom-bala /opt/boom-bala /var/lib/boom-bala \
  /var/backups/boom-bala
sudo -u boom-bala git clone <PRIVATE_REPOSITORY_URL> /opt/boom-bala
cd /opt/boom-bala
sudo -u boom-bala git checkout <KNOWN_GOOD_COMMIT>
```

Pin the exact commit used for the staging smoke test. Rollback is a checkout
of the previous known-good commit followed by dependency installation and a
service restart; never perform an automatic destructive database downgrade.

## 4. Python environment and PostgreSQL

```bash
sudo -u boom-bala python3 -m venv /opt/boom-bala/backend/.venv
sudo -u boom-bala /opt/boom-bala/backend/.venv/bin/pip install --upgrade pip
sudo -u boom-bala /opt/boom-bala/backend/.venv/bin/pip install \
  -r /opt/boom-bala/backend/requirements.txt
```

Create a separate database role and database. Keep PostgreSQL local; do not
open port 5432 to the Internet.

```bash
sudo -u postgres createuser --pwprompt boom_bala
sudo -u postgres createdb --owner=boom_bala boom_bala_staging
sudo -u postgres psql -c "ALTER ROLE boom_bala SET statement_timeout = '30s';"
```

Copy the template and fill it on the VPS, never in git:

```bash
sudo install -o root -g boom-bala -m 0640 \
  /opt/boom-bala/backend/deploy/env/staging.env.example \
  /etc/boom-bala/staging.env
sudoedit /etc/boom-bala/staging.env
```

`APP_ENV=staging` enables production-like fail-closed checks while allowing
`FREEDOMPAY_TESTING_MODE=true`; `FREEDOMPAY_MOCK_MODE` must remain `false`.
Set unique values for `JWT_SECRET_KEY` and `TICKET_QR_SECRET`. The QR secret
must be random, at least the length enforced by the backend, kept outside git,
and stable across restarts of this environment. Replacing it invalidates
existing signed QR payloads.

Run migrations as an explicit deploy step, not from every web process:

```bash
cd /opt/boom-bala/backend
sudo -u boom-bala env $(sudo sed 's/#.*//' /etc/boom-bala/staging.env | xargs) \
  /opt/boom-bala/backend/.venv/bin/python -m alembic upgrade head
```

For secrets containing shell metacharacters, use a protected interactive
shell or an equivalent environment loader rather than the illustrative `env`
shortcut above. Verify the migration result with `alembic current`.

## 5. Build the admin SPA

```bash
cd /opt/boom-bala/admin_panel
sudo -u boom-bala npm ci
sudo -u boom-bala env \
  VITE_API_BASE_URL=https://api-staging.boombala.kz/api/v1 \
  npm run build
```

The production config rejects localhost, loopback, placeholder, and tunnel
hosts. The static output is `/opt/boom-bala/admin_panel/dist`; it contains no
backend secrets.

## 6. Install Caddy

```bash
sudo install -o root -g root -m 0644 \
  /opt/boom-bala/backend/deploy/caddy/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl enable --now caddy
```

Caddy obtains and renews HTTPS certificates automatically once DNS and ports
80/443 are correct. The admin site uses an SPA fallback to `index.html`.

## 7. Install and start systemd services

```bash
sudo install -o root -g root -m 0644 \
  /opt/boom-bala/backend/deploy/systemd/boom-bala-api.service \
  /etc/systemd/system/
sudo install -o root -g root -m 0644 \
  /opt/boom-bala/backend/deploy/systemd/boom-bala-finalize-visits.service \
  /opt/boom-bala/backend/deploy/systemd/boom-bala-finalize-visits.timer \
  /opt/boom-bala/backend/deploy/systemd/boom-bala-postgres-backup.service \
  /opt/boom-bala/backend/deploy/systemd/boom-bala-postgres-backup.timer \
  /etc/systemd/system/
sudo chown boom-bala:boom-bala /opt/boom-bala/backend/deploy/scripts/backup_postgres.sh
sudo systemctl daemon-reload
sudo systemctl enable --now boom-bala-api.service
sudo systemctl enable --now boom-bala-finalize-visits.timer
sudo systemctl enable --now boom-bala-postgres-backup.timer
```

The API and Visit finalizer run as `boom-bala`, use the same protected
`/etc/boom-bala/staging.env`, and never use `--reload`. The API binds only to
loopback. Existing optional cleanup/reminder units in this directory use the
same environment-file convention; enable them only when their feature config
is complete.

## 8. Backups and logs

The backup timer runs `pg_dump`, gzip-compresses a timestamped file, and
retains the configured number of days (14 by default). The database password
is supplied only through the protected environment file, never through this
script or git.

```bash
sudo systemctl start boom-bala-postgres-backup.service
sudo systemctl list-timers 'boom-bala-*'
sudo journalctl -u boom-bala-api --since today
sudo journalctl -u boom-bala-finalize-visits --since today
sudo journalctl -u boom-bala-postgres-backup --since today
```

Confirm that the backup directory is on persistent storage and is itself
included in the VPS backup policy. Repository configuration cannot prove an
off-host copy.

## 9. Smoke checks

```bash
curl --fail --silent --show-error \
  https://api-staging.boombala.kz/healthz
curl --fail --silent --show-error \
  https://ops-staging.boombala.kz/login
```

Expected health response is HTTP 200 with `{"status":"ok"}`. Then perform a
single FreedomPay sandbox purchase with the result URL from the template and
verify the existing callback, payment, ticket, and QR flow. A mobile staging
release uses the centralized environment config, but is blocked until Legal
supplies an approved HTTPS privacy URL and consent version. Do not substitute
the ops domain or another placeholder. Server and admin staging deployment do
not depend on this mobile release blocker. Once Legal has approved both values,
export them and run:

```bash
: "${MOBILE_PRIVACY_POLICY_URL:?set the approved HTTPS privacy URL}"
: "${MOBILE_PRIVACY_CONSENT_VERSION:?set the approved consent version}"
flutter build apk --release \
  --dart-define=MOBILE_APP_ENV=production \
  --dart-define=MOBILE_API_BASE_URL=https://api-staging.boombala.kz/api/v1/mobile \
  --dart-define=MOBILE_PRIVACY_POLICY_URL="${MOBILE_PRIVACY_POLICY_URL}" \
  --dart-define=MOBILE_PRIVACY_CONSENT_VERSION="${MOBILE_PRIVACY_CONSENT_VERSION}"
```

## 10. Rollback basics

1. Stop or drain the API before switching code.
2. Checkout the previous known-good commit.
3. Reinstall requirements if `requirements.txt` changed.
4. Run only forward migrations required by that commit.
5. Restart `boom-bala-api.service` and verify `/healthz`.

Do not delete the database or run an automatic `alembic downgrade` as a
rollback mechanism. Preserve the current backup before any schema operation.

## External blockers and ownership

DNS records, VPS IP/SSH access, firewall rules, Caddy certificate issuance,
PostgreSQL disk/backup durability, FreedomPay sandbox credentials, Firebase
runtime values, and mobile signing credentials are external deployment inputs.
They are intentionally represented as placeholders in the repository template.
