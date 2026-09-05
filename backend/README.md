# Star Kids Backend

FastAPI backend for mobile and admin products.

## Responsibilities

- mobile API
- admin API
- auth
- lead processing
- content delivery
- push registration
- integration-ready module boundaries

## Operational payment cleanup

`scripts/expire_mobile_payments.py` is the idempotent reconciliation pass for
abandoned FreedomPay initializations. It marks only expired `created`/`pending`
payments as `expired` and releases their still-reserved loyalty bonuses. It
also retries loyalty settlement for already-`paid` payments whose ticket
delivery succeeded before a transient loyalty failure. Both passes are
idempotent and safe to run concurrently: terminal payments and already
settled/released reservations are ignored.

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

The service reads the same backend environment file as the API from
`/etc/boom-bala/backend.env`; it does not contain credentials or secrets.
