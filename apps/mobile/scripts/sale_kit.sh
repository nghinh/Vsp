#!/usr/bin/env bash
#
# Photographs a full eighteen at Long Biên, for showing people.
#
#   scripts/sale_kit.sh <simulator-udid> [api-base-url]
#   xcrun simctl list devices available   # to find the udid
#
# The finished set lands in docs/sale-kit/<theme>/ inside the repository, with
# an index naming each picture. The run itself writes to /tmp: a failure half
# way through should not leave a half-built kit committed.
#
# Three things this does that `flutter test` alone does not, each of which has
# cost a run:
#
#   * Cycles the simulator. One left booted from an earlier run hands Flutter a
#     surface that never repaints — takeScreenshot returns identical bytes for
#     every screen, and the run still passes.
#
#   * Puts the golfer on the golf course. Without a location the simulator
#     reports Cupertino, so every distance reads "no fix" and the satellite
#     view opens over California. There is no faster way to make a screenshot
#     worthless.
#
#   * Passes the API base url. A build without it points at localhost, and the
#     app that comes up has no courses in it at all.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: scripts/sale_kit.sh <simulator-udid> [api-base-url]" >&2
  echo "" >&2
  xcrun simctl list devices available | grep -i iphone >&2 || true
  exit 64
fi

DEVICE="$1"
API_BASE_URL="${2:-https://vps-api.vnteki.com}"
THEME="${VSP_KIT_THEME:-dark}"
cd "$(dirname "$0")/.."

# The first tee at Long Biên's Đường A. The app's own "is the golfer on this
# hole" guard works to a kilometre, so this puts every hole of both nines
# within reach of a real fix.
LAT="${VSP_KIT_LAT:-21.0384}"
LNG="${VSP_KIT_LNG:-105.8920}"

OUT="/tmp/vsp-sale-kit/$THEME"
KIT="docs/sale-kit/$THEME"

# Old PNGs are worse than none: a step that fails silently leaves the previous
# run's picture behind, and it gets reviewed as if it were this run's.
rm -rf "/tmp/vsp-sale-kit"

echo "==> cycling $DEVICE so its surface repaints"
xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

echo "==> standing the golfer on the first tee at $LAT,$LNG"
xcrun simctl location "$DEVICE" set "$LAT,$LNG"

# The eighteen holes of Đường A then Đường B, each the middle of its own
# corridor — tee, fairway and green averaged from the published packages.
#
# The tour walks: it writes the hole it is playing to hole.txt and the watcher
# below moves the simulator there. Without this the golfer stands on the first
# tee for the whole round, hole detection drags the card back to the 1st a
# second after every advance, and the kit comes back with a card of ten holes.
# Fighting the app for the camera would have produced a picture of the fight;
# walking makes the app right.
HOLES=(
  "21.035815,105.893826" "21.035472,105.889832" "21.034422,105.887778"
  "21.033067,105.886036" "21.035527,105.886865" "21.036425,105.888153"
  "21.036469,105.888694" "21.037408,105.888512" "21.035190,105.893175"
  "21.035702,105.894896" "21.034853,105.893899" "21.034202,105.895339"
  "21.032620,105.897311" "21.031468,105.896052" "21.032699,105.896280"
  "21.033675,105.893839" "21.033371,105.893590" "21.035032,105.893875"
)

HOLE_FILE="/tmp/vsp-sale-kit/hole.txt"
mkdir -p "$(dirname "$HOLE_FILE")"

walk_with_the_tour() {
  local last=""
  while :; do
    if [[ -f "$HOLE_FILE" ]]; then
      local want
      want="$(cat "$HOLE_FILE" 2>/dev/null || true)"
      if [[ -n "$want" && "$want" != "$last" && "$want" =~ ^[0-9]+$ ]] \
         && (( want >= 1 && want <= 18 )); then
        xcrun simctl location "$DEVICE" set "${HOLES[$((want - 1))]}" \
          >/dev/null 2>&1 || true
        echo "    walked to hole $want"
        last="$want"
      fi
    fi
    sleep 1
  done
}

walk_with_the_tour &
WALKER=$!
# The walker outlives a failed test otherwise, and a stray process moving a
# simulator around is a confusing thing to leave behind.
trap 'kill "$WALKER" 2>/dev/null || true' EXIT

echo "==> playing eighteen in $THEME against $API_BASE_URL"
flutter test integration_test/sale_kit_test.dart \
  -d "$DEVICE" \
  --dart-define=VSP_API_BASE_URL="$API_BASE_URL" \
  --dart-define=VSP_KIT_THEME="$THEME"

kill "$WALKER" 2>/dev/null || true

shots=$(find "$OUT" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
echo "==> $shots screenshots in $OUT"

# Only a run that got to the end puts anything in the repository.
rm -rf "$KIT"
mkdir -p "$KIT"
cp "$OUT"/*.png "$KIT"/
echo "==> copied to $KIT"
