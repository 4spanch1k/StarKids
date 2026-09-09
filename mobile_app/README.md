# Star Kids Mobile App

Flutter client for parents.

## Local development

Run the app with the Clerk publishable key passed through the Flutter
dart-define that the app reads:

```bash
flutter run --dart-define=MOBILE_CLERK_PUBLISHABLE_KEY=pk_test_ZnVua3ktc2Vhc25haWwtOTcuY2xlcmsuYWNjb3VudHMuZGV2JA
```

The backend Clerk secret stays backend-only. Configure these backend variables
locally with placeholder-free values in your private environment:

```bash
CLERK_SECRET_KEY=
CLERK_ISSUER=https://funky-seasentail-97.clerk.accounts.dev
CLERK_JWKS_URL=
CLERK_AUTHORIZED_PARTIES=
```

## Current foundation

- app shell
- route map
- theme
- environment config
- core infrastructure placeholders
- first feature slice structure for `branches`

## Initial slice order

1. onboarding
2. branch selection
3. home
4. branch details
5. birthdays request flow
