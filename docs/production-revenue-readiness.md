# Production revenue readiness runbook

This runbook covers the verified deployment steps for the
`login → ticket → payment callback → issued ticket → QR → redemption → Visit`
flow. It does not replace provider, legal, or store-release approval.

## Required configuration

Provide these values through the deployment environment, never in git:

- `APP_ENV=production`
- `DATABASE_URL` using the supported PostgreSQL driver
- `JWT_SECRET_KEY` and `TICKET_QR_SECRET`
- `FREEDOMPAY_MERCHANT_ID`, `FREEDOMPAY_SECRET_KEY`, `FREEDOMPAY_BASE_URL`
- `FREEDOMPAY_RESULT_URL`, `FREEDOMPAY_SUCCESS_URL`, `FREEDOMPAY_FAILURE_URL`
- `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` when push is enabled
- `STORAGE_BACKEND` and persistent `MEDIA_ROOT` storage
- `MOBILE_API_BASE_URL` and approved privacy policy build defines
- `VITE_API_BASE_URL`

Production validation must remain fail-closed for missing secrets, mock modes,
SQLite, localhost origins, and placeholder URLs.

## Deploy order

1. Take/verify a PostgreSQL backup.
2. Deploy the application revision and run `alembic upgrade head`.
3. Start/restart the backend and verify `/healthz`.
4. Build and publish the admin panel.
5. Enable payment-expiry, push-campaign, birthday-reminder, and visit-finalizer timers.
6. Validate media persistence and inspect application logs.

## Smoke test

Use a dedicated test account and test payment configuration:

1. Register/login and complete onboarding.
2. Select a branch and obtain a ticket quote.
3. Complete a provider-confirmed payment callback.
4. Confirm `MobilePayment=paid` and exactly-once `IssuedTicket` rows.
5. Open the signed QR and redeem it at the correct branch.
6. Confirm the ticket becomes `used`, one `TicketRedemption` exists, and one
   `Visit` is visible to the mobile account.
7. Scan the same QR again and verify deterministic `already_used`.

## Failure checks

- invalid or tampered QR is rejected;
- wrong branch/date is rejected;
- duplicate provider callback does not issue another ticket;
- paid payment with a failed issuance remains visible in reconciliation;
- expired payment releases any reserved bonus amount;
- production configuration rejects mock OTP/payment and non-PostgreSQL DB URLs.

## Refund boundary

There is no provider-backed refund execution in this repository. Do not mark a
paid payment refunded from the admin UI. Refunds require a provider operation
and a separate, idempotent local reversal workflow before being exposed.

## External gates

Provider merchant credentials, real payment execution, privacy-policy approval,
production PostgreSQL operations/backups, FCM service-account setup, and mobile
store signing must be validated in the target environment.
