# Integrations

External adapters will live here:

- CRM
- WhatsApp
- push delivery
- payments
- SMS (`sms.py` currently exposes the development console adapter and a
  fail-closed production placeholder; environment values alone do not mean
  real delivery is available, and a vendor-specific HTTP contract is still
  required before staging/production delivery can be enabled)
