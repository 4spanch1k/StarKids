#!/bin/sh

# Signed/archive builds must provide the native reversed client ID used by
# google_sign_in_ios. Unsigned Flutter compile checks intentionally remain
# possible without deployment credentials.
if { [ "$CONFIGURATION" = "Release" ] || [ "$CONFIGURATION" = "Profile" ]; } &&
  { [ "$ACTION" = "install" ] || [ "$CODE_SIGNING_ALLOWED" = "YES" ]; } &&
  [ -z "${GOOGLE_IOS_REVERSED_CLIENT_ID:-}" ]; then
  echo "error: Set GOOGLE_IOS_REVERSED_CLIENT_ID for signed/archive Google Sign-In builds." >&2
  exit 1
fi
