#!/usr/bin/env bash
#
# Photographs the screens a golfer sees, on a simulator that will actually
# paint them.
#
#   scripts/tour.sh <simulator-udid> [api-base-url]
#   xcrun simctl list devices available   # to find the udid
#
# Screenshots land in /tmp/vsp-tour/dark and /tmp/vsp-tour/light — the same
# walk in both palettes, so the two can be compared screen by screen. Light
# mode shipped as a setting that had been measured but never looked at.
#
# The cycle below is the whole reason this file exists. A simulator left booted
# from an earlier run hands Flutter a surface that never repaints:
# takeScreenshot returns identical bytes for every screen, and before the
# distinct-frame check in the test the run still reported success. It cost half
# a day once, misdiagnosed as "MapLibre platform views cannot be captured".
# Knowing the remedy is not the same as applying it, so it is applied here
# rather than remembered.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: scripts/tour.sh <simulator-udid> [api-base-url]" >&2
  echo "" >&2
  xcrun simctl list devices available | grep -i iphone >&2 || true
  exit 64
fi

DEVICE="$1"
API_BASE_URL="${2:-https://vps-api.vnteki.com}"
cd "$(dirname "$0")/.."

# Old PNGs are worse than none: a step that fails silently leaves the previous
# run's picture behind, and it gets reviewed as if it were this run's.
rm -rf /tmp/vsp-tour
mkdir -p /tmp/vsp-tour

# A failing pass must not cancel the other one. The palettes are compared
# against each other, and half a comparison answers nothing — the first run to
# do this aborted on a teardown error in the dark pass and never photographed
# light mode at all, which was the reason the second pass was added.
failed=""

for THEME in dark light; do
  # Cycled before each pass, not once at the start. The second pass inherits a
  # simulator the first one left booted, which is the exact condition that
  # freezes the surface.
  echo "==> cycling $DEVICE so its surface repaints"
  xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
  xcrun simctl boot "$DEVICE"

  echo "==> touring in $THEME against $API_BASE_URL"
  if ! flutter test integration_test/screens_tour_test.dart \
    -d "$DEVICE" \
    --dart-define=VSP_API_BASE_URL="$API_BASE_URL" \
    --dart-define=VSP_TOUR_THEME="$THEME"; then
    failed="$failed $THEME"
  fi
done

echo "==> $(find /tmp/vsp-tour -name '*.png' | wc -l | tr -d ' ') screenshots in /tmp/vsp-tour"
if [[ -n "$failed" ]]; then
  echo "==> failed:$failed" >&2
  exit 1
fi
