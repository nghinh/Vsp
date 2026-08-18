#!/usr/bin/env bash
#
# Photographs the screens a golfer sees, on a simulator that will actually
# paint them.
#
#   scripts/tour.sh <simulator-udid> [api-base-url]
#   xcrun simctl list devices available   # to find the udid
#
# Screenshots land in /tmp/vsp-tour.
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

echo "==> cycling $DEVICE so its surface repaints"
xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE"

# Old PNGs are worse than none: a step that fails silently leaves the previous
# run's picture behind, and it gets reviewed as if it were this run's.
rm -rf /tmp/vsp-tour
mkdir -p /tmp/vsp-tour

echo "==> touring against $API_BASE_URL"
exec flutter test integration_test/screens_tour_test.dart \
  -d "$DEVICE" \
  --dart-define=VSP_API_BASE_URL="$API_BASE_URL"
