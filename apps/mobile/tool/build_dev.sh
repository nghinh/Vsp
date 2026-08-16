#!/usr/bin/env bash
#
# A debug build for a phone on a desk, with the same compile-time settings a
# release build gets.
#
# WHY THIS EXISTS
#
# build_release.sh already validates every define and warns about each one
# left out. Nothing did that for the builds that actually go on a test device,
# so those were assembled by hand — and by hand meant `flutter build ios
# --debug --dart-define=VSP_API_BASE_URL=...` and nothing else. Twice that
# shipped a phone a broken app for a reason nobody could see from the screen:
#
#   * with no VSP_API_BASE_URL the app reported "this build has no server
#     configured" on every request;
#   * with no GOOGLE_SERVER_CLIENT_ID the Google button hid itself, which is
#     the correct behaviour and looks exactly like the feature being missing.
#
# A flag you can forget is a flag you will forget. This carries them.
#
#   tool/build_dev.sh ios      # then: flutter install -d <device-id>
#   tool/build_dev.sh apk
#
# Settings come from the environment, or from tool/dev.env if it exists —
# which is gitignored, because a client id belongs to a deployment rather than
# to this repository.

set -euo pipefail
cd "$(dirname "$0")/.."

[ -f tool/dev.env ] && . tool/dev.env

TARGET="${1:-ios}"

: "${VSP_API_BASE_URL:=https://vps-api.vnteki.com}"

DEFINES=(--dart-define="VSP_API_BASE_URL=$VSP_API_BASE_URL")

if [ -n "${GOOGLE_SERVER_CLIENT_ID:-}" ]; then
  DEFINES+=(--dart-define="GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID")
else
  echo "warning: GOOGLE_SERVER_CLIENT_ID unset — the Google button will be" >&2
  echo "         hidden. That is deliberate, and indistinguishable on screen" >&2
  echo "         from the feature not existing." >&2
fi

# Apple platforms need a client of their own to open the consent screen, and
# its reversed form in ios/Runner/Info.plist. Without it the Google button
# stays hidden on iOS however good the server client id is.
if [ -n "${GOOGLE_IOS_CLIENT_ID:-}" ]; then
  DEFINES+=(--dart-define="GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID")
elif [ "$TARGET" = "ios" ]; then
  echo "note: GOOGLE_IOS_CLIENT_ID unset — Google sign-in stays hidden on" >&2
  echo "      iOS. Android is unaffected." >&2
fi

[ -n "${VSP_PACKAGE_BASE_URL:-}" ] &&
  DEFINES+=(--dart-define="VSP_PACKAGE_BASE_URL=$VSP_PACKAGE_BASE_URL")

echo "building $TARGET against $VSP_API_BASE_URL"
exec flutter build "$TARGET" --debug "${DEFINES[@]}"
