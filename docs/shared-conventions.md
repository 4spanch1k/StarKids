# Shared Conventions

## Repository rules

- `mobile_app` is the parent-facing client only.
- `admin_panel` is the internal backoffice only.
- `backend` is the single API center for mobile, admin, auth, leads, and notifications.
- Each product must stay independently deployable.

## Architecture rules

- Keep modules cohesive and small.
- Keep transport, business rules, and persistence separate.
- Prefer domain names over generic utility names.
- Extract shared infrastructure only when more than one module needs it.
- Do not hide core business behavior behind generic helpers.

## Vertical slice rule

Default delivery order:

1. backend endpoint contract
2. admin operational flow if the feature affects staff
3. mobile user flow
4. instrumentation and verification

## State and API rules

- Do not call APIs directly from Vue page components.
- Keep Flutter networking and storage abstractions in `core`.
- Keep backend routers thin and move behavior into services.
- Repositories own database reads and writes.
- Schemas define request and response contracts.

## UX state rule

Every user-facing feature should define:

- loading state
- empty state
- error state
- success or completed state

## Configuration rule

- Environment variables are defined in the root `.env.example`.
- Each app reads only its own prefixed keys.
- No secrets in source control.
- Add new variables to `.env.example` before using them in code.

