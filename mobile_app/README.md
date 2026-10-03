# Star Kids Mobile App

Flutter client for parents.

## Local development

Run the app with the Clerk publishable key passed through the Flutter
dart-define that the app reads:

```bash
flutter run --dart-define=MOBILE_CLERK_PUBLISHABLE_KEY=pk_test_ZnVua3ktc2Vhc25haWwtOTcuY2xlcmsuYWNjb3VudHMuZGV2JA
```

Social sign-in also requires the Google client defines used by the native
gateway (`MOBILE_GOOGLE_SERVER_CLIENT_ID`, plus the iOS client and reversed
client ID on iOS). On iOS, enable Sign in with Apple for the app target and
configure the Apple connection in Clerk; the app passes the native Apple ID
token to the same Clerk exchange endpoint.

The backend Clerk secret stays backend-only. Configure these backend variables
locally with placeholder-free values in your private environment:

```bash
CLERK_SECRET_KEY=private-value
CLERK_ISSUER=https://your-instance.clerk.accounts.dev
CLERK_JWKS_URL=https://your-instance.clerk.accounts.dev/.well-known/jwks.json
CLERK_AUTHORIZED_PARTIES=your-mobile-client-azp
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
