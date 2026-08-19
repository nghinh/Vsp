#!/usr/bin/env bash
# Builds the release artefacts with the defines a device actually needs.
#
# Both values are compile-time constants — `String.fromEnvironment` with no
# runtime fallback — so a build that forgets them cannot be fixed by a setting
# afterwards. Forgetting them is easy and the result looks like a working
# build until it is opened:
#
#   * without VSP_API_BASE_URL the app carries the default localhost and opens
#     on "Bản dựng này chưa cấu hình máy chủ";
#   * without GOOGLE_SERVER_CLIENT_ID the Google button hides itself, because
#     a token minted with no audience is refused by the API.
#
# Which is why the defines live here rather than in a note somewhere.
#
#   scripts/release.sh              # both
#   scripts/release.sh apk          # Android only
#   scripts/release.sh ios          # iOS only
#
# The iOS build produces an .app for a device. Install it with
# `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app`
# rather than `flutter install`, which uninstalls first and takes every course
# package the golfer has downloaded with it.
set -euo pipefail

cd "$(dirname "$0")/.."

API_BASE_URL="${VSP_API_BASE_URL:-https://vps-api.vnteki.com}"
GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}"

if [ -z "$GOOGLE_SERVER_CLIENT_ID" ]; then
  echo "GOOGLE_SERVER_CLIENT_ID is not set — the Google sign-in button will be" >&2
  echo "hidden in this build. It is the web OAuth client id, the same value the" >&2
  echo "server carries as VSP_GOOGLE_CLIENT_IDS." >&2
fi

what="${1:-both}"

defines=(--dart-define=VSP_API_BASE_URL="$API_BASE_URL")
if [ -n "$GOOGLE_SERVER_CLIENT_ID" ]; then
  defines+=(--dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID")
fi

if [ "$what" = "apk" ] || [ "$what" = "both" ]; then
  echo "Building the APK against $API_BASE_URL"
  flutter build apk --release "${defines[@]}"
fi

if [ "$what" = "ios" ] || [ "$what" = "both" ]; then
  echo "Building the iOS app against $API_BASE_URL"
  flutter build ios --release "${defines[@]}"
fi
