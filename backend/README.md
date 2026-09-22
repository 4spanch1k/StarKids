# Star Kids Backend

FastAPI backend for mobile and admin products.

## Required environment

`APP_ENV` is mandatory and must be exactly one of `development`, `test`,
`staging`, or `production`. The backend fails during startup for a missing or
unknown value; it never falls back to development authentication. Use
`APP_ENV=development` only for an explicit local environment,
`APP_ENV=test` for test commands, and `APP_ENV=staging` for the VPS sandbox
deployment. Staging keeps production-like fail-closed validation while allowing
`FREEDOMPAY_TESTING_MODE=true`; mock payments remain forbidden.

## Responsibilities

- mobile API
- admin API
- auth
- lead processing
- content delivery
- push registration
- integration-ready module boundaries

## Local phone OTP

With `APP_ENV=development` and `OTP_MOCK_MODE=true`, `/auth/request-otp`
creates a persisted, single-use challenge and prints the six-digit code to the
backend console. This is a local delivery adapter, not an SMS provider; keep
the flag disabled in staging and production. Challenges expire after
`OTP_CODE_TTL_SECONDS` (default 300 seconds) and lock after
`OTP_MAX_ATTEMPTS` (default 5).

## Operational payment cleanup

`scripts/expire_mobile_payments.py` is the idempotent reconciliation pass for
abandoned FreedomPay initializations. It marks only expired `created`/`pending`
payments as `expired` and releases their still-reserved loyalty bonuses. It
also reconciles already-`paid` payments whose ticket issuance or loyalty
settlement was interrupted by a transient failure. Both passes are idempotent
and safe to run concurrently: terminal payments and already settled/released
reservations are ignored.

For the production systemd deployment, install the checked-in unit and timer,
then adjust the deployment paths/user if the application is not installed at
`/opt/boom-bala`:

```bash
sudo cp deploy/systemd/boom-bala-expire-mobile-payments.service /etc/systemd/system/
sudo cp deploy/systemd/boom-bala-expire-mobile-payments.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now boom-bala-expire-mobile-payments.timer
systemctl status boom-bala-expire-mobile-payments.timer
```

The service reads the same protected environment file as the API from
`/etc/boom-bala/staging.env`; it does not contain credentials or secrets.
