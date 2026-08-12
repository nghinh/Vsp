#!/usr/bin/env bash
#
# Builds a release artifact with the compile-time configuration the app needs.
#
# This script exists because nothing in the repository passed the --dart-define
# values the app reads: no CI step, no Makefile, no fastlane config. Every
# release build therefore fell back to http://localhost:8080 for the API and to
# "no imagery provider" for the satellite basemap — and on a database where
# nearly every hole falls back to satellite, that meant a golfer got neither a
# map nor a server.
#
# Usage:
#   VSP_API_BASE_URL=https://api.example.vn \
#   MAPBOX_ACCESS_TOKEN=pk.xxxx \
#     tool/build_release.sh apk
#
# Targets: apk | appbundle | ipa
#
# Secrets are read from the environment and never written to a file here. In CI
# they come from the secret store; locally, export them in your shell or keep
# them in a file that .gitignore covers.

set -euo pipefail

TARGET="${1:-appbundle}"

fail() { echo "error: $*" >&2; exit 1; }

# ─── Required ────────────────────────────────────────────────────────────────

[ -n "${VSP_API_BASE_URL:-}" ] || fail \
  "VSP_API_BASE_URL is not set. A release build without it points at
   http://localhost:8080 — the phone itself — and every request fails."

case "$VSP_API_BASE_URL" in
  https://*) ;;
  http://*)
    echo "warning: VSP_API_BASE_URL is not https. Android blocks cleartext at" >&2
    echo "         targetSdk 28+ and iOS ATS blocks it too, so this will only" >&2
    echo "         work against a local server." >&2
    ;;
  *) fail "VSP_API_BASE_URL must be an absolute http(s) URL" ;;
esac

# ─── Optional ────────────────────────────────────────────────────────────────

DEFINES=(--dart-define="VSP_API_BASE_URL=$VSP_API_BASE_URL")

if [ -n "${VSP_PACKAGE_BASE_URL:-}" ]; then
  DEFINES+=(--dart-define="VSP_PACKAGE_BASE_URL=$VSP_PACKAGE_BASE_URL")
else
  echo "note: VSP_PACKAGE_BASE_URL unset — course packages will be fetched" >&2
  echo "      from the API's own /packages endpoint." >&2
fi

if [ -n "${GOOGLE_SERVER_CLIENT_ID:-}" ]; then
  case "$GOOGLE_SERVER_CLIENT_ID" in
    *.apps.googleusercontent.com) ;;
    *) fail "GOOGLE_SERVER_CLIENT_ID does not look like an OAuth client id.
     It must be the *web* client id from Google Cloud — the Android client id
     is resolved natively from the package name and signing certificate and
     will not produce an idToken here." ;;
  esac
  DEFINES+=(--dart-define="GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID")
else
  echo "warning: GOOGLE_SERVER_CLIENT_ID unset — the app hides the Google" >&2
  echo "         button rather than offer one that cannot work. Sign-in also" >&2
  echo "         needs an Android OAuth client registered for this build's" >&2
  echo "         signing certificate, and VSP_GOOGLE_CLIENT_IDS on the API." >&2
fi

# Apple platforms need a client of their own; Android resolves its client from
# the signing certificate instead, so this is unset for apk/appbundle.
if [ -n "${GOOGLE_IOS_CLIENT_ID:-}" ]; then
  case "$GOOGLE_IOS_CLIENT_ID" in
    *.apps.googleusercontent.com) ;;
    *) fail "GOOGLE_IOS_CLIENT_ID does not look like an OAuth client id." ;;
  esac
  DEFINES+=(--dart-define="GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID")
elif [ "$TARGET" = "ipa" ]; then
  echo "warning: GOOGLE_IOS_CLIENT_ID unset — this iOS build hides the Google" >&2
  echo "         button. Create an iOS OAuth client for the bundle id, and put" >&2
  echo "         its reversed form in ios/Runner/Info.plist as a" >&2
  echo "         CFBundleURLTypes scheme, or the consent screen has nowhere" >&2
  echo "         to return to." >&2
fi

if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
  DEFINES+=(--dart-define="MAPBOX_ACCESS_TOKEN=$MAPBOX_ACCESS_TOKEN")
elif [ -n "${VSP_SATELLITE_TILE_URL:-}" ]; then
  [ -n "${VSP_SATELLITE_ATTRIBUTION:-}" ] || fail \
    "VSP_SATELLITE_TILE_URL is set without VSP_SATELLITE_ATTRIBUTION.
     Imagery we cannot credit is imagery we do not display."
  DEFINES+=(--dart-define="VSP_SATELLITE_TILE_URL=$VSP_SATELLITE_TILE_URL")
  DEFINES+=(--dart-define="VSP_SATELLITE_ATTRIBUTION=$VSP_SATELLITE_ATTRIBUTION")
else
  echo "warning: no imagery provider configured. Holes with no surveyed" >&2
  echo "         geometry — which is nearly all of them — will offer the" >&2
  echo "         measuring tool over a plain canvas rather than over a" >&2
  echo "         photograph of the course." >&2
fi

# ─── Android signing ─────────────────────────────────────────────────────────

if [ "$TARGET" != "ipa" ] && [ ! -f android/key.properties ]; then
  fail "android/key.properties is missing, so the release would be unsigned.
     Copy android/key.properties.example and fill it in."
fi

echo "Building $TARGET against $VSP_API_BASE_URL"
exec flutter build "$TARGET" --release "${DEFINES[@]}"
